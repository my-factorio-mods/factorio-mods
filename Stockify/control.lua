-- Stockify: fill the player's locked (filtered) inventory slots with items
-- pulled from nearby chests, nearest chests first.

-- Read a slot's filter as an item name, a quality name, and how the quality
-- is compared ("=" means exactly that quality). Returns nil if no filter.
local function get_slot_filter(inventory, index)
  local filter = inventory.get_filter(index)
  if not filter then
    return nil
  end

  -- Older style filters are just the item name.
  if type(filter) == "string" then
    return { name = filter, quality = "normal", comparator = "=" }
  end

  local quality = filter.quality
  if type(quality) ~= "string" then
    quality = quality and quality.name or "normal"
  end

  return {
    name = filter.name,
    quality = quality,
    comparator = filter.comparator or "="
  }
end

-- Does a quality pass the filter? Handles filters like "uncommon or better".
local function quality_allowed(quality_name, item)
  if item.comparator == "=" then
    return quality_name == item.quality
  end

  local level = prototypes.quality[quality_name].level
  local wanted = prototypes.quality[item.quality].level
  local c = item.comparator

  if c == ">" then return level > wanted end
  if c == "<" then return level < wanted end
  if c == ">=" or c == "≥" then return level >= wanted end
  if c == "<=" or c == "≤" then return level <= wanted end
  if c == "!=" or c == "≠" then return level ~= wanted end

  return quality_name == item.quality
end

-- Can this chest stack go into this player slot?
local function can_take(source, slot, item)
  if not source.valid_for_read or source.name ~= item.name then
    return false
  end

  if not quality_allowed(source.quality.name, item) then
    return false
  end

  -- A partly filled slot can only take more of the same quality.
  if slot.valid_for_read and slot.quality.name ~= source.quality.name then
    return false
  end

  return true
end

-- Get the inventory Stockify is allowed to take from, or nil to skip it.
local function get_source_inventory(entity, player_settings)
  if entity.type == "container" then
    return entity.get_inventory(defines.inventory.chest)
  end

  if entity.type == "logistic-container" then
    local setting = player_settings["stockify-logistic-" .. tostring(entity.prototype.logistic_mode)]
    if setting and setting.value then
      return entity.get_inventory(defines.inventory.chest)
    end
    return nil
  end

  if entity.type == "cargo-landing-pad" and player_settings["stockify-landing-pads"].value then
    return entity.get_inventory(defines.inventory.cargo_landing_pad_main)
  end

  if player_settings["stockify-vehicles"].value then
    -- "car" covers both the car and the tank.
    if entity.type == "car" then
      return entity.get_inventory(defines.inventory.car_trunk)
    end
    if entity.type == "spider-vehicle" then
      return entity.get_inventory(defines.inventory.spider_trunk)
    end
  end

  if entity.type == "cargo-wagon" and player_settings["stockify-cargo-wagons"].value then
    return entity.get_inventory(defines.inventory.cargo_wagon)
  end

  return nil
end

-- Inventories in range we're allowed to take from, sorted nearest first.
-- skip_entity is the vehicle being restocked, so it never takes from itself.
local function find_sources(character, player, range, player_settings, skip_entity)
  local found = character.surface.find_entities_filtered({
    position = character.position,
    radius = range,
    type = { "container", "logistic-container", "cargo-landing-pad", "car", "spider-vehicle", "cargo-wagon" },
    force = player.force
  })

  local origin = character.position
  local sources = {}

  for _, entity in pairs(found) do
    local inventory = nil
    if entity ~= skip_entity then
      inventory = get_source_inventory(entity, player_settings)
    end
    if inventory then
      local dx = entity.position.x - origin.x
      local dy = entity.position.y - origin.y
      table.insert(sources, { inventory = inventory, distance = dx * dx + dy * dy })
    end
  end

  table.sort(sources, function(a, b)
    return a.distance < b.distance
  end)

  return sources
end

-- Quick check so we don't scan every slot of a big chest for nothing.
-- Only works for exact-quality filters, so other filters always get scanned.
local function might_have(source_inventory, item)
  if item.comparator ~= "=" then
    return true
  end
  return source_inventory.get_item_count({ name = item.name, quality = item.quality }) > 0
end

-- Fill one player slot from one inventory. Returns how many items were moved.
local function fill_slot_from(slot, item, source_inventory)
  local moved = 0
  local has_filters = source_inventory.supports_filters()

  for j = 1, #source_inventory do
    -- Stop once the slot is a full stack.
    if slot.valid_for_read and slot.count >= slot.prototype.stack_size then
      break
    end

    -- Locked slots in a vehicle or wagon are reserved, so never take from them.
    local source_locked = has_filters and source_inventory.get_filter(j) ~= nil

    local source = source_inventory[j]
    if not source_locked and can_take(source, slot, item) then
      local before = slot.valid_for_read and slot.count or 0

      if slot.valid_for_read then
        -- Moves as much as fits and leaves the rest behind.
        -- Using whole stacks (instead of counts) keeps spoilage and other item data.
        slot.transfer_stack(source)
      else
        slot.set_stack(source)
        source.clear()
      end

      moved = moved + (slot.count - before)
    end
  end

  return moved
end

-- Show a short message at the player's cursor.
local function show_message(player, text)
  player.create_local_flying_text({
    text = text,
    create_at_cursor = true
  })
end

-- Work out what the hotkey should refill, based on which window is open.
-- Returns the inventory to fill and the vehicle (or nil for the player),
-- or nil plus a message explaining why nothing can be restocked.
local function get_restock_target(player, character, range)
  local gui = player.opened_gui_type

  -- No window, or the player's own inventory screen: refill the player.
  if gui == defines.gui_type.none or gui == defines.gui_type.controller then
    return player.get_main_inventory(), nil
  end

  -- A car, tank, or spidertron window: refill that vehicle's trunk.
  local entity = player.opened
  if gui == defines.gui_type.entity and entity and entity.valid
    and (entity.type == "car" or entity.type == "spider-vehicle") then

    if entity.force ~= player.force then
      return nil, nil, "Can't restock someone else's vehicle"
    end

    -- Stops refilling a vehicle on the other side of the map through remote view.
    local dx = entity.position.x - character.position.x
    local dy = entity.position.y - character.position.y
    if entity.surface ~= character.surface or dx * dx + dy * dy > range * range then
      return nil, nil, "Too far from this vehicle to restock it"
    end

    if entity.type == "car" then
      return entity.get_inventory(defines.inventory.car_trunk), entity
    end
    return entity.get_inventory(defines.inventory.spider_trunk), entity
  end

  -- Any other window: leave everything alone.
  return nil, nil, "Close this window to restock"
end

local function restock(player)
  -- Need an actual character standing somewhere (not a space platform or god mode).
  local character = player.character
  if not character then
    show_message(player, "Stockify needs your character nearby")
    return
  end

  local player_settings = settings.get_player_settings(player)

  -- The setting is a dropdown string like "10", so convert it to a number.
  local range = tonumber(player_settings["stockify-range"].value)

  local target_inventory, target_vehicle, problem = get_restock_target(player, character, range)
  if problem then
    show_message(player, problem)
    return
  end
  if not target_inventory then
    return
  end
  if not target_inventory.supports_filters() then
    show_message(player, "This inventory can't have locked slots")
    return
  end

  local sources = find_sources(character, player, range, player_settings, target_vehicle)

  local total_moved = 0
  local found_locked_slot = false

  -- Items we couldn't get enough of, in the order we found them.
  local missing_order = {}
  local missing_counts = {}

  for i = 1, #target_inventory do
    local item = get_slot_filter(target_inventory, i)
    local slot = target_inventory[i]

    -- Skip unlocked slots, and locked slots holding something else.
    local slot_is_usable = item
      and (not slot.valid_for_read
        or (slot.name == item.name and quality_allowed(slot.quality.name, item)))

    if slot_is_usable then
      found_locked_slot = true

      for _, source in pairs(sources) do
        if might_have(source.inventory, item) then
          total_moved = total_moved + fill_slot_from(slot, item, source.inventory)
        end
      end

      -- If the slot still isn't full, remember how many we were short.
      local stack_size = prototypes.item[item.name].stack_size
      local current = slot.valid_for_read and slot.count or 0
      local short = stack_size - current

      if short > 0 then
        local key = item.name .. "/" .. item.quality
        if not missing_counts[key] then
          missing_counts[key] = 0
          table.insert(missing_order, item)
        end
        missing_counts[key] = missing_counts[key] + short
      end
    end
  end

  local anything_missing = #missing_order > 0

  -- Let the player know what happened.
  if not found_locked_slot then
    show_message(player, "No locked slots to restock")
  elseif total_moved > 0 and anything_missing then
    show_message(player, "Restocked " .. total_moved .. " items, some missing")
  elseif total_moved > 0 then
    show_message(player, "Restocked " .. total_moved .. " items")
  elseif anything_missing then
    show_message(player, "Couldn't restock, items missing")
  else
    show_message(player, "Already fully stocked")
  end

  -- List what was missing in chat, with item icons.
  if anything_missing then
    local parts = {}
    for _, item in pairs(missing_order) do
      local icon = "[item=" .. item.name .. "]"
      if item.quality ~= "normal" then
        icon = "[item=" .. item.name .. ",quality=" .. item.quality .. "]"
      end
      local key = item.name .. "/" .. item.quality
      table.insert(parts, icon .. " x" .. missing_counts[key])
    end
    player.print("Stockify missing: " .. table.concat(parts, ", "))
  end
end

script.on_event("stockify-restock", function(event)
  local player = game.get_player(event.player_index)
  if player then
    restock(player)
  end
end)
