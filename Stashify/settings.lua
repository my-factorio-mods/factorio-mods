-- How far (in tiles) to look for chests around the player.
-- Dropdown values have to be strings, so control.lua turns it back into a number.
local new_settings = {
  {
    type = "string-setting",
    name = "stashify-range",
    setting_type = "runtime-per-user",
    default_value = "10",
    allowed_values = { "10", "15", "20", "25", "30", "35", "40", "45", "50" },
    order = "a"
  }
}

-- One on/off setting per logistic chest type. All off by default, so items
-- only go into regular chests unless the player opts in.
-- These names match each chest's logistic mode in the game.
local logistic_modes = { "active-provider", "passive-provider", "storage", "buffer", "requester" }

for index, mode in pairs(logistic_modes) do
  table.insert(new_settings, {
    type = "bool-setting",
    name = "stashify-logistic-" .. mode,
    setting_type = "runtime-per-user",
    default_value = false,
    order = "b-" .. index
  })
end

data:extend(new_settings)
