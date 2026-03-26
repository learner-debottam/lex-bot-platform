# # First, create a map of intents keyed by bot_id + locale + name
# locals {
#   intents_map = {
#     for intent in var.intents_config :
#     "${intent.name}-${intent.locale}" => intent
#   }
# }

# # Fetch the intent IDs for your bot
# data "aws_lex_intent" "intents" {
#   for_each = local.intents_map
#   name = each.value.name
# }

# resource "aws_lexv2models_intent" "update_priorities" {
#   for_each = local.intents_map

#   name        = each.value.name
#   description = lookup(each.value, "description", null)
#   locale_id   = each.value.locale
#   bot_id      = var.bot_id
#   bot_version  = var.bot_version
#   # other required attributes like sample_utterances etc.

#   dynamic "slot_priority" {
#     for_each = [
#       for slot_name, slot_data in each.value.slots :
#       slot_data if slot_data.slot_id != null
#     ]

#     content {
#       priority = slot_priority.value.priority
#       slot_id  = slot_priority.value.slot_id
#     }
#   }
# }

# Map of intents keyed by name-locale
locals {
  intents_map = {
    for intent in var.intents :
    "${intent.name}-${intent.locale}" => intent
  }

  # Group slots by intent_id
  slots_by_intent = {
    for intent_key, intent in local.intents_map :
    intent_key => [
      for slot_key, slot in var.slots :
      slot if slot.intent_id == intent.intent_id
    ]
  }
}

# Update intent slot priorities dynamically
//resource "aws_lexv2models_intent" "update_priorities" {
# resource "aws_lexv2models_intent" "intents" {
#   for_each = local.intents_map

#   name        = each.value.name
#   description = lookup(each.value, "description", null)
#   locale_id   = each.value.locale
#   bot_id      = var.bot_id
#   bot_version = "DRAFT" //var.bot_version

#   # other required attributes like sample_utterances etc.

#   dynamic "slot_priority" {
#     for_each = local.slots_by_intent[each.key]

#     content {
#       priority = slot_priority.key + 1  # sequential priority
#       slot_id  = slot_priority.value.slot_id
#     }
#   }
# }