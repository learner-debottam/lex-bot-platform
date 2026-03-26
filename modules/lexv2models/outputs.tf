output "bot_id" {
  value = aws_lexv2models_bot.this.id
}
output "bot_name" {
  value = aws_lexv2models_bot.this.name
}

output "bot_version" {
  value = aws_lexv2models_bot_version.this.bot_version
}

output "locales" {
  description = "Locales configured on the bot (keys are locale IDs such as en_US, en_GB)"
  value       = keys(local.locales)
}

output "intents" {
  value = {
    for k, v in aws_lexv2models_intent.intents :
    k => {
      intent_id = v.intent_id
      name      = v.name
      locale    = v.locale_id
    }
  }
}

output "slots" {
  value = {
    for k, v in aws_lexv2models_slot.slots :
    k => {
      slot_id   = v.slot_id
      name      = v.name
      intent_id = v.intent_id
      locale    = v.locale_id
    }
  }
}

# VERY IMPORTANT → pass original structure
output "intents_config" {
  value = local.intents
}