# ============================================================================
# AWS Lex V2 – Bot (Root Resource)
# ============================================================================
# Creates the primary Lex V2 bot.
#
# Responsibilities:
# - Defines bot identity (name, description)
# - Associates IAM execution role
# - Configures data privacy settings
# - Sets session timeout behavior
#
# Naming Strategy:
# - Bot name is environment-aware (e.g., insurance-bot-dev, insurance-bot-prod)
# - Ensures uniqueness across environments
#
# Key Notes:
# - This resource only creates the "container" for the bot
# - Actual behavior is defined in:
#     • Locales
#     • Intents
#     • Slots
#
# Dependency:
# - Requires IAM role with proper permissions (defined separately)
# ============================================================================

resource "aws_lexv2models_bot" "this" {
  name        = local.bot_name
  description = lookup(var.bot_config, "description", "Lex bot managed by Terraform")

  # IAM role assumed by Lex to execute bot operations
  role_arn = aws_iam_role.lex_role.arn

  # Bot type:
  # - "Bot" (standard conversational bot)
  # - "BotNetwork" (advanced multi-bot orchestration)
  type = lookup(var.bot_config, "type", "Bot")

  # --------------------------------------------------------------------------
  # Data Privacy Settings
  # --------------------------------------------------------------------------
  # Determines whether the bot is directed toward children under 13.
  # This impacts compliance (e.g., COPPA).
  #
  # NOTE:
  # - Should ideally be boolean (true/false)
  # - Current lookup defaults to "true" (string) — ensure input consistency
  #
  data_privacy {
    child_directed = lookup(var.bot_config, "child_directed", true)
  }

  # Session timeout (in seconds)
  # Controls how long a conversation session remains active
  //idle_session_ttl_in_seconds = var.bot_config.idle_session_ttl
  //idle_session_ttl_in_seconds = lookup(each.value, "session_ttl", 300)
  idle_session_ttl_in_seconds = lookup(var.bot_config, "idle_session_ttl", 300)
  tags                        = var.tags
}


# ============================================================================
# AWS Lex V2 – Bot Locales
# ============================================================================
# Creates one locale per language/region defined in the input configuration.
#
# What is a Locale?
# - A locale defines:
#     • Language (e.g., en_GB, en_US)
#     • NLU model configuration
#     • Voice settings (optional)
#
# Behavior:
# - Each locale is independently configured and trained
# - Intents, slots, and slot types are scoped per locale
#
# Iteration Strategy:
# - Uses for_each over local.locales map
# - Each.key   → locale ID (e.g., en_GB)
# - Each.value → locale configuration object
#
# Important Notes:
# - All locales are created in DRAFT version initially
# - They are later included in bot version snapshots
# ============================================================================

resource "aws_lexv2models_bot_locale" "locales" {
  for_each = local.locales

  bot_id      = aws_lexv2models_bot.this.id
  bot_version = "DRAFT"

  # Locale identifier (must match Lex-supported formats, e.g., en_GB)
  locale_id = each.key

  description = lookup(each.value, "description", "Locale for ${each.key}")

  # --------------------------------------------------------------------------
  # NLU Confidence Threshold
  # --------------------------------------------------------------------------
  # Determines how confident Lex must be before selecting an intent.
  #
  # Typical values:
  # - 0.3 → more flexible, may misclassify
  # - 0.7 → stricter, more fallback responses
  #
  n_lu_intent_confidence_threshold = each.value.confidence_threshold


  # --------------------------------------------------------------------------
  # Optional Voice Settings (Text-to-Speech)
  # --------------------------------------------------------------------------
  # Enables voice responses using Amazon Polly.
  #
  # Dynamic block ensures:
  # - Only created if voice_settings exists in input JSON
  #
  # Supported engines:
  # - standard → lower cost
  # - neural   → higher quality voice
  #
  dynamic "voice_settings" {
    for_each = lookup(each.value, "voice_settings", null) == null ? [] : [each.value.voice_settings]
    content {
      voice_id = voice_settings.value.voice_id
      engine   = lookup(voice_settings.value, "engine", null)
    }
  }
}

# ============================================================================
# AWS Lex V2 – Build Bot Locale (NEW)
# ============================================================================
# Ensures the bot locale is BUILT before creating a version.
# Without this, Lex console shows "Not built" and versioning may fail.
# ============================================================================

# resource "null_resource" "build_bot" {

#   depends_on = [
#     aws_lexv2models_intent.intents,
#     aws_lexv2models_slot.slots
#   ]

#   provisioner "local-exec" {
#     command = <<EOT

# echo "Starting Lex bot build..."

# # Loop through all locales
# for LOCALE in ${join(" ", keys(local.locales))}
# do
#   echo "Building locale: $LOCALE"

#   aws lexv2-models build-bot-locale \
#     --bot-id ${aws_lexv2models_bot.this.id} \
#     --bot-version DRAFT \
#     --locale-id $LOCALE

#   echo "Waiting for build to complete for $LOCALE..."

#   while true; do
#     STATUS=$(aws lexv2-models describe-bot-locale \
#       --bot-id ${aws_lexv2models_bot.this.id} \
#       --bot-version DRAFT \
#       --locale-id $LOCALE \
#       --query 'botLocaleStatus' \
#       --output text)

#     echo "Locale $LOCALE status: $STATUS"

#     if [ "$STATUS" = "Built" ]; then
#       echo "Locale $LOCALE build complete!"
#       break
#     fi

#     if [ "$STATUS" = "Failed" ]; then
#       echo "Locale $LOCALE build FAILED!"
#       exit 1
#     fi

#     sleep 5
#   done

# done

# EOT
#   }
# }

# ============================================================================
# AWS Lex V2 – Bot Version
# ============================================================================
# Creates a versioned snapshot of the Lex bot based on the current DRAFT state.
#
# Why this is important:
# - Lex bots operate in two modes:
#     • DRAFT → editable working version
#     • VERSION → immutable, deployable snapshot
#
# - A version is REQUIRED for:
#     • Creating bot aliases
#     • Promoting changes to environments (dev → qa → prod)
#
# Behavior:
# - Captures all configured locales from the DRAFT version
# - Automatically includes:
#     • Intents
#     • Slots
#     • Slot types
#
# Versioning Strategy:
# - Uses timestamp-based description for traceability
# - Each apply creates a new version if dependencies change
#
# Dependency Handling:
# - Explicit depends_on ensures:
#     • All intents are created
#     • All slots are created
#   before version snapshot is taken
#
# Optional Lifecycle Controls (commented out):
# - prevent_destroy → protects versions from accidental deletion
# - create_before_destroy → avoids downtime during updates
#
# NOTE:
# - Versions are immutable once created
# - Deleting a version may break aliases pointing to it
# ============================================================================

resource "aws_lexv2models_bot_version" "this" {
  bot_id = aws_lexv2models_bot.this.id

  # Human-readable version description (timestamp-based for uniqueness)
  //description = "Version created at ${timestamp()}"
  description = "Stable version"  # stable description
  # Include all locales from the DRAFT bot version
  locale_specification = {
    for locale_id, _ in local.locales : locale_id => {
      source_bot_version = "DRAFT"
    }
  }

  # --------------------------------------------------------------------------
  # OPTIONAL: Protect version from accidental deletion
  # --------------------------------------------------------------------------
  lifecycle {
  //  prevent_destroy = true
    create_before_destroy = true
  }

  # --------------------------------------------------------------------------
  # OPTIONAL: Ensure zero-downtime updates when replacing versions
  # --------------------------------------------------------------------------
  # lifecycle {
  #   create_before_destroy = true
  # }

  # Ensure all dependent resources are created before versioning
  depends_on = [
    aws_lexv2models_intent.intents,
    aws_lexv2models_slot.slots
  //  null_resource.build_bot
  //null_resource.update_slot_priorities
  ]
}

# ============================================================================
# AWS Lex V2 – Intents
# ============================================================================
# Creates all intents across all locales defined in the bot configuration.
#
# What is an Intent?
# - Represents a user goal (e.g., BuyInsurance, FileClaim)
# - Contains:
#     • Sample utterances (training phrases)
#     • Slots (data to collect)
#     • Fulfillment logic (Lambda hook)
#     • Conversation flow (confirmation, closing, etc.)
#
# Key Features Implemented:
# - Dynamic fulfillment hook enablement
# - Rich confirmation flow:
#     • confirmation_prompt
#     • confirmation_response
#     • declination_response
#     • failure_response
# - Closing response support
# - Lex-compliant intent name sanitization
#
# Iteration Strategy:
# - Key format: "<locale>-<intent_name>"
# - Ensures uniqueness across locales
# ============================================================================

resource "aws_lexv2models_intent" "intents" {
  for_each = {
    for intent in local.intents :
    "${intent.locale}-${intent.name}" => intent
  }
  
  bot_id      = aws_lexv2models_bot.this.id
  bot_version = "DRAFT"
  locale_id   = each.value.locale

  # Lex-compliant sanitized name (max 100 chars, alphanumeric only)
  name        = each.value.lex_id
  description = each.value.description


  # --------------------------------------------------------------------------
  # Fulfillment Code Hook (Lambda Integration)
  # --------------------------------------------------------------------------
  # Enables Lambda execution when intent is fulfilled.
  #
  # NOTE:
  # - This only enables the hook at intent level
  # - Actual Lambda ARN is configured externally (not in this resource)
  #
  dynamic "fulfillment_code_hook" {
    for_each = each.value.fulfillment_lambda_name != null ? [1] : []
    content {
      enabled = true
    }
  }


  # --------------------------------------------------------------------------
  # Sample Utterances (Training Data)
  # --------------------------------------------------------------------------
  # Defines example phrases users may say to trigger this intent.
  #
  dynamic "sample_utterance" {
    for_each = each.value.sample_utterances
    content {
      utterance = sample_utterance.value
    }
  }

  dynamic "initial_response_setting" {
    for_each = each.value.fulfillment_lambda_name != null ? [1] : []
    content {
      code_hook {
        active                      = true
        enable_code_hook_invocation = true
      }
    }
  }
  
  # --------------------------------------------------------------------------
  # Confirmation Flow
  # --------------------------------------------------------------------------
  # Handles user confirmation before fulfillment.
  #
  # Includes:
  # - Prompt asking for confirmation
  # - Response if user confirms
  # - Response if user declines
  # - Response if confirmation fails
  #
  dynamic "confirmation_setting" {
    for_each = each.value.confirmation_prompt != null ? [each.value.confirmation_prompt] : []

    content {
      active = true

      # ---------------- Prompt ----------------
      prompt_specification {
        message_selection_strategy = each.value.confirmation_prompt.message_selection_strategy != null ? each.value.confirmation_prompt.message_selection_strategy : "Ordered"
        max_retries                = each.value.confirmation_prompt.max_retries != null ? each.value.confirmation_prompt.max_retries : 1

        message_group {
          message {
            plain_text_message {
              value = each.value.confirmation_prompt.message
            }
          }

          # Optional message variations (improves UX)
          dynamic "variation" {
            for_each = lookup(each.value.confirmation_prompt, "variations", [])
            content {
              plain_text_message {
                value = variation.value
              }
            }
          }
        }
      }

      # ---------------- Confirmation Response ----------------
      dynamic "confirmation_response" {
        for_each = each.value.confirmation_response != null ? [each.value.confirmation_response] : []
        content {
          message_group {
            message {
              plain_text_message {
                value = confirmation_response.value.message
              }
            }

            dynamic "variation" {
              for_each = lookup(confirmation_response.value, "variations", [])
              content {
                plain_text_message {
                  value = variation.value
                }
              }
            }
          }
        }
      }

      # ---------------- Declination Response ----------------
      dynamic "declination_response" {
        for_each = each.value.declination_response != null ? [each.value.declination_response] : []
        content {
          message_group {
            message {
              plain_text_message {
                value = declination_response.value.message
              }
            }

            dynamic "variation" {
              for_each = lookup(declination_response.value, "variations", [])
              content {
                plain_text_message {
                  value = variation.value
                }
              }
            }
          }
        }
      }

      # ---------------- Failure Response ----------------
      dynamic "failure_response" {
        for_each = each.value.failure_response != null ? [each.value.failure_response] : []
        content {
          message_group {
            message {
              plain_text_message {
                value = failure_response.value.message
              }
            }

            dynamic "variation" {
              for_each = lookup(failure_response.value, "variations", [])
              content {
                plain_text_message {
                  value = variation.value
                }
              }
            }
          }
        }
      }
    }
  }


  # --------------------------------------------------------------------------
  # Closing Response
  # --------------------------------------------------------------------------
  # Final message delivered after successful fulfillment.
  #
  # Enhances conversational UX by providing a clean exit message.
  #
  dynamic "closing_setting" {
    for_each = each.value.closing_prompt != null ? [1] : []

    content {
      active = true

      closing_response {
        message_group {
          message {
            plain_text_message {
              value = each.value.closing_prompt.message
            }
          }

          dynamic "variation" {
            for_each = each.value.closing_prompt.variations
            content {
              plain_text_message {
                value = variation.value
              }
            }
          }
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [
      closing_setting[0].closing_response[0].allow_interrupt
    ]
  }
  depends_on = [
    aws_lexv2models_bot_locale.locales
  ]
}

# ============================================================================
# AWS Lex V2 – Slot Types (Custom)
# ============================================================================
# Defines custom slot types used by intents.
#
# What is a Slot Type?
# - Defines allowed values for a slot (e.g., InsuranceType)
# - Supports synonyms for better NLU recognition
#
# Value Resolution Modes:
# - ExpandValues (default):
#     → Accepts values beyond defined list (training mode)
#
# - RestrictToSlotValues:
#     → Only accepts explicitly defined values
#
# Mapping to AWS:
# - ExpandValues        → OriginalValue
# - RestrictToSlotValues → TopResolution
# ============================================================================

resource "aws_lexv2models_slot_type" "slot_types" {
  for_each = {
    for st in local.slot_types :
    "${st.locale}-${st.name}" => st
  }

  bot_id      = aws_lexv2models_bot.this.id
  bot_version = "DRAFT"
  locale_id   = each.value.locale

  name        = each.value.lex_id
  description = each.value.description


  # --------------------------------------------------------------------------
  # Slot Values & Synonyms
  # --------------------------------------------------------------------------
  # Supports:
  # - Primary value
  # - Optional synonyms (improves recognition)
  #
  dynamic "slot_type_values" {
    for_each = each.value.values

    content {
      sample_value {
        value = slot_type_values.value.value
      }

      dynamic "synonyms" {
        for_each = lookup(slot_type_values.value, "synonyms", [])
        content {
          value = synonyms.value
        }
      }
    }
  }


  # --------------------------------------------------------------------------
  # Value Selection Strategy
  # --------------------------------------------------------------------------
  # Controls how Lex resolves user input:
  #
  # - OriginalValue:
  #     → Accepts free-form input (ExpandValues)
  #
  # - TopResolution:
  #     → Restricts to defined slot values
  #
  value_selection_setting {
    resolution_strategy = (
      each.value.value_selection_strategy == "RestrictToSlotValues"
      ? "TopResolution"
      : "OriginalValue"
    )
  }

  depends_on = [
    aws_lexv2models_bot_locale.locales
  ]
}


# ============================================================================
# AWS Lex V2 – Slots
# ============================================================================
# Creates slots within intents.
#
# What is a Slot?
# - A parameter required to fulfill an intent
# - Example:
#     Intent: BuyInsurance
#     Slots: insurance_type, coverage_amount
#
# Features:
# - Supports required/optional slots
# - Configurable prompts
# - Multi-modal input (text, audio, DTMF)
# - Retry handling with standardized configuration
# ============================================================================

resource "aws_lexv2models_slot" "slots" {
  for_each = {
    for slot in local.slots :
    "${slot.locale}-${slot.intent}-${slot.name}" => slot
  }

  bot_id      = aws_lexv2models_bot.this.id
  bot_version = "DRAFT"
  locale_id   = each.value.locale

  intent_id = aws_lexv2models_intent.intents["${each.value.locale}-${each.value.intent}"].intent_id

  name        = each.value.name
  description = each.value.description


  # --------------------------------------------------------------------------
  # Slot Type Resolution
  # --------------------------------------------------------------------------
  # Uses:
  # - Built-in AMAZON.* types directly
  # - Custom slot types via Terraform resource
  #
  slot_type_id = startswith(each.value.slot_type, "AMAZON.") ? each.value.slot_type : aws_lexv2models_slot_type.slot_types["${each.value.locale}-${each.value.slot_type}"].slot_type_id


  # --------------------------------------------------------------------------
  # Value Elicitation (Prompting User)
  # --------------------------------------------------------------------------
  value_elicitation_setting {
    slot_constraint = each.value.required ? "Required" : "Optional"

    prompt_specification {
      max_retries                = 2
      allow_interrupt            = true
      message_selection_strategy = "Random"

      message_group {
        message {
          plain_text_message {
            value = each.value.prompt
          }
        }
      }

      # ----------------------------------------------------------------------
      # Standardized Retry Behavior
      # ----------------------------------------------------------------------
      # Ensures consistent handling of retries across all slots
      #
      dynamic "prompt_attempts_specification" {
        for_each = ["Initial", "Retry1", "Retry2"]
        content {
          map_block_key   = prompt_attempts_specification.value
          allow_interrupt = true

          allowed_input_types {
            allow_audio_input = true
            allow_dtmf_input  = true
          }

          audio_and_dtmf_input_specification {
            start_timeout_ms = 4000

            audio_specification {
              max_length_ms  = 15000
              end_timeout_ms = 640
            }

            dtmf_specification {
              max_length         = 513
              end_timeout_ms     = 5000
              deletion_character = "*"
              end_character      = "#"
            }
          }

          text_input_specification {
            start_timeout_ms = 30000
          }
        }
      }
    }
  }


  # --------------------------------------------------------------------------
  # Lifecycle Customization
  # --------------------------------------------------------------------------
  # Prevents unnecessary diffs due to AWS-managed/defaulted values
  #
  lifecycle {
    ignore_changes = [
      value_elicitation_setting[0].prompt_specification[0].prompt_attempts_specification,
      value_elicitation_setting[0].prompt_specification[0].allow_interrupt,
      value_elicitation_setting[0].prompt_specification[0].message_selection_strategy,
    ]
  }

  depends_on = [
    aws_lexv2models_intent.intents,
    aws_lexv2models_slot_type.slot_types,
  ]
}
# Temporary disabled
# resource "null_resource" "version_and_alias" {

#   depends_on = [
#     aws_lexv2models_bot_version.this,
#    // null_resource.slot_priorities,
#   ]

#   provisioner "local-exec" {
#   command = <<EOT

# # Wait for version to be fully available
# sleep 10

# VERSION=${aws_lexv2models_bot_version.this.bot_version}

# echo "Using Terraform-created version: $VERSION"

# ALIAS_ID=$(aws lexv2-models list-bot-aliases \
#   --bot-id ${aws_lexv2models_bot.this.id} \
#   --query "botAliasSummaries[?botAliasName=='Live'].botAliasId" \
#   --output text)

# if [ -z "$ALIAS_ID" ]; then
#   aws lexv2-models create-bot-alias \
#     --bot-id ${aws_lexv2models_bot.this.id} \
#     --bot-version $VERSION \
#     --bot-alias-name "Live"
# else
#   aws lexv2-models update-bot-alias \
#     --bot-id ${aws_lexv2models_bot.this.id} \
#     --bot-alias-id $ALIAS_ID \
#     --bot-version $VERSION
# fi

# EOT
# }
# }
# # ============================================================================
# # AWS Lex Bot - Main Bot Resource
# # ============================================================================
# # Creates the primary Lex V2 bot with data privacy settings and session timeout.
# # The bot name is automatically suffixed with the environment (e.g., my-bot-dev).

# resource "aws_lexv2models_bot" "this" {
#   name        = local.bot_name
#   description = lookup(var.bot_config, "description", "Lex bot managed by Terraform")
#   role_arn    = aws_iam_role.lex_role.arn
#   type = lookup(var.bot_config, "type", "Bot")
#   data_privacy {
#     child_directed = lookup(var.bot_config, "child_directed", "true")
#   }

#   idle_session_ttl_in_seconds = var.bot_config.idle_session_ttl

#   tags = var.tags
# }

# # ============================================================================
# # Bot Locales
# # ============================================================================
# # Creates a locale for each language defined in the bot configuration.
# # Each locale has its own confidence threshold for NLU intent matching.

# resource "aws_lexv2models_bot_locale" "locales" {
#   for_each = local.locales

#   bot_id      = aws_lexv2models_bot.this.id
#   bot_version = "DRAFT"
#   locale_id   = each.key
#   description = lookup(each.value, "description", "Locale for ${each.key}")

#   n_lu_intent_confidence_threshold = each.value.confidence_threshold


#   dynamic "voice_settings" {
#     for_each = lookup(each.value, "voice_settings", null) == null ? [] : [each.value.voice_settings]
#     content {
#       voice_id = voice_settings.value.voice_id
#       engine   = lookup(voice_settings.value, "engine", null)
#     }
#   }
# }