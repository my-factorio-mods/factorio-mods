-- The resources ForeverMine has settings for.
-- Shared by settings.lua, data-final-fixes.lua and control.lua.
--
-- Mod settings are created before the game knows which resources exist, so
-- this list is written out by hand. Ores from other mods use "other".

local resources = {}

-- Solid ores: these are finite in vanilla.
resources.ores = {
  "iron-ore",
  "copper-ore",
  "coal",
  "stone",
  "uranium-ore",
  -- Space Age
  "tungsten-ore",
  "calcite",
  "scrap",
}

-- Fluids: already infinite in vanilla, but they slowly deplete.
resources.fluids = {
  "crude-oil",
  -- Space Age
  "sulfuric-acid-geyser",
  "lithium-brine",
  "fluorine-vent",
}

-- Setting name prefixes.
resources.INFINITE_PREFIX = "forever-mine-infinite-"
resources.YIELD_PREFIX = "forever-mine-yield-"

return resources
