# ============================================================================
# Local Variables – Core Configuration & Tagging
# ============================================================================
# Defines foundational local variables used across the module.
#
# Responsibilities:
# - Loads and parses the external bot configuration JSON
# - Standardizes tagging strategy for all AWS resources
#
# Why this matters:
# - Decouples bot definition from Terraform code (JSON-driven design)
# - Enables reuse across environments (dev, qa, prod)
# - Ensures consistent tagging for governance, billing, and auditing
# ============================================================================

locals {
  # --------------------------------------------------------------------------
  # Standard Tags
  # --------------------------------------------------------------------------
  # Applies consistent tagging across all AWS resources.
  #
  # Benefits:
  # - Cost allocation (AWS Cost Explorer)
  # - Resource tracking
  # - Governance & compliance
  #
  # Recommended Best Practice:
  # - Keep tag keys consistent across all modules
  #
  tags = merge(
    {
      MANAGED_BY       = "Terraform"
      ENVIRONMENT      = var.environment
      AWS_REGION       = var.aws_region
      AWS_ACCOUNT_NAME = var.aws_account_name
      AWS_ACCOUNT_ID   = var.aws_account_id
    }
  )
}
