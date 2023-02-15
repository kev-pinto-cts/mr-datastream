variable "spanner_config" {
  description = "A list of n spanner Instances and Databases Specified in YAML"
}

variable "env" {
  type        = string
  description = "Target Env (dev/test/uat/prod)"
}

variable "sql_admins" {
  type        = list(string)
  description = "Admins must have nwmworld.com address"
  validation {
    condition     = can(regex("^[A-Za-z0-9._%+-]+@nwmworld.com$", var.sql_admins[0]))
    error_message = "Not a valid Natwest email"
  }
}

variable "sql_sa" {
  type        = list(string)
  description = "Application service accounts"
  validation {
    condition     = can(regex("^[A-Za-z0-9._%+-]+@.*gserviceaccount.com$", var.sql_sa[0]))
    error_message = "Not a valid service account email"
  }
}
