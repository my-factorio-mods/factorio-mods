-- Stashify: move items from the player's inventory into nearby chests
-- that already contain the same item (same name and same quality).

-- How many slots at the start of the chest are unlocked. Slots past the red X
-- (the chest's slot limit) are locked, and we never put items there.
local function get_unlocked_slot_count(chest_inventory)
  if chest_inventory.supports_bar() then
    -- get_bar() is the first locked slot, so everything before it is open.
    return chest_inventory.get_bar() - 1
  end
  return #chest_inventory
end

-- True if this chest slot holds the same item and quality as the stack.
local function same_item(slot, stack)
  return slot.valid_for_read
    and slot.name == stack.name
    and slot.quality.name == stack.quality.name
end

-- Try to put one inventory slot's items into one chest.
-- Returns how many items were moved.
local function stack_into_chest(stack, chest_inventory)
  local item = { name = stack.name, quality = stack.quality.name }

  -- Only stack into chests that already hold this exact item.
  if chest_inventory.get_item_count(item) == 0 then
    return 0
  end

  local unlocked = get_unlocked_slot_count(chest_inventory)
  local count_before = stack.count

  -- First top up stacks of the same item, then use empty slots.
  -- Moving stack to slot keeps any extra item data (spoilage, damage, etc.)
  for i = 1, unlocked do
    if not stack.valid_for_read then
      break
    end
    local slot = chest_inventory[i]
    if same_item(slot, stack) then
      slot.transfer_stack(stack)
    end
  end

  for i = 1, unlocked do
    if not stack.valid_for_read then
      break
    end
    local slot = chest_inventory[i]
    if not slot.valid_for_read then
      slot.transfer_stack(stack)
    end
  end

  -- An emptied slot can't be read, so it counts as 0 left.
  local count_after = 0
  if stack.valid_for_read then
    count_after = stack.count
  end
  return count_before - count_after
end

-- Should Stashify put items in this chest, based on the player's settings?
local function chest_allowed(chest, player_settings)
  -- Skip chests that are about to be picked up by bots, or the items
  -- would just get hauled away to storage.
  if chest.to_be_deconstructed() then
    return false
  end

  -- Regular chests always count.
  if chest.type == "container" then
    return true
  end

  -- Logistic chests count only if the player turned that kind on.
  local setting = player_settings["stashify-logistic-" .. tostring(chest.prototype.logistic_mode)]
  return setting ~= nil and setting.value == true
end

local function quick_stack(player)
  -- Need an actual character standing somewhere (not remote view or god mode).
  local character = player.character
  if not character then
    return
  end

  local player_inventory = player.get_main_inventory()
  if not player_inventory then
    return
  end

  local player_settings = settings.get_player_settings(player)

  -- The setting is a dropdown string like "10", so convert it to a number.
  local range = tonumber(player_settings["stashify-range"].value)

  -- Look for chests in a circle around the player.
  local chests = character.surface.find_entities_filtered({
    position = character.position,
    radius = range,
    type = { "container", "logistic-container" },
    force = player.force
  })

  local total_moved = 0

  for _, chest in pairs(chests) do
    local chest_inventory = chest.get_inventory(defines.inventory.chest)

    if chest_inventory and chest_allowed(chest, player_settings) then
      for i = 1, #player_inventory do
        local stack = player_inventory[i]
        -- Skip slots the player locked with a filter (middle-click).
        local is_locked = player_inventory.get_filter(i) ~= nil
        if stack.valid_for_read and not is_locked then
          total_moved = total_moved + stack_into_chest(stack, chest_inventory)
        end
      end
    end
  end

  -- Let the player know something happened.
  if total_moved > 0 then
    player.create_local_flying_text({
      text = "Quick stacked " .. total_moved .. " items",
      create_at_cursor = true
    })
  else
    player.create_local_flying_text({
      text = "Nothing to quick stack",
      create_at_cursor = true
    })
  end
end

script.on_event("stashify-quick-stack", function(event)
  local player = game.get_player(event.player_index)
  if player then
    quick_stack(player)
  end
end)
