variable "name" {
  type        = string
  description = "Name of the bucket"
}

variable "account_id" {
  type        = string
  description = "Account ID"
  sensitive   = true
}

variable "jurisdiction" {
  type        = string
  description = "Jurisdiction where objects in this bucket are guaranteed to be stored. Available values: 'default', 'eu', 'fedramp', 'us'"
  default     = null
}

variable "location" {
  type        = string
  description = "Location of the bucket. Available values: apac, eeur, enam, weur, wnam, oc."
  default     = null
}

variable "storage_class" {
  type        = string
  description = "Storage class for newly uploaded objects, unless specified otherwise. Available values: 'Standard', 'InfrequentAccess'."
  default     = null
}
