mock_provider "cloudflare" {
  mock_resource "cloudflare_r2_bucket" {
    defaults = {
      jurisdiction  = "mock-jurisdiction"
      location      = "mock-location"
      storage_class = "mock-storage-class"
    }
  }
}

variables {
  account_id = "00000000000000000000000000000000"
  name       = "r2-unit-test"
}

run "minimal_configuration" {
  command = apply

  assert {
    condition     = cloudflare_r2_bucket.this.account_id == "00000000000000000000000000000000"
    error_message = "The bucket must use the account supplied by the caller."
  }

  assert {
    condition     = cloudflare_r2_bucket.this.name == "r2-unit-test"
    error_message = "The bucket must use the name supplied by the caller."
  }

  assert {
    condition = (
      cloudflare_r2_bucket.this.jurisdiction == coalesce(var.jurisdiction, "mock-jurisdiction") &&
      cloudflare_r2_bucket.this.location == coalesce(var.location, "mock-location") &&
      cloudflare_r2_bucket.this.storage_class == coalesce(var.storage_class, "mock-storage-class")
    )
    error_message = "Optional configuration must preserve caller inputs and delegate null values to the provider."
  }
}

run "explicit_configuration" {
  command = plan

  variables {
    account_id    = "11111111111111111111111111111111"
    name          = "r2-unit-test-custom"
    jurisdiction  = "eu"
    location      = "weur"
    storage_class = "InfrequentAccess"
  }

  assert {
    condition = (
      cloudflare_r2_bucket.this.account_id == "11111111111111111111111111111111" &&
      cloudflare_r2_bucket.this.name == "r2-unit-test-custom"
    )
    error_message = "Changing account and name must update the bucket's planned configuration."
  }

  assert {
    condition     = cloudflare_r2_bucket.this.jurisdiction == "eu"
    error_message = "The bucket must preserve the requested data jurisdiction."
  }

  assert {
    condition     = cloudflare_r2_bucket.this.location == "weur"
    error_message = "The bucket must preserve the requested location preference."
  }

  assert {
    condition     = cloudflare_r2_bucket.this.storage_class == "InfrequentAccess"
    error_message = "The bucket must preserve the requested default storage class."
  }
}
