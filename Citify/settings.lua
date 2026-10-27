-- Map-wide settings, so everyone in a multiplayer game sees the same city.
data:extend({
  {
    type = "double-setting",
    name = "citify-brightness",
    setting_type = "runtime-global",
    default_value = 0.6,
    minimum_value = 0.1,
    maximum_value = 1,
    order = "a"
  },
  {
    type = "string-setting",
    name = "citify-color",
    setting_type = "runtime-global",
    default_value = "warm",
    allowed_values = { "warm", "sodium", "white", "cool" },
    order = "b"
  },
  {
    type = "bool-setting",
    name = "citify-powered-only",
    setting_type = "runtime-global",
    default_value = true,
    order = "c"
  },
  {
    -- Fine-tunes how far the glow reaches, in case it looks a little big or
    -- small. 100% means the glow ends at the edge of the supply area.
    type = "int-setting",
    name = "citify-glow-size",
    setting_type = "runtime-global",
    default_value = 100,
    minimum_value = 50,
    maximum_value = 200,
    order = "d"
  }
})
