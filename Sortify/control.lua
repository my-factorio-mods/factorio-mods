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

-- Builds the value we sort items by: the same group/subgroup/item order the game
-- uses in its menus, then name and quality. The slot number goes last so items
-- that are otherwise equal keep their current order and don't shuffle around.
local function get_sort_key(stack, slot)
  local proto = stack.prototype
  return {
    proto.group.order,
    proto.subgroup.order,
    proto.order,
    stack.name,
    stack.quality.level,
    slot,
  }
end

-- True if key a should come before key b. Compares one part at a time.
local function comes_before(a, b)
  for i = 1, #a do
    if a[i] ~= b[i] then
      return a[i] < b[i]
    end
  end
  return false
end

-- Combines partial stacks of the same item (and quality) in the given slots.
local function merge_stacks(inventory, slots)
  -- Remembers, for each item, a slot that still has room for more.
  local slot_with_room = {}

  for _, i in ipairs(slots) do
    local stack = inventory[i]
    if stack.valid_for_read then
      local id = stack.name .. "/" .. stack.quality.name
      local target_index = slot_with_room[id]

      if target_index then
        local target = inventory[target_index]
        target.transfer_stack(stack)
        if target.count >= target.prototype.stack_size then
          slot_with_room[id] = nil
        end
      end

      -- Whatever is left here can take the next matching stack.
      if stack.valid_for_read and stack.count < stack.prototype.stack_size and not slot_with_room[id] then
        slot_with_room[id] = i
      end
    end
  end
end

-- Sorts an inventory that has slot filters, like vanilla would treat it:
-- filtered slots are never touched, everything else gets merged and sorted.
local function sort_around_filters(inventory)
  -- Find every slot without a filter. These are the only ones we rearrange.
  local free_slots = {}
  for i = 1, #inventory do
    if not inventory.get_filter(i) then
      table.insert(free_slots, i)
    end
  end

  merge_stacks(inventory, free_slots)

  -- List the items in the free slots and put them in sorted order.
  local items = {}
  for _, i in ipairs(free_slots) do
    local stack = inventory[i]
    if stack.valid_for_read then
      table.insert(items, { key = get_sort_key(stack, i), slot = i })
    end
  end
  table.sort(items, function(a, b) return comes_before(a.key, b.key) end)

  -- Move item number n into the nth free slot. We swap stacks instead of
  -- removing and re-adding them, so nothing about the item is lost
  -- (equipment grids, damage, blueprint contents, and so on).
  local slot_of_item = {} -- item number -> slot it's in right now
  local item_in_slot = {} -- slot -> item number sitting in it
  for n, item in ipairs(items) do
    slot_of_item[n] = item.slot
    item_in_slot[item.slot] = n
  end

  for n = 1, #items do
    local target = free_slots[n]
    local current = slot_of_item[n]
    if current ~= target then
      inventory[target].swap_stack(inventory[current])

      -- Whatever was in the target slot (maybe nothing) is now in "current".
      local displaced = item_in_slot[target]
      if displaced then
        slot_of_item[displaced] = current
      end
      item_in_slot[current] = displaced
      item_in_slot[target] = n
      slot_of_item[n] = target
    end
  end
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
  if not inventory then
    return
  end

  if inventory.is_filtered() then
    -- Has slot filters, so sort around them and leave filtered slots alone.
    sort_around_filters(inventory)
  else
    -- No filters, so the game's built-in sort is fastest.
    -- It merges partial stacks and sorts items into the standard order.
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
