-- How far (in tiles) to look for chests around the player.
-- Dropdown values have to be strings, so control.lua turns it back into a number.
local new_settings = {
  {
    type = "string-setting",
    name = "stockify-range",
    setting_type = "runtime-per-user",
    default_value = "10",
    allowed_values = { "10", "15", "20", "25", "30", "35", "40", "45", "50" },
    order = "a"
  }
}

-- One on/off setting per logistic chest type. Requester and buffer chests are
-- holding items for a reason, so they're off by default.
-- These names match each chest's logistic mode in the game.
local logistic_defaults = {
  { mode = "active-provider", default = true },
  { mode = "passive-provider", default = true },
  { mode = "storage", default = true },
  { mode = "buffer", default = false },
  { mode = "requester", default = false }
}

for index, chest in pairs(logistic_defaults) do
  table.insert(new_settings, {
    type = "bool-setting",
    name = "stockify-logistic-" .. chest.mode,
    setting_type = "runtime-per-user",
    default_value = chest.default,
    order = "b-" .. index
  })
end

-- Other places Stockify can pull from.
table.insert(new_settings, {
  type = "bool-setting",
  name = "stockify-landing-pads",
  setting_type = "runtime-per-user",
  default_value = true,
  order = "c-1"
})

table.insert(new_settings, {
  type = "bool-setting",
  name = "stockify-vehicles",
  setting_type = "runtime-per-user",
  default_value = true,
  order = "c-2"
})

table.insert(new_settings, {
  type = "bool-setting",
  name = "stockify-cargo-wagons",
  setting_type = "runtime-per-user",
  default_value = false,
  order = "c-3"
})

data:extend(new_settings)
