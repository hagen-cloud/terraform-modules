/**
 * # Cloudflare R2 Bucket
 *
 * Creates and manages a single Cloudflare R2 bucket, with optional data
 * jurisdiction, location preference, and default storage class.
 *
 * ## Account selection and authentication
 *
 * Authentication is supplied through the Cloudflare provider configuration.
 * The required `account_id` input explicitly selects the Cloudflare account
 * where the bucket is created. It is marked as sensitive, and the provider
 * credentials must have permission to manage R2 buckets in that account.
 *
 * ## Bucket configuration
 *
 * - `name` is required and identifies the bucket within the selected account.
 * - `jurisdiction` controls where objects are guaranteed to be stored.
 *   Supported values: `default`, `eu`, `fedramp`, and `us`.
 * - `location` is a best-effort placement preference, not a residency guarantee.
 *   Supported values: `apac`, `eeur`, `enam`, `weur`, `wnam`, and `oc`.
 *   Cloudflare honors it only when a bucket name is first created; deleting
 *   and recreating a bucket with the same name retains its original location.
 * - `storage_class` sets the default for newly uploaded objects unless an
 *   upload specifies another class. Supported values: `Standard` and
 *   `InfrequentAccess`.
 *
 * Optional inputs default to `null`, leaving their values to the provider
 * and Cloudflare API defaults.
 *
 * ## Scope
 *
 * This module manages the bucket itself. Object uploads, access credentials,
 * public access, custom domains, CORS, and lifecycle rules are configured
 * separately.
 *
 * ## Outputs
 *
 * No outputs are currently exposed. The resource ID is the bucket name,
 * which callers already supply. The creation timestamp has no identified
 * downstream use in this module. Outputs can be added when another module
 * needs a resource reference or the effective bucket configuration.
 */

resource "cloudflare_r2_bucket" "this" {
  account_id    = var.account_id
  name          = var.name
  jurisdiction  = var.jurisdiction
  location      = var.location
  storage_class = var.storage_class
}
