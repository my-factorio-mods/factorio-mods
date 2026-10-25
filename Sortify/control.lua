-- Finds the inventory to sort for an entity, based on the player's settings.
-- Returns nil if this entity should not be sorted.
local function get_sortable_inventory(entity, settings)
  -- Regular chests (wooden, iron, steel) and all logistic chests.
  if entity.type == "container" or entity.type == "logistic-container" then
    return entity.get_inventory(defines.inventory.chest)
  end

  if entity.type == "cargo-wagon" and settings["sortify-cargo-wagons"].value then
    return entity.get_inventory(defines.inventory.cargo_wagon)
  end

  if settings["sortify-vehicles"].value then
    -- "car" covers both the car and the tank.
    if entity.type == "car" then
      return entity.get_inventory(defines.inventory.car_trunk)
    end
    if entity.type == "spider-vehicle" then
      return entity.get_inventory(defines.inventory.spider_trunk)
    end
  end

  if settings["sortify-space-age"].value then
    if entity.type == "space-platform-hub" then
      return entity.get_inventory(defines.inventory.hub_main)
    end
    if entity.type == "cargo-landing-pad" then
      return entity.get_inventory(defines.inventory.cargo_landing_pad_main)
    end
  end

  return nil
end

-- How often to re-sort an open chest. 60 ticks = 1 second, so 10 is 6 times a second.
local SORT_INTERVAL_TICKS = 10

-- Sorts whatever entity this player has open, if it's something we sort.
local function tidy_open_entity(player)
  -- Only care about entity windows (not the inventory screen, map, etc.)
  if player.opened_gui_type ~= defines.gui_type.entity then
    return
  end

  local entity = player.opened
  if not entity or not entity.valid then
    return
  end

  -- Each player has their own settings.
  local settings = player.mod_settings
  if not settings["sortify-enabled"].value then
    return
  end

  local inventory = get_sortable_inventory(entity, settings)
  if inventory then
    -- Merges partial stacks and sorts items into the game's standard order.
    inventory.sort_and_merge()
  end
end

-- Sort right away when the window opens, so it never looks messy.
script.on_event(defines.events.on_gui_opened, function(event)
  local player = game.get_player(event.player_index)
  if player then
    tidy_open_entity(player)
  end
end)

-- Keep sorting while the window stays open.
script.on_nth_tick(SORT_INTERVAL_TICKS, function()
  for _, player in pairs(game.connected_players) do
    tidy_open_entity(player)
  end
end)
