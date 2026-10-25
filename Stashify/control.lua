-- Stashify: move items from the player's inventory into nearby chests
-- that already contain the same item (same name and same quality).

-- Try to put one inventory slot's items into one chest.
-- Returns how many items were moved.
local function stack_into_chest(stack, chest_inventory)
  local item = { name = stack.name, quality = stack.quality.name }

  -- Only stack into chests that already hold this exact item.
  if chest_inventory.get_item_count(item) == 0 then
    return 0
  end

  -- Inserting the stack itself keeps any extra item data intact.
  local moved = chest_inventory.insert(stack)
  if moved > 0 then
    stack.count = stack.count - moved
  end
  return moved
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

  -- The setting is a dropdown string like "10", so convert it to a number.
  local range = tonumber(settings.get_player_settings(player)["stashify-range"].value)

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

    if chest_inventory then
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
