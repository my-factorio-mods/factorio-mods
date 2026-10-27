-- Map-wide setting: how many lamps to recolor per tick. Higher looks smoother
-- on huge shows but costs more performance.
data:extend({
  {
    type = "int-setting",
    name = "lumify-updates-per-tick",
    setting_type = "runtime-global",
    default_value = 500,
    minimum_value = 50,
    maximum_value = 5000
  }
})
