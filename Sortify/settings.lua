-- All settings are per player, so you and your friend can each pick your own.
-- They show up under Settings > Mod settings > Per player, and can be changed mid-game.
data:extend({
  {
    type = "bool-setting",
    name = "sortify-enabled",
    setting_type = "runtime-per-user",
    default_value = true,
    order = "a",
  },
  {
    type = "bool-setting",
    name = "sortify-cargo-wagons",
    setting_type = "runtime-per-user",
    default_value = true,
    order = "b",
  },
  {
    type = "bool-setting",
    name = "sortify-vehicles",
    setting_type = "runtime-per-user",
    default_value = true,
    order = "c",
  },
  {
    type = "bool-setting",
    name = "sortify-space-age",
    setting_type = "runtime-per-user",
    default_value = true,
    order = "d",
  },
})
