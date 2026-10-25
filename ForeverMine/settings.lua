-- ForeverMine settings.
--
-- Infinite on/off checkboxes are "startup" settings (Settings > Mod settings >
-- Startup) because they change how resources are defined when the game loads.
-- Changing one needs a restart.
--
-- Yield % boxes are "runtime-global" settings (Settings > Mod settings > Map)
-- and can be changed while playing.

local resources = require("resources")

local new_settings = {}

local function add_settings(name, order)
  table.insert(new_settings, {
    type = "bool-setting",
    name = resources.INFINITE_PREFIX .. name,
    setting_type = "startup",
    default_value = true,
    order = order,
  })

  table.insert(new_settings, {
    type = "int-setting",
    name = resources.YIELD_PREFIX .. name,
    setting_type = "runtime-global",
    default_value = 100,
    minimum_value = 1,
    maximum_value = 500,
    order = order,
  })
end

for index, ore in pairs(resources.ores) do
  add_settings(ore, string.format("a-%02d", index))
end

add_settings("other", "b")

for index, fluid in pairs(resources.fluids) do
  add_settings(fluid, string.format("c-%02d", index))
end

data:extend(new_settings)
