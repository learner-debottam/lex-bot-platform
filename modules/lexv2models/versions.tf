# ============================================================================
# Terraform Provider Configuration
# ============================================================================
# Defines the required providers for this module.
#
# In this module:
# - AWS provider is used to provision all Lex V2 resources
#
# Version Strategy:
# - ">= 6.20" ensures compatibility with newer AWS provider releases
# - Lex V2 resources are relatively recent, so older versions may lack support
#
# Best Practice:
# - Use a minimum version constraint in modules
# - Pin exact versions in root modules for stability (e.g., = 6.25.0)
#
# NOTE:
# - Ensure your root module configures AWS credentials and region
#   (this module assumes provider configuration is inherited)
# ============================================================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.20"
    }
  }
}