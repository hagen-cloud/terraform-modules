<!-- BEGIN_TF_DOCS -->
# Cloudflare R2 Bucket

Creates and manages a single Cloudflare R2 bucket, with optional data
jurisdiction, location preference, and default storage class.

## Account selection and authentication

Authentication is supplied through the Cloudflare provider configuration.
The required `account_id` input explicitly selects the Cloudflare account
where the bucket is created. It is marked as sensitive, and the provider
credentials must have permission to manage R2 buckets in that account.

## Bucket configuration

- `name` is required and identifies the bucket within the selected account.
- `jurisdiction` controls where objects are guaranteed to be stored.
  Supported values: `default`, `eu`, `fedramp`, and `us`.
- `location` is a best-effort placement preference, not a residency guarantee.
  Supported values: `apac`, `eeur`, `enam`, `weur`, `wnam`, and `oc`.
  Cloudflare honors it only when a bucket name is first created; deleting
  and recreating a bucket with the same name retains its original location.
- `storage_class` sets the default for newly uploaded objects unless an
  upload specifies another class. Supported values: `Standard` and
  `InfrequentAccess`.

Optional inputs default to `null`, leaving their values to the provider
and Cloudflare API defaults.

## Scope

This module manages the bucket itself. Object uploads, access credentials,
public access, custom domains, CORS, and lifecycle rules are configured
separately.

## Outputs

No outputs are currently exposed. The resource ID is the bucket name,
which callers already supply. The creation timestamp has no identified
downstream use in this module. Outputs can be added when another module
needs a resource reference or the effective bucket configuration.

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.15.8, < 2.0.0 |
| <a name="requirement_cloudflare"></a> [cloudflare](#requirement\_cloudflare) | 5.26.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_cloudflare"></a> [cloudflare](#provider\_cloudflare) | 5.26.0 |

## Resources

| Name | Type |
|------|------|
| [cloudflare_r2_bucket.this](https://registry.terraform.io/providers/cloudflare/cloudflare/5.26.0/docs/resources/r2_bucket) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | Account ID | `string` | n/a | yes |
| <a name="input_jurisdiction"></a> [jurisdiction](#input\_jurisdiction) | Jurisdiction where objects in this bucket are guaranteed to be stored. Available values: 'default', 'eu', 'fedramp', 'us' | `string` | `null` | no |
| <a name="input_location"></a> [location](#input\_location) | Location of the bucket. Available values: apac, eeur, enam, weur, wnam, oc. | `string` | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of the bucket | `string` | n/a | yes |
| <a name="input_storage_class"></a> [storage\_class](#input\_storage\_class) | Storage class for newly uploaded objects, unless specified otherwise. Available values: 'Standard', 'InfrequentAccess'. | `string` | `null` | no |
<!-- END_TF_DOCS -->