-- All settings are per player, so everyone picks their own.
data:extend({
  {
    type = "bool-setting",
    name = "squadify-enabled",
    setting_type = "runtime-per-user",
    default_value = true,
    order = "a"
  },
  {
    type = "bool-setting",
    name = "squadify-only-near-enemies",
    setting_type = "runtime-per-user",
    default_value = true,
    order = "b"
  },
  {
    type = "int-setting",
    name = "squadify-range",
    setting_type = "runtime-per-user",
    default_value = 20,
    minimum_value = 10,
    maximum_value = 50,
    order = "c"
  },
  -- One cap per robot type. 0 means never use that capsule.
  {
    type = "int-setting",
    name = "squadify-cap-destroyer",
    setting_type = "runtime-per-user",
    default_value = 0,
    minimum_value = 0,
    maximum_value = 1000,
    order = "d-1"
  },
  {
    type = "int-setting",
    name = "squadify-cap-defender",
    setting_type = "runtime-per-user",
    default_value = 0,
    minimum_value = 0,
    maximum_value = 1000,
    order = "d-2"
  },
  {
    type = "int-setting",
    name = "squadify-cap-distractor",
    setting_type = "runtime-per-user",
    default_value = 0,
    minimum_value = 0,
    maximum_value = 1000,
    order = "d-3"
  }
})
