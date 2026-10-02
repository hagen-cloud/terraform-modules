# Terraform Modules

A shared library of reusable Terraform building blocks for the `hagen-cloud` organization.

This repository exists to turn repeatable infrastructure knowledge into clear, maintainable components. Its purpose is to reduce duplication, make infrastructure decisions easier to review, and provide a consistent foundation for composing infrastructure across projects and environments.

The library is intended to evolve incrementally from practical needs and validated experience. This README describes its purpose and design direction; it does not certify the maturity, compatibility, or production readiness of every component.

## Why this repository exists

Infrastructure work often repeats the same design choices: which settings to expose, how to express dependencies, which defaults are appropriate, and how to make changes understandable. Repeating those choices independently creates drift, duplicated maintenance, and inconsistent behavior.

A shared module library provides a place to capture reusable implementation knowledge while keeping each deployment's context explicit. The goals are to:

- **Reuse proven patterns:** apply lessons from validated work without copying entire configurations between projects.
- **Improve consistency:** make recurring infrastructure behavior easier to recognize, compare, and maintain.
- **Reduce cognitive load:** expose an understandable interface around a clearly defined infrastructure responsibility.
- **Support review:** make assumptions, dependencies, and the consequences of configuration choices visible.
- **Preserve knowledge:** keep implementation intent and limitations alongside the code they explain.
- **Enable controlled evolution:** allow consumers to adopt changes deliberately and assess their impact.

Reuse should simplify the total work of deployment, operation, troubleshooting, and upgrades. It should not introduce abstraction solely to make configurations appear more sophisticated.

## Intended audience

The repository is intended for infrastructure engineers and maintainers who develop reusable components or compose them into executable Terraform configurations.

It also supports reviewers and future operators who need to understand a component's responsibility, configuration contract, and limitations without relying on undocumented knowledge from its original author.

## Role in the infrastructure architecture

This repository represents the reusable component layer. Root modules represent the deployment composition layer.

An ingredient-and-recipe analogy describes that relationship: reusable modules are the ingredients, while root modules are the recipes that combine them for a particular outcome. The recipe supplies the deployment context and determines how the ingredients fit together.

| Responsibility | Reusable component layer | Root module / deployment layer |
| --- | --- | --- |
| Infrastructure behavior | Encapsulates a focused responsibility | Selects and combines the required components |
| Configuration | Exposes inputs, outputs, and constraints | Supplies values appropriate to the target environment |
| Dependencies | Makes required dependencies explicit | Connects components and resolves deployment context |
| Provider configuration | Declares provider requirements | Configures providers and passes them when required |
| State and backend | Documents implications of its resources | Configures and protects the deployment's state |
| Credentials and execution | Avoids embedding credentials | Supplies authorized access and controls execution |
| Change adoption | Communicates interface and behavior changes | Reviews and adopts a specific revision |

For this project, reusable components are maintained in `terraform-modules`, while deployment compositions belong in `terraform-root-modules`. A component should remain useful without requiring a particular execution platform or delivery pipeline.

## Scope and boundaries

The library's scope is reusable infrastructure behavior: focused abstractions, clear configuration contracts, meaningful defaults, documented constraints, and knowledge that can be applied across more than one deployment context.

Environment-specific composition belongs with the configuration that consumes the library. Account selection, environment values, backend configuration, execution permissions, approvals, and operational ownership are deployment responsibilities.

The repository is not intended to become a collection of complete customer environments, a store for live infrastructure state, or a substitute for operational runbooks. Client-specific information and deployment secrets must remain outside the shared library.

Provider-specific behavior may be appropriate when it reflects the infrastructure being managed. Reuse does not require pretending that different platforms have identical capabilities or tradeoffs.

## Design principles

### Focused responsibilities

Each component should have a purpose that can be explained plainly. Its boundary should follow an infrastructure responsibility, with related behavior grouped only when it improves clarity and maintenance.

Abstraction depth should remain proportional to the problem. A reusable component is worthwhile when it captures meaningful behavior, policy, or recurring knowledge and makes the consuming configuration easier to understand.

### Explicit interfaces

Inputs and outputs form a contract between the component and its consumers. Their meaning, constraints, defaults, and operational consequences should be understandable before deployment.

Expose decisions that consumers reasonably need to make. Avoid turning every implementation detail into a parameter or hiding important behavior behind implicit assumptions.

### Practical defaults

Defaults should be deliberate and explainable. Choices that affect cost, accessibility, data retention, or destructive behavior require particular care.

A default is a starting point for review, not evidence that a configuration is suitable for every environment. Consumers remain responsible for checking it against their requirements.

### Composition over hidden coupling

Components should expose the information needed to connect them through the consuming configuration. Dependencies should be visible enough for reviewers to understand the resulting infrastructure and its lifecycle.

Avoid assumptions about a specific account, environment, naming convention, or surrounding deployment unless those assumptions are part of the documented contract.

### Maintainability and handover

Code and documentation should allow another engineer to understand intent, diagnose behavior, and maintain the result. Prefer straightforward implementations to clever indirection.

The library should reduce dependence on its original author by making decisions and limitations discoverable.

## Quality and validation expectations

Quality is an intended standard that must be demonstrated for the relevant component and change. Repository membership alone is not proof of validation.

Before treating a component as suitable for a deployment, maintainers and consumers should be able to establish:

- Its purpose, supported use cases, assumptions, and exclusions.
- The configuration contract and applicable compatibility requirements.
- The expected resources, dependencies, and lifecycle behavior.
- What validation was performed and what remains unverified.
- Known risks, limitations, and any required migration steps.

Validation should be proportionate to the impact of the change. Configuration checks provide useful feedback, but behavior that depends on a provider or a real environment requires appropriate deployment evidence.

Experimental behavior and unresolved questions should be identified explicitly. Readiness claims must reflect evidence for the intended use case.

## Security and operational responsibility

The shared library should support clear security decisions and avoid embedding deployment access or sensitive context.

Credentials, tokens, private keys, live state, saved plans, and confidential client or employer information must not be committed. Documentation and examples should use generic or sanitized values.

Component design should consider least privilege, unintended exposure, data protection, and resource lifecycle consequences. Consumers must still evaluate the resulting plan in the target environment, confirm the intended account and scope, and control approval and execution.

Costs and destructive changes are part of that review. A reusable interface does not remove responsibility for understanding the infrastructure it manages or for protecting existing data.

## Consumption and change management

Consumers should adopt an identified revision and upgrade intentionally. Compatibility must be assessed against the component's documented requirements and the consuming deployment.

Changes to inputs, outputs, defaults, resource identity, dependencies, or lifecycle behavior can affect consumers even when the interface appears familiar. Relevant changes should explain the impact and any validation or migration required.

A code rollback alone may not undo changes already applied to infrastructure. Recovery must account for the deployment's state, actual resources, and any irreversible effects.

## Evolution of the library

The library should grow from recurring needs and validated learning. New abstractions should have a concrete reason to exist, a clear responsibility, and a maintenance cost justified by their value.

As experience accumulates, maintainers can improve interfaces, document limitations, and refine common patterns. Experimental ideas should remain distinguishable from validated behavior, and uncertain assumptions should not become implicit guarantees.

Success means less duplicated work, clearer infrastructure reviews, more deliberate change adoption, and easier maintenance. The number of components or the sophistication of the tooling is not a useful goal by itself.

## Documentation expectations

This root README explains the repository's purpose and boundaries. Documentation closer to each component should explain the details required to evaluate and use it: prerequisites, inputs, outputs, assumptions, validation evidence, limitations, and upgrade considerations.

Deployment procedures belong with the consuming configuration or the relevant operational runbook. Each subject should have a clear source of truth so that readers can find current guidance without reconciling duplicated instructions.

New documentation is written in English. Examples and explanations intended for publication must be reviewed for sensitive information.

## References

The following official references provide Terraform's language model for reusable modules and their relationship to consuming configurations. The repository's purpose and quality expectations above describe this project's direction.

- [Creating modules](https://developer.hashicorp.com/terraform/language/modules/develop)
- [Providers within modules](https://developer.hashicorp.com/terraform/language/modules/develop/providers)
- [Using modules in configurations](https://developer.hashicorp.com/terraform/language/modules/configuration)

Last reviewed: 2026-10-02.
