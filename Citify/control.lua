-- Citify: power poles light up their supply area like streetlights.
--
-- Each pole gets one soft glow attached to it. Because the glow is attached
-- to the pole, the game removes it automatically when the pole is mined or
-- destroyed. Once a second, each power network is checked once, and its
-- lights turn off if no power moved through it recently.

-- How many tiles across the glow texture covers at normal size. Tuned in game
-- so the glow's soft fade reaches the edge of each pole's supply area.
local GLOW_TILES_ACROSS = 4

local COLORS = {
  warm = { r = 1, g = 0.85, b = 0.6 },
  sodium = { r = 1, g = 0.65, b = 0.3 },
  white = { r = 1, g = 1, b = 1 },
  cool = { r = 0.75, g = 0.85, b = 1 }
}

local POLE_FILTER = { { filter = "type", type = "electric-pole" } }

-- Helpers ------------------------------------------------------------------------

-- How far this pole's supply area reaches from its center, in tiles.
-- Uses the pole's quality when the game supports it.
local function get_supply_radius(pole)
  local prototype = pole.prototype

  local ok, distance = pcall(function()
    return prototype.get_supply_area_distance(pole.quality)
  end)
  if ok and distance then
    return distance
  end

  ok, distance = pcall(function()
    return prototype.supply_area_distance
  end)
  if ok and distance then
    return distance
  end

  return 0
end

-- Did any power flow through this pole's network in the last 5 seconds?
-- If the check itself fails for any reason, say yes, so lights never vanish
-- because of an error.
local function network_has_power(pole)
  local ok, has_power = pcall(function()
    local stats = pole.electric_network_statistics
    local precision = defines.flow_precision_index.five_seconds

    for _, category in pairs({ "input", "output" }) do
      local counts = stats.input_counts
      if category == "output" then
        counts = stats.output_counts
      end

      for name in pairs(counts) do
        local flow = stats.get_flow_count({
          name = name,
          category = category,
          precision_index = precision
        })
        if flow > 0 then
          return true
        end
      end
    end

    return false
  end)

  if ok then
    return has_power
  end
  return true
end

-- Lights ------------------------------------------------------------------------

local function add_light(pole)
  if not (pole and pole.valid) then
    return
  end

  local radius = get_supply_radius(pole)
  if radius <= 0 then
    return
  end

  -- Replace any old light (for example, after a setting change).
  local old = storage.lights[pole.unit_number]
  if old and old.light.valid then
    old.light.destroy()
  end

  local size = settings.global["citify-glow-size"].value / 100
  local light = rendering.draw_light({
    sprite = "citify-glow",
    scale = radius * 2 / GLOW_TILES_ACROSS * size,
    intensity = settings.global["citify-brightness"].value,
    color = COLORS[settings.global["citify-color"].value] or COLORS.warm,
    target = pole,
    surface = pole.surface
  })

  if settings.global["citify-powered-only"].value then
    light.visible = network_has_power(pole)
  end

  storage.lights[pole.unit_number] = { pole = pole, light = light }
end

-- Turn each network's lights on or off depending on whether it has power.
local function update_power()
  local powered_only = settings.global["citify-powered-only"].value
  local network_power = {}

  for unit, entry in pairs(storage.lights) do
    if not (entry.pole.valid and entry.light.valid) then
      -- The pole is gone. Its light was removed with it.
      if entry.light.valid then
        entry.light.destroy()
      end
      storage.lights[unit] = nil

    elseif powered_only then
      -- Check each network only once, no matter how many poles it has.
      local network = entry.pole.electric_network_id or ("pole " .. unit)
      local powered = network_power[network]
      if powered == nil then
        powered = network_has_power(entry.pole)
        network_power[network] = powered
      end

      if entry.light.visible ~= powered then
        entry.light.visible = powered
      end
    end
  end
end

-- Remove every light and make new ones for every pole on every surface.
local function rebuild_all_lights()
  rendering.clear("Citify")
  storage.lights = {}

  for _, surface in pairs(game.surfaces) do
    local poles = surface.find_entities_filtered({ type = "electric-pole" })
    for _, pole in pairs(poles) do
      add_light(pole)
    end
  end
end

-- Events ------------------------------------------------------------------------

script.on_init(function()
  storage.lights = {}
  rebuild_all_lights()
end)

script.on_configuration_changed(function()
  storage.lights = storage.lights or {}
  rebuild_all_lights()
end)

script.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
  if string.sub(event.setting, 1, 7) == "citify-" then
    rebuild_all_lights()
  end
end)

local function on_pole_built(event)
  add_light(event.entity or event.destination)
end

script.on_event(defines.events.on_built_entity, on_pole_built, POLE_FILTER)
script.on_event(defines.events.on_robot_built_entity, on_pole_built, POLE_FILTER)
script.on_event(defines.events.script_raised_built, on_pole_built, POLE_FILTER)
script.on_event(defines.events.script_raised_revive, on_pole_built, POLE_FILTER)
script.on_event(defines.events.on_entity_cloned, on_pole_built, POLE_FILTER)
if defines.events.on_space_platform_built_entity then
  script.on_event(defines.events.on_space_platform_built_entity, on_pole_built, POLE_FILTER)
end

script.on_nth_tick(60, update_power)
