-- ForeverMine runtime script.
--
-- An infinite resource mines at (amount / normal) speed. This script sets
-- each resource tile's amount so it reads the yield % chosen in
-- Settings > Mod settings > Map.
--
-- What 100% means:
--   ores:   normal drill speed (same as vanilla)
--   fluids: each field's own starting yield (same as vanilla)

local resources = require("resources")

---------------------------------------------------------------------------
-- Which resources this mod manages (only the ones with Infinite ticked)
---------------------------------------------------------------------------

local function get_names(list_name)
  local names = {}
  local entry = prototypes.mod_data["forever-mine-managed"]
  for name, _ in pairs(entry.data[list_name]) do
    if prototypes.entity[name] then
      table.insert(names, name)
    end
  end
  return names
end

local function get_all_names()
  local names = get_names("ores")
  for _, name in pairs(get_names("fluids")) do
    table.insert(names, name)
  end
  return names
end

local function is_fluid(name)
  local entry = prototypes.mod_data["forever-mine-managed"]
  return entry.data.fluids[name] == true
end

-- The yield % for one resource: its own setting if it has one, otherwise
-- the "other" setting.
local function get_yield(name)
  local setting = settings.global[resources.YIELD_PREFIX .. name]
  if setting == nil then
    setting = settings.global[resources.YIELD_PREFIX .. "other"]
  end
  return setting.value
end

---------------------------------------------------------------------------
-- Setting amounts
---------------------------------------------------------------------------

-- Set resource tiles in the area (or the whole surface if area is nil) to
-- their chosen yield %. Only the resources listed in names are touched.
local function fix_resources(surface, area, names)
  if #names == 0 then
    return
  end

  local found = surface.find_entities_filtered({ area = area, type = "resource", name = names })
  for _, resource in pairs(found) do
    local yield = get_yield(resource.name)

    -- The amount that counts as 100% for this tile.
    local base
    if is_fluid(resource.name) then
      base = resource.initial_amount
    end
    if base == nil then
      base = resource.prototype.normal_resource_amount
    end

    local wanted = math.floor(base * yield / 100)

    -- Vanilla fluids have a lowest allowed amount; don't go under it.
    local lowest = resource.prototype.minimum_resource_amount
    if wanted < lowest then
      wanted = lowest
    end
    if wanted < 1 then
      wanted = 1
    end

    if resource.amount ~= wanted then
      resource.amount = wanted
    end
  end
end

local function fix_all_surfaces(names)
  for _, surface in pairs(game.surfaces) do
    fix_resources(surface, nil, names)
  end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

-- New chunks: fix resources as soon as the chunk is generated.
script.on_event(defines.events.on_chunk_generated, function(event)
  fix_resources(event.surface, event.area, get_all_names())
end)

-- Mod added to a save, mod updated, startup settings changed, or other mods
-- added/removed.
script.on_init(function()
  fix_all_surfaces(get_all_names())
end)

script.on_configuration_changed(function()
  fix_all_surfaces(get_all_names())
end)

-- A yield setting was changed in the menu: update only what it affects.
script.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
  local prefix = resources.YIELD_PREFIX
  if string.sub(event.setting, 1, #prefix) ~= prefix then
    return
  end

  local affected = {}
  for _, name in pairs(get_all_names()) do
    local has_own_setting = settings.global[prefix .. name] ~= nil
    if event.setting == prefix .. name then
      table.insert(affected, name)
    elseif event.setting == prefix .. "other" and not has_own_setting then
      table.insert(affected, name)
    end
  end

  fix_all_surfaces(affected)
end)
