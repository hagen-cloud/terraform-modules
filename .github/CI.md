# Terraform CI and module releases

Last reviewed: 2026-10-03.

## Purpose and scope

The workflows validate reusable modules and publish module-specific Git tags after a pull request is merged into the default branch. They do not deploy infrastructure, configure a state backend, or receive cloud deployment credentials.

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

CI keeps repository contents read-only and does not persist checkout credentials. Report jobs receive `pull-requests: write` to update PR comments; the reusable workflow caller declares the same permission ceiling. No checks-writing token or personal access token is needed. Actions reference explicit release tags, such as `actions/checkout@v7.0.1`, to keep the workflow readable. Tags can be moved by upstream maintainers; commit SHA pinning offers stronger code identity guarantees. This project deliberately uses release tags and reviews Dependabot updates. Reports are displayed in Actions summaries and PR comments without uploading artifacts. Secret findings stay in execution logs; restrict access to those logs as appropriate.

The local pre-commit hooks remain available. CI uses prek, a pre-commit-compatible runner, to avoid maintaining separate implementations of file hygiene and TFLint.

### Reports in Actions and pull requests

The workflows do not upload or download artifacts. Terraform tests produce native JUnit XML; Trivy uses its upstream JUnit template and Checkov produces JUnit XML directly. These temporary files remain on the runner and disappear when the hosted job ends. They are not stored as Actions artifacts. Trivy tool/database caches are separate from reports and remain enabled.

`dorny/test-reporter` reads the XML files in the same job and publishes counts, suite results, and failed test or policy names and messages in the Actions summary. Unit tests have one report per registered module. Trivy and Checkov share a security policy report, with results separated by report file and suite. Trivy includes successful configuration checks; the security counts represent policy evaluations, not Terraform unit tests or unique infrastructure resources. A zero count does not establish scanner coverage.

`marocchino/sticky-pull-request-comment` updates one comment per module, one security comment, and one overall CI comment. PR comments show counts and execution status and link to the current run for failure details. They reuse stable headers rather than adding a new comment on each rerun. Unavailable reports are labelled explicitly; a scanner error can leave a partial security report, and the scanner status remains visible. Failed test/scanner steps continue to fail CI even when report publication succeeds. Report parsing/publication errors also fail their job.

Comments are enabled only for same-repository `pull_request` runs that are not authored or triggered by Dependabot. Fork PRs and Dependabot use the Actions summaries reached from the PR's Checks tab because their tokens normally cannot write comments. Scheduled, manual, merge-queue, and post-merge runs publish summaries without changing PR comments. No privileged follow-up workflow, artifact transfer, or extra secret is needed. After an early failure or cancellation, consult the current run: a detailed report might not exist and a previous comment might remain.

The overall summary is produced by `alls-green`; the PR overview lists repository, module, and security job results. The security comment also reports the secret scan status, without including detected credential values. Secret scan details remain in the scan step's logs.

The Trivy template path follows setup-trivy's default installation on the selected `ubuntu-24.04` runner (`/home/runner/.local/bin/trivy-bin/contrib/junit.tpl`). Check this location when changing the runner or Trivy setup action. The template is provided by upstream, with no local template or script to maintain. Checkov requires a trailing comma in `output_file_path` for a single output file.

### Module registration

The module list is defined once, directly in `terraform-ci.yml`, under `jobs.hygiene.outputs.modules`:

```yaml
outputs:
  modules: '["cloudflare/r2_bucket"]'
```

Add a new identifier to this JSON array when its module is ready. The module test matrix reads this output, and the reusable workflow exposes the same list to the release workflow. The release workflow builds each path filter directly from the identifier. No separate inventory file or repeated path registration is required.

An identifier must be unique and stable. Use simple directory names with letters, numbers, underscores, hyphens, and slashes. Avoid regex metacharacters because the tagging action matches a tag prefix using a regular expression.

Currently, only the versioned Cloudflare module is registered. Local untracked Hetzner work has not been enrolled or modified. When that module is ready, add `hetzner/network` to that one list and provide its documentation and tests.

Each registered module must have a generated README and runnable mock-based tests directly in `tests/unit/`. Missing tests fail the module job. Keep nested test helpers under fixtures rather than relying on recursive discovery of nested test files. To retire a module, remove its registration along with the module; deleting individual module files is still a releasable change.

The explicit list is a maintenance requirement: a new unregistered module does not automatically receive module validation, tests, documentation checks, or tags. Repository-wide formatting, linting, and security checks still run.

### Compatibility and test boundaries

The dflook validate and test actions initialize without a backend and select the latest Terraform release allowed by the module's `required_version`. They do not run the former minimum/current version matrix. Successful validation therefore demonstrates compatibility with the selected version, not all versions in the declared range or the minimum supported version.

The validate/test actions resolve providers through Terraform initialization. The former conditional `-lockfile=readonly` policy is not reproduced. Lockfiles in reusable modules should not be treated as deployment dependency locks for consuming root modules.

Unit tests use Terraform's `mock_provider` configuration and exercise module behavior without real infrastructure. CI does not receive cloud credentials. This does not itself prove that a newly added test is mock-only: review test provider configuration, assertions, alternate modules, and external dependencies before merging.

The Python HCL parser enforcing the former mock-only policy was removed. There is no equivalent structural enforcement in this workflow. Removing it must not be interpreted as certification that arbitrary test files are safe to execute. Integration tests and cloud credentials require a separate, deliberately authorized workflow.

The previous custom checks for an empty Checkov workflow report and report parsing errors were also removed. Checkov's own action exit status is the policy gate; reviewers should inspect scanner output when adding a new workflow format or upgrading the scanner. Static security scans do not establish complete provider-policy coverage or deployment readiness.

Documentation uses the existing root `.terraform-docs.yml`, including its replacement mode. CI fails when generated output differs and never commits or pushes documentation. Generate and review README changes locally before merging.

The declarative `language: fail` pre-commit hook blocks tracked state, common saved-plan filenames, provider cache paths, CLI configuration, and deployment `.tfvars` files. Generic `.auto.tfvars` files remain allowed and are scanned for secrets. This is a filename policy, not a complete content-based secret detector.

## Module release workflow

`module-release.yml` uses `pull_request_target` with the `closed` activity so that the trusted base-branch workflow can publish tags for merged fork PRs as well. It proceeds only if the PR was merged into the repository's default branch. No job checks out or executes an unmerged PR head. All checkouts select the approved merge commit explicitly. Keep this merge guard and restricted job permissions intact.

1. Reuse the CI workflow to check the exact merge commit and obtain its module list.
2. Process the registered modules one at a time with `max-parallel: 1`.
3. Use an inline paths-filter configuration to check whether the current module changed in the PR. Skip publication for unchanged modules.
4. Wait for earlier release runs to finish before choosing a version. Turnstyle prevents concurrent runs from selecting the same next version; a timeout fails rather than bypassing the queue.
5. Read the highest matching semantic version tag for that module and create the next tag on the merge commit.

Only the tagging job receives `contents: write`. The hygiene job receives `issues: read` to inspect PR labels. The same release job uses `pull-requests: read` for path detection and `actions: read` for queue coordination. Unmerged PRs, merges into other branches, direct pushes, and changes outside registered module paths do not publish module tags.

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

- `cloudflare/r2_bucket/v0.2.3` becomes `cloudflare/r2_bucket/v0.2.4` on a patch change.
- A registered `hetzner/network/v0.1.7` becomes `hetzner/network/v0.1.8` on the same patch PR.

There is no repository-wide counter shared between modules. Without any matching tag, the baseline is `0.0.0`: the first patch tag is `0.0.1`, the first minor tag is `0.1.0`, and the first major tag is `1.0.0`. This baseline is not a production-readiness claim.

Keep the prefix `<module identifier>/v` stable. Existing tags with another naming scheme are not adopted automatically. At the time of this local refactor, the checkout had no existing tags.

Consumers select a module subdirectory and its tag together, for example:

```hcl
module "bucket" {
  source = "git::https://github.com/hagen-cloud/terraform-modules.git//modules/cloudflare/r2_bucket?ref=cloudflare/r2_bucket/v0.2.4"

  # Supply the inputs required by the selected module version.
}
```

The source is illustrative; the version in this example is not a published release.

### Failures and recovery

A failed check prevents tagging. The release workflow may publish some module tags before another module fails; it is not an atomic multi-module transaction. Review the job results before retrying.

Re-running a tagging job immediately after the same commit has already received that module's latest tag skips the increment. Retry failed jobs before newer merges are released. Do not rerun an older completed release after newer tags exist: the tagging action compares against the latest tag and can create an additional version for the old commit. This is an upstream action limitation, not general idempotence.

The workflows do not move or delete existing tags. For an incorrect release, prefer a corrective PR and a new tag. Any exceptional tag deletion requires checking consumers first. If a run times out while waiting for previous releases, inspect the previous runs and rerun the failed jobs; do not bypass the queue.

GitHub's token permission settings or tag rules may block tag creation. Grant only the required tagging permission and compatible tag-rule access. No personal access token is configured.

Tags created with `GITHUB_TOKEN` do not normally trigger other workflows. This design does not depend on a tag-triggered workflow for completing a release.

## Dependabot and maintenance

Dependabot proposes weekly updates for GitHub Actions, Terraform dependencies, and pre-commit hooks. Compatible action minor/patch updates are grouped; major action updates remain separate for review. No auto-merge is configured.

Action references use explicit release version tags rather than commit SHAs or moving major aliases. Tool versions supplied as action inputs, including Terraform, TFLint, Trivy, actionlint, and prek, require deliberate updates; Dependabot is not a generic updater of those input values.

Keep the module list, tag prefixes, provider requirements, and test policy under review as the library grows. The workflows contain no repository scripts, but dependency maintenance and review of upstream action behavior remain necessary.

## Validation status

The workflow changes are local and intentionally uncommitted. The 2026-10-03 simplification removes the module inventory file, reduces CI from six jobs to four and release from three jobs to two, and removes the duplicate post-merge push trigger. Actionlint and YAML/output-wiring checks passed after this simplification; Terraform implementation was not changed. Passed locally: YAML parsing, actionlint, pre-commit configuration validation, file hygiene hooks, TFLint, absence of repository scripts and inline scripts, module registration consistency, and action input contracts against every selected upstream manifest. On 2026-10-03, all replacement release tags were verified to resolve to the previously configured commits, and actionlint was rerun after changing the references. In an isolated copy, Terraform formatting, backend-free initialization, validation, and both Cloudflare mock test runs passed. The original module files were not changed.

The artifact-free reporting change was checked with actionlint and upstream action input manifests. The selected reporter was also executed locally against synthetic JUnit results: pass/fail/skip counts and failure messages appeared in the summary, and a failed test retained a nonzero exit code. No Terraform implementation changed for reporting.

End-to-end Actions execution, PR comment permissions, report rendering on GitHub, queue behavior, fork PR behavior, and real tag publication must be validated after the workflows are committed through the normal PR process. No remote workflow or tag is created during this refactor.

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
- [Dependabot options](https://docs.github.com/en/code-security/reference/supply-chain-security/dependabot-options-reference)
- [Terraform provider mocks](https://developer.hashicorp.com/terraform/language/tests/mocking)
- [GitHub token workflow trigger behavior](https://docs.github.com/en/actions/how-tos/writing-workflows/choosing-when-your-workflow-runs/triggering-a-workflow)
