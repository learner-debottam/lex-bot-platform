# ============================================================================
# Local Variables – Data Transformation Layer
# ============================================================================
# This section converts the user-provided JSON configuration (var.bot_config)
# into flattened, Terraform-friendly data structures.
#
# Why this is needed:
# - AWS Lex resources require iteration (for_each), but JSON is deeply nested
# - Terraform works best with flat, predictable maps/lists
# - Lex has strict naming constraints (length, allowed characters)
#
# What this layer handles:
# - Appending environment suffix to bot name
# - Flattening nested locale → intent → slot structures
# - Generating Lex-compliant IDs (sanitized + truncated)
# - Safely handling optional configurations (prompts, responses, Lambda hooks)
# - Mapping slot types correctly across locales
#
# Design Goals:
# - Zero runtime errors from missing keys
# - Fully dynamic (driven entirely by JSON input)
# - AWS Lex constraint compliance
# - Clean separation between input schema and Terraform resources
# ============================================================================

locals {

  # ==========================================================================
  # Bot Name (Environment-Aware)
  # ==========================================================================
  # Ensures unique bot names per environment (e.g., dev, qa, prod)
  # Example: insurance-bot-dev
  //bot_name = "${var.bot_config.name}-${var.environment}"
  bot_name = var.bot_config.name

  # ==========================================================================
  # Locales (Direct Mapping)
  # ==========================================================================
  # Extracts all locale configurations from input JSON.
  # This acts as the base structure for all downstream transformations.
  locales = var.bot_config.locales


  # ==========================================================================
  # Slot Types (Flattened Structure)
  # ==========================================================================
  # Transforms:
  #   locales → slot_types → values
  #
  # Into a flat list of slot type objects for Terraform iteration.
  #
  # Key Enhancements:
  # - Generates Lex-compliant IDs (max 100 chars, alphanumeric + underscore)
  # - Supports dynamic value selection strategy:
  #     • ExpandValues (default → flexible NLP)
  #     • RestrictToSlotValues (strict matching)
  #
  # slot_types = flatten([
  #   for locale, locale_data in local.locales : [
  #     for slot_type_name, slot_type_data in lookup(locale_data, "slot_types", {}) : {

  #       locale      = locale
  #       name        = slot_type_name
  #       description = lookup(slot_type_data, "description", "")
  #       values      = slot_type_data.values

  #       # Value selection strategy (controls Lex behavior)
  #       value_selection_strategy = lookup(
  #         slot_type_data,
  #         "value_selection_strategy",
  #         "ExpandValues"
  #       )

  #       # Lex-compliant ID (max 100 chars, only letters/numbers/underscore)
  #       lex_id = substr(
  #         replace(slot_type_name, "/[^0-9a-zA-Z_]/", ""),
  #         0,
  #         100
  #       )
  #     }
  #   ]
  # ])
  #   slot_types = flatten([
  #   for locale, locale_data in local.locales : [
  #     for slot_type_name, slot_type_data in lookup(locale_data, "slot_types", {}) : {

  #       locale      = locale
  #       name        = slot_type_name
  #       description = lookup(slot_type_data, "description", "")

  #       # Normalize values: ensure each entry is an object { value, synonyms }
  #       values = [
  #         for v in slot_type_data.values : (
  #           # If v is a string, wrap it into an object; if already object, keep as-is
  #           type(v) == string ? { value = v, synonyms = [] } : v
  #         )
  #       ]

  #       # Value selection strategy (controls Lex behavior)
  #       value_selection_strategy = lookup(
  #         slot_type_data,
  #         "value_selection_strategy",
  #         "ExpandValues"
  #       )

  #       # Lex-compliant ID (max 100 chars, only letters/numbers/underscore)
  #       lex_id = substr(
  #         replace(slot_type_name, "/[^0-9a-zA-Z_]/", ""),
  #         0,
  #         100
  #       )
  #     }
  #   ]
  # ])

  # slot_types = flatten([ 
  #   for locale, locale_data in local.locales : [ 
  #     for slot_type_name, slot_type_data in lookup(locale_data, "slot_types", {}) : { 
  #       locale = locale 
  #       name = slot_type_name 
  #       description = lookup(slot_type_data, "description", "") 
  #       values = slot_type_data.values 
  #       # Value selection strategy (controls Lex behavior) 
  #       value_selection_strategy = lookup( slot_type_data, "value_selection_strategy", "ExpandValues" ) 
  #       # Lex-compliant ID (max 100 chars, only letters/numbers/underscore) 
  #       lex_id = substr( replace(slot_type_name, "/[^0-9a-zA-Z_]/", ""), 0, 100 ) 
  #       } 
  #       ] 
  #     ]
  #   )
  # ==========================================================================
  # Slot Types (Flattened & Normalized – Fixed Type Issue)
  # ==========================================================================
  # ==========================================================================
  # Slot Types (Flattened & Normalized – Terraform-safe)
  # ==========================================================================
  # ==========================================================================
  # Slot Types (Flattened & Normalized – Terraform-safe)
  # ==========================================================================
  # ==========================================================================
  # Slot Types (Flattened & Normalized – Terraform-safe)
  # ==========================================================================
  # ==========================================================================
  # Slot Types (Flattened & Normalized – Terraform-safe)
  # ==========================================================================
  slot_types = flatten([
    for locale, locale_data in local.locales : [
      for slot_type_name, slot_type_data in lookup(locale_data, "slot_types", {}) : {

        locale      = locale
        name        = slot_type_name
        description = lookup(slot_type_data, "description", "")

        # ✅ FINAL FIX: normalize values safely
        values = [
          for v in slot_type_data.values : {
            value    = try(v.value, tostring(v))
            synonyms = try(v.synonyms, [])
          }
        ]

        value_selection_strategy = lookup(
          slot_type_data,
          "value_selection_strategy",
          "ExpandValues"
        )

        lex_id = substr(
          replace(slot_type_name, "/[^0-9a-zA-Z_]/", ""),
          0,
          100
        )
      }
    ]
  ])
  # ==========================================================================
  # Intents (Flattened + Sanitized)
  # ==========================================================================
  # Transforms:
  #   locales → intents
  #
  # Into a flat structure suitable for Terraform resources.
  #
  # Key Features:
  # - Handles optional fields safely using lookup() and contains()
  # - Normalizes all prompt/response configurations
  # - Generates Lex-safe intent IDs
  # - Supports Lambda fulfillment integration
  #
  intents = flatten([
    for locale, locale_data in local.locales : [
      for intent_name, intent_data in lookup(locale_data, "intents", {}) : {

        locale            = locale
        name              = intent_name
        description       = lookup(intent_data, "description", "")
        sample_utterances = lookup(intent_data, "sample_utterances", [])
        slots             = lookup(intent_data, "slots", {})

        # Optional Lambda association (used for fulfillment hooks)
        fulfillment_lambda_name = lookup(intent_data, "fulfillment_lambda_name", null)


        # ----------------------------------------------------------------------
        # Confirmation Prompt (User confirmation before action)
        # ----------------------------------------------------------------------
        confirmation_prompt = contains(keys(intent_data), "confirmation_prompt") ? {
          message                    = lookup(intent_data.confirmation_prompt, "message", "")
          variations                 = lookup(intent_data.confirmation_prompt, "variations", [])
          message_selection_strategy = lookup(intent_data.confirmation_prompt, "message_selection_strategy", "Ordered")
          max_retries                = lookup(intent_data.confirmation_prompt, "max_retries", 1)
        } : null


        # ----------------------------------------------------------------------
        # Confirmation Response (When user confirms intent)
        # ----------------------------------------------------------------------
        confirmation_response = contains(keys(intent_data), "confirmation_response") ? {
          message    = lookup(intent_data.confirmation_response, "message", "")
          variations = lookup(intent_data.confirmation_response, "variations", [])
        } : null


        # ----------------------------------------------------------------------
        # Declination Response (When user rejects intent)
        # ----------------------------------------------------------------------
        declination_response = contains(keys(intent_data), "declination_response") ? {
          message    = lookup(intent_data.declination_response, "message", "")
          variations = lookup(intent_data.declination_response, "variations", [])
        } : null


        # ----------------------------------------------------------------------
        # Failure Response (When user input cannot be understood)
        # ----------------------------------------------------------------------
        failure_response = contains(keys(intent_data), "failure_response") ? {
          message    = lookup(intent_data.failure_response, "message", "")
          variations = lookup(intent_data.failure_response, "variations", [])
        } : null


        # ----------------------------------------------------------------------
        # Closing Prompt (Final message after fulfillment)
        # ----------------------------------------------------------------------
        # Notes:
        # - Variations are capped to 2 (Lex limitation)
        # - SSML is optional and used for voice responses
        #
        closing_prompt = contains(keys(intent_data), "closing_prompt") ? {
          message      = lookup(intent_data.closing_prompt, "message", "")
          variations   = slice(lookup(intent_data.closing_prompt, "variations", []), 0, 2)
          ssml_message = lookup(intent_data.closing_prompt, "ssml_message", "")
        } : null


        # Lex-compliant intent ID (max 100 chars, alphanumeric only)
        lex_id = substr(
          replace(intent_name, "/[^0-9a-zA-Z]/", ""),
          0,
          100
        )
      }
    ]
  ])


  # ==========================================================================
  # Slots (Flattened + Cross-Referenced)
  # ==========================================================================
  # Transforms:
  #   intents → slots
  #
  # Into a flat structure with resolved references to:
  # - Intent IDs
  # - Slot Type IDs
  #
  # Key Feature:
  # - Dynamically resolves slot_type → lex_id mapping per locale
  # - Falls back to raw slot_type if no custom type is found
  #
  slots = flatten([
    for intent in local.intents : [
      for slot_name, slot_data in intent.slots : {

        locale      = intent.locale
        intent      = intent.name
        name        = slot_name
        description = lookup(slot_data, "description", "")
        slot_type   = slot_data.slot_type
        required    = slot_data.required
        prompt      = slot_data.prompt

        # Reference to sanitized intent ID
        lex_intent_id = intent.lex_id

        # Resolve slot type to its Lex-compliant ID
        lex_slot_type_id = lookup(
          {
            for st in local.slot_types :
            "${st.locale}-${st.name}" => st.lex_id
          },
          "${intent.locale}-${slot_data.slot_type}",
          slot_data.slot_type
        )
      }
    ]
  ])

  # ==========================================================================
  # Lambda ARN Mapping (NEW)
  # ==========================================================================
  # Maps intent -> Lambda ARN (from external module or input)

  lambda_map = {
    for intent in local.intents :
    "${intent.locale}-${intent.name}" => lookup(var.lambda_arns, intent.fulfillment_lambda_name, null)
    if intent.fulfillment_lambda_name != null
  }
}