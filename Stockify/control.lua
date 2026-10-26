-- Stockify: fill the player's locked (filtered) inventory slots with items
-- pulled from nearby chests, nearest chests first.

-- Logistic chests holding items for a reason. Never take from these.
local SKIPPED_LOGISTIC_MODES = {
  requester = true,
  buffer = true
}

-- Read a slot's filter as a plain item name and quality name.
-- Returns nil if the slot has no filter.
local function get_slot_filter(inventory, index)
  local filter = inventory.get_filter(index)
  if not filter then
    return nil
  end

  -- Older style filters are just the item name.
  if type(filter) == "string" then
    return { name = filter, quality = "normal" }
  end

  local quality = filter.quality
  if type(quality) ~= "string" then
    quality = quality and quality.name or "normal"
  end

  return { name = filter.name, quality = quality }
end

local function stack_matches(stack, item)
  return stack.valid_for_read
    and stack.name == item.name
    and stack.quality.name == item.quality
end

-- Chests in range that we're allowed to take from, sorted nearest first.
local function find_source_chests(character, player, range)
  local found = character.surface.find_entities_filtered({
    position = character.position,
    radius = range,
    type = { "container", "logistic-container" },
    force = player.force
  })

  local chests = {}
  for _, chest in pairs(found) do
    local mode = chest.prototype.logistic_mode
    if not (mode and SKIPPED_LOGISTIC_MODES[mode]) then
      table.insert(chests, chest)
    end
  end

  local origin = character.position
  local function distance(chest)
    local dx = chest.position.x - origin.x
    local dy = chest.position.y - origin.y
    return dx * dx + dy * dy
  end

  table.sort(chests, function(a, b)
    return distance(a) < distance(b)
  end)

  return chests
end

-- Fill one player slot from one chest. Returns how many items were moved.
local function fill_slot_from_chest(slot, item, chest_inventory)
  local moved = 0

  for j = 1, #chest_inventory do
    -- Stop once the slot is a full stack.
    if slot.valid_for_read and slot.count >= slot.prototype.stack_size then
      break
    end

    local source = chest_inventory[j]
    if stack_matches(source, item) then
      local before = slot.valid_for_read and slot.count or 0

      if slot.valid_for_read then
        -- Moves as much as fits and leaves the rest in the chest.
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

local function restock(player)
  -- Need an actual character standing somewhere (not remote view or god mode).
  local character = player.character
  if not character then
    return
  end

  local player_inventory = player.get_main_inventory()
  if not player_inventory then
    return
  end

  -- The setting is a dropdown string like "10", so convert it to a number.
  local range = tonumber(settings.get_player_settings(player)["stockify-range"].value)
  local chests = find_source_chests(character, player, range)

  local total_moved = 0
  local found_locked_slot = false

  -- Items we couldn't get enough of, in the order we found them.
  local missing_order = {}
  local missing_counts = {}

  for i = 1, #player_inventory do
    local item = get_slot_filter(player_inventory, i)
    local slot = player_inventory[i]

    -- Skip unlocked slots, and locked slots holding something else.
    local slot_is_usable = item and (not slot.valid_for_read or stack_matches(slot, item))

    if slot_is_usable then
      found_locked_slot = true

      for _, chest in pairs(chests) do
        local chest_inventory = chest.get_inventory(defines.inventory.chest)
        if chest_inventory then
          total_moved = total_moved + fill_slot_from_chest(slot, item, chest_inventory)
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
  local message
  if not found_locked_slot then
    message = "No locked slots to restock"
  elseif total_moved > 0 and anything_missing then
    message = "Restocked " .. total_moved .. " items, some missing"
  elseif total_moved > 0 then
    message = "Restocked " .. total_moved .. " items"
  elseif anything_missing then
    message = "Couldn't restock, items missing"
  else
    message = "Already fully stocked"
  end

  player.create_local_flying_text({
    text = message,
    create_at_cursor = true
  })

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
