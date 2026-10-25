-- How far (in tiles) to look for chests around the player.
-- Dropdown values have to be strings, so control.lua turns it back into a number.
data:extend({
  {
    type = "string-setting",
    name = "stashify-range",
    setting_type = "runtime-per-user",
    default_value = "10",
    allowed_values = { "10", "15", "20", "25", "30", "35", "40", "45", "50" }
  }
})
