# Terraform CI and module releases

Last reviewed: 2026-10-03.

## Purpose and scope

The workflows validate reusable modules and publish module-specific Git tags and GitHub Releases after a pull request is merged into the default branch. They do not deploy infrastructure, configure a state backend, or receive cloud deployment credentials.

All workflow steps use maintained actions. There are no repository-owned CI scripts, inline scripts, or `run` steps. Tools and actions may use Python, shell, or JavaScript internally; their implementation belongs to the upstream projects.

## Validation workflow

`terraform-ci.yml` runs for pull requests, merge queues, manual requests, and a weekly schedule at 06:00 UTC on Mondays. It is also reusable by the release workflow so that the exact merged commit is checked before tagging. There is no additional push-triggered run after a merge. Direct pushes do not trigger CI; use PRs or an explicit manual run.

| Job | Responsibility | Implementation |
| --- | --- | --- |
| Repository checks | File hygiene, forbidden artifacts, TFLint, workflow syntax, release labels, Terraform formatting | Existing pre-commit hooks through prek, setup-tflint, actionlint, required-labels, terraform-fmt-check |
| Modules | Backend-free validation, documentation freshness, unit tests, JUnit reports | dflook Terraform actions and terraform-docs |
| Security | Terraform misconfiguration, GitHub Actions policies, and secret detection | Trivy and Checkov actions |
| Quality gate | Reject failures, cancellations, and skipped required jobs | alls-green |

Require `Terraform CI / required` in the repository's branch rules. The workflow does not configure branch protection itself. Keep release-related workflows and settings subject to maintainer review.

CI keeps repository contents read-only and does not persist checkout credentials. Only the final quality-gate job receives `pull-requests: write` to update the consolidated PR comment; the reusable workflow caller declares the same permission ceiling. No checks-writing token or personal access token is needed. Actions reference explicit release tags, such as `actions/checkout@v7.0.1`, to keep the workflow readable. Tags can be moved by upstream maintainers; commit SHA pinning offers stronger code identity guarantees. This project deliberately uses release tags and reviews Dependabot updates. Reports are displayed in Actions summaries and PR comments without uploading artifacts. Secret findings stay in execution logs; restrict access to those logs as appropriate.

The local pre-commit hooks remain available. CI uses prek, a pre-commit-compatible runner, to avoid maintaining separate implementations of file hygiene and TFLint.

### Reports in Actions and pull requests

The workflows do not upload or download artifacts. Terraform tests produce native JUnit XML; Trivy uses its upstream JUnit template and Checkov produces JUnit XML directly. These temporary files remain on the runner and disappear when the hosted job ends. They are not stored as Actions artifacts. Trivy tool/database caches are separate from reports and remain enabled.

`dorny/test-reporter` reads the XML files in the same job and publishes counts, suite results, and failed test or policy names and messages in the Actions summary. Unit tests have one report per registered module. Trivy and Checkov share a security policy report, with results separated by report file and suite. Trivy includes successful configuration checks; the security counts represent policy evaluations, not Terraform unit tests or unique infrastructure resources. A zero count does not establish scanner coverage.

`marocchino/sticky-pull-request-comment` updates one consolidated comment from the final quality-gate job after all required jobs finish. It includes overall job results, the module list and test job status, individual scanner statuses, security policy counts, and a link to the current run. Per-module test counts and failure details remain in Actions summaries. Matrix job outputs cannot reliably aggregate results from every module, so the PR comment does not present a misleading combined test count. The stable `terraform-ci-overview` header updates the same comment on reruns. Unavailable reports are labelled explicitly; a scanner error can leave a partial security report, and the scanner status remains visible. Failed test/scanner steps continue to fail CI even when report publication succeeds. Report parsing/publication errors also fail their job.

Comments are enabled only for same-repository `pull_request` runs that are not authored or triggered by Dependabot. Fork PRs and Dependabot use the Actions summaries reached from the PR's Checks tab because their tokens normally cannot write comments. Scheduled, manual, merge-queue, and post-merge runs publish summaries without changing PR comments. No privileged follow-up workflow, artifact transfer, or extra secret is needed. After an early failure or cancellation, consult the current run: a detailed report might not exist and a previous comment might remain.

The overall summary is produced by `alls-green`; the PR overview lists repository, module, and security job results. The consolidated comment also reports the secret scan status, without including detected credential values. Secret scan details remain in the scan step's logs.

The Trivy template path follows setup-trivy's default installation on the selected `ubuntu-24.04` runner (`/home/runner/.local/bin/trivy-bin/contrib/junit.tpl`). Check this location when changing the runner or Trivy setup action. The template is provided by upstream, with no local template or script to maintain. Checkov requires a trailing comma in `output_file_path` for a single output file.

### Module registration

The module list is defined once, directly in `terraform-ci.yml`, under `jobs.hygiene.outputs.modules`:

```yaml
outputs:
  modules: '["cloudflare/r2_bucket"]'
```

Add a new identifier to this JSON array when its module is ready. The module test matrix reads this output, and the reusable workflow exposes the same list to the release workflow. The release workflow builds each path filter directly from the identifier. No separate inventory file or repeated path registration is required.

An identifier must be unique and stable. Use simple directory names with letters, numbers, underscores, hyphens, and slashes. Use lowercase names. Publication replaces every `/` and `_` with `-`, then appends `-v<version>`. Identifiers must also be unique after this normalization: `aws/foo_bar` and `aws/foo-bar` would collide. Review this when registering or renaming a module. Avoid regex metacharacters because the tagging action matches a tag prefix using a regular expression.

Currently, only the versioned Cloudflare module is registered. Local untracked Hetzner work has not been enrolled or modified. When that module is ready, add `hetzner/network` to that one list and provide its documentation and tests.

Each registered module must have a generated README and runnable mock-based tests directly in `tests/unit/`. Missing tests fail the module job. Keep nested test helpers under fixtures rather than relying on recursive discovery of nested test files. To retire a module, remove its registration along with the module; deleting individual module files is still a releasable change.

The explicit list is a maintenance requirement: a new unregistered module does not automatically receive module validation, tests, documentation checks, or tags. Repository-wide formatting, linting, and security checks still run.

### Compatibility and test boundaries

The dflook validate and test actions initialize without a backend and select the latest Terraform release allowed by the module's `required_version`. They do not run the former minimum/current version matrix. Successful validation therefore demonstrates compatibility with the selected version, not all versions in the declared range or the minimum supported version.

The validate/test actions resolve providers through Terraform initialization. The former conditional `-lockfile=readonly` policy is not reproduced. Lockfiles in reusable modules should not be treated as deployment dependency locks for consuming root modules.

Unit tests use Terraform's `mock_provider` configuration and exercise module behavior without real infrastructure. CI does not receive cloud credentials. This does not itself prove that a newly added test is mock-only: review test provider configuration, assertions, alternate modules, and external dependencies before merging.

The Python HCL parser enforcing the former mock-only policy was removed. There is no equivalent structural enforcement in this workflow. Removing it must not be interpreted as certification that arbitrary test files are safe to execute. Integration tests and cloud credentials require a separate, deliberately authorized workflow.

The previous custom checks for an empty Checkov workflow report and report parsing errors were also removed. Checkov's own action exit status is the policy gate; reviewers should inspect scanner output when adding a new workflow format or upgrading the scanner. Static security scans do not establish complete provider-policy coverage or deployment readiness.

Documentation uses the existing root `.terraform-docs.yml`, including its replacement mode. CI fails when generated output differs and never commits or pushes documentation. Generate and review README changes locally before merging. The selected terraform-docs action embeds version 0.20.0; the shared `.terraform-docs.yml` requires exactly `0.20.0` for both local hooks and CI. Install it on Windows with `winget install --id Terraform-docs.Terraform-docs --exact --version 0.20.0 --source winget --force`, then generate documentation with `terraform-docs markdown table --config .terraform-docs.yml modules/cloudflare/r2_bucket`. Version 0.24.0 formats Markdown table separators differently and causes the freshness check to fail. Documentation is checked before Terraform initialization because the action detects changes across the entire checkout, including tracked lockfiles.

The declarative `language: fail` pre-commit hook blocks tracked state, common saved-plan filenames, provider cache paths, CLI configuration, and deployment `.tfvars` files. Generic `.auto.tfvars` files remain allowed and are scanned for secrets. This is a filename policy, not a complete content-based secret detector.

## Module release workflow

`module-release.yml` uses `pull_request_target` with the `closed` activity so that the trusted base-branch workflow can publish tags for merged fork PRs as well. It proceeds only if the PR was merged into the repository's default branch. No job checks out or executes an unmerged PR head. All checkouts select the approved merge commit explicitly. Keep this merge guard and restricted job permissions intact.

1. Reuse the CI workflow to check the exact merge commit and obtain its module list.
2. Process the registered modules one at a time with `max-parallel: 1`.
3. Use an inline paths-filter configuration to check whether the current module changed in the PR. Skip publication for unchanged modules.
4. Wait for earlier release runs to finish before choosing a version. Turnstyle prevents concurrent runs from selecting the same next version; a timeout fails rather than bypassing the queue.
5. Replace `/` and `_` in the module identifier with `-`, read the highest matching semantic version tag for that prefix, and create the next tag on the merge commit.
6. Build release notes with `mikepenz/release-changelog-builder-action`, using `.github/release-notes.json` for categories and the entry template. The workflow wraps those changes with module identity, a pinned usage example, documentation, and validation links.
7. Publish a GitHub Release for the exact tag with `softprops/action-gh-release`. Releases are not marked as the repository-wide latest release because each module has its own version stream.

Only the release job receives `contents: write`. The hygiene job receives `issues: read` to inspect PR labels. The same release job uses `pull-requests: read` for path detection and `actions: read` for queue coordination. Unmerged PRs, merges into other branches, direct pushes, and changes outside registered module paths do not publish module tags.

Changes anywhere under a registered module path, including documentation, tests, and deletions, count as changes to that module. Root README and CI-only changes do not release unrelated modules. A tag identifies a commit of the whole repository; its prefix denotes the module whose version is being released.

### Version policy

The founder selected PR labels with patch as the default. The optional labels are:

| Label | Increment | Example from 1.2.3 |
| --- | --- | --- |
| No release label or `release:patch` | Patch | 1.2.4 |
| `release:minor` | Minor | 1.3.0 |
| `release:major` | Major | 2.0.0 |

CI rejects more than one release label on the same PR. Create these labels in the repository before using them; the workflows do not create or edit labels.

Use patch for compatible fixes or documentation changes, minor for backward-compatible capabilities, and major for breaking contracts such as removed inputs/outputs, incompatible defaults, or changes requiring consumer migration. A provider update can be breaking: assess behavior rather than assuming that every dependency update is a patch.

The selected label applies to every changed registered module in that PR. If modules need different increments, split them into separate PRs. Set labels before merging. Commit subjects, Conventional Commits, and the action's usual `#major`/`#minor` directives do not determine the bump: run-specific directive tokens disable those message conventions.

Version streams are independent:

- `cloudflare-r2-bucket-v0.2.3` becomes `cloudflare-r2-bucket-v0.2.4` on a patch change.
- A registered `hetzner-network-v0.1.7` becomes `hetzner-network-v0.1.8` on the same patch PR.

There is no repository-wide counter shared between modules. Without any matching tag, the baseline is `0.0.0`: the first patch tag is `0.0.1`, the first minor tag is `0.1.0`, and the first major tag is `1.0.0`. This baseline is not a production-readiness claim.

Keep the normalized prefix `<provider>-<module>-v` stable. Renaming directories may change that prefix and therefore requires a release migration. Directory paths remain unchanged by tag normalization.

The first published tag used the legacy name `cloudflare/r2_bucket/v0.0.1` on commit `e815a5392349482746b37a3dff2967fddc81d610`. Preserve that tag and seed `cloudflare-r2-bucket-v0.0.1` at the same commit before activating the new workflow. This retains existing consumers and lets the next patch release continue at `cloudflare-r2-bucket-v0.0.2`. Changing only the prefix would otherwise start a new version stream. CI-only merges do not publish a module release.

Consumers select a module subdirectory and its tag together, for example:

```hcl
module "bucket" {
  source = "git::https://github.com/hagen-cloud/terraform-modules.git//modules/cloudflare/r2_bucket?ref=cloudflare-r2-bucket-v0.2.4"

  # Supply the inputs required by the selected module version.
}
```

The source is illustrative; the version in this example is not a published release.

### Release descriptions

Notes describe the merged PR that triggered this publication. The changelog action compares the PR base SHA with the merge SHA, fetches PRs through those commits, and filters commits by `modules/<identifier>/`. Both refs are explicit, so the action cannot accidentally select a different module's latest tag. The same bounds work for a first release and a retry. The trailing slash in the path prevents matching sibling names. The action accepts path prefixes here, not glob patterns.

Entries include reviewed PR titles, links, and authors. Conventional Commit prefixes and PR labels categorize features, fixes, dependencies, documentation, and maintenance; unmatched entries remain visible. They do not change the version increment policy. A PR that changes several modules may appear in each affected module's release, with the same PR title; keep titles useful and describe per-module impact and migration steps in the PR body and module documentation.

The template does not use an AI service, infer compatibility from code, or copy the whole PR body into every module's release. Release notes are reproducible from GitHub metadata and require only `GITHUB_TOKEN`. Human review remains responsible for explaining compatibility and upgrade requirements. A future AI-assisted PR summary can feed the same process after review without giving an AI publication credentials.

### Failures and recovery

A failed check prevents tagging. Tag creation and GitHub Release publication are separate API operations: a notes or publication failure can leave a valid tag without a Release, and fails the job. Retry the failed release job before newer module releases. The release workflow may publish some module tags before another module fails; it is not an atomic multi-module transaction. Review the job results before retrying.

Re-running the release job immediately after the same commit has already received that module's latest tag skips the increment, rebuilds notes with the same commit bounds, and creates or updates the Release for that tag. The body is replaced rather than appended, preventing duplicate notes. Do not hand-edit generated release bodies if a retry is expected. Retry failed jobs before newer merges are released. Do not rerun an older completed release after newer tags exist: the tagging action compares against the latest tag and can create an additional version for the old commit. This is an upstream action limitation, not general idempotence.

The workflows do not move or delete existing tags. For an incorrect release, prefer a corrective PR and a new tag. Any exceptional tag deletion requires checking consumers first. If a run times out while waiting for previous releases, inspect the previous runs and rerun the failed jobs; do not bypass the queue.

GitHub's token permission settings or tag rules may block tag creation. Grant only the required tagging permission and compatible tag-rule access. No personal access token is configured.

Tags created with `GITHUB_TOKEN` do not normally trigger other workflows. The GitHub Release is created in the same job, immediately after tagging and generating notes; this design does not depend on a tag-triggered workflow.

## Dependabot and maintenance

Dependabot proposes weekly updates for GitHub Actions, Terraform dependencies, and pre-commit hooks. Compatible action minor/patch updates are grouped; major action updates remain separate for review. No auto-merge is configured.

Action references use explicit release version tags rather than commit SHAs or moving major aliases. Tool versions supplied as action inputs, including Terraform, TFLint, Trivy, actionlint, and prek, require deliberate updates; Dependabot is not a generic updater of those input values.

Keep the module list, tag prefixes, provider requirements, and test policy under review as the library grows. The workflows contain no repository scripts, but dependency maintenance and review of upstream action behavior remain necessary.

## Validation status

The original R2 module release completed successfully in [run 37147045882](https://github.com/hagen-cloud/terraform-modules/actions/runs/37147045882), including repository checks, module documentation, backend-free validation, mock tests, security scans, and publication of the legacy `cloudflare/r2_bucket/v0.0.1` tag. This confirms the original single-module merge-and-tag flow; it does not validate concurrent multi-module releases or fork behavior.

For normalized tags and GitHub Releases, actionlint 1.7.12 passed locally. The exact pinned normalization action was executed against `cloudflare/r2_bucket` and `hetzner/network`. The pinned changelog action was executed locally against real GitHub history: the initial R2 PR was categorized as a feature, an extended range excluded the unrelated Actions/pre-commit PRs, and an unrelated-only range produced no module entries. Repeating the initial range produced identical notes. The rendered release body was reviewed for resolved placeholders, the pinned source, and documentation/run links.

GitHub CI must pass on the implementation PR before merge. Automated Release publication with the workflow's `GITHUB_TOKEN` still needs its first module-changing merge; a workflow-only PR does not publish a module version. Keep concurrency, fork behavior, tag-rule permissions, and recovery after a newer release as explicit operational limitations described above.

## References

- [dflook Terraform actions](https://github.com/dflook/terraform-github-actions)
- [terraform-docs action](https://github.com/terraform-docs/gh-actions)
- [prek action](https://github.com/j178/prek-action)
- [Trivy action](https://github.com/aquasecurity/trivy-action)
- [Checkov action](https://github.com/bridgecrewio/checkov-action)
- [Test reporter](https://github.com/dorny/test-reporter)
- [Sticky PR comments](https://github.com/marocchino/sticky-pull-request-comment)
- [alls-green](https://github.com/re-actors/alls-green)
- [paths-filter](https://github.com/dorny/paths-filter)
- [Turnstyle](https://github.com/softprops/turnstyle)
- [Tagging action](https://github.com/anothrNick/github-tag-action)
- [String normalization action](https://github.com/frabert/replace-string-action)
- [Release changelog builder](https://github.com/mikepenz/release-changelog-builder-action)
- [GitHub Release action](https://github.com/softprops/action-gh-release)
- [Dependabot options](https://docs.github.com/en/code-security/reference/supply-chain-security/dependabot-options-reference)
- [Terraform provider mocks](https://developer.hashicorp.com/terraform/language/tests/mocking)
- [GitHub token workflow trigger behavior](https://docs.github.com/en/actions/how-tos/writing-workflows/choosing-when-your-workflow-runs/triggering-a-workflow)

### 2026-10-03 documentation check correction

Run 37139581751 failed at documentation freshness because the committed README used terraform-docs 0.24.0 formatting while the action embeds 0.20.0. Regenerated the R2 README with 0.20.0 and moved documentation checking before backend-free validation to avoid unrelated initialization changes affecting this check. The documentation gate remains mandatory; no scripts or automatic documentation push were added.

The subsequent correction aligns the local WinGet-managed executable with the action and enforces an exact version in the shared configuration. When upgrading the documentation action, inspect its embedded generator version, update this constraint, and upgrade the local executable together. Do not reformat READMEs just to accommodate mismatched toolchains.
