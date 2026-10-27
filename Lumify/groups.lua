-- Lumify groups: creating and deleting groups, and adding or removing lamps.
--
-- Everything lives in `storage` so it's saved with the game:
--   storage.groups[group_id]     = the group (name, pattern, colors, lamps...)
--   storage.lamp_group[unit]     = which group a lamp belongs to
--   storage.selected[player]     = which group a player has picked in the window
--   storage.queue                = list of lamps, worked through a few per tick

local groups = {}

local WHITE = { r = 1, g = 1, b = 1 }

function groups.init_storage()
  storage.groups = storage.groups or {}
  storage.lamp_group = storage.lamp_group or {}
  storage.selected = storage.selected or {}
  storage.renaming = storage.renaming or {}
  storage.next_group_id = storage.next_group_id or 1
  storage.queue = storage.queue or {}
  storage.queue_position = storage.queue_position or 1
  storage.queue_dirty = true
end

-- Groups sorted by when they were made, for the window's dropdown.
function groups.sorted_list()
  local list = {}
  for _, group in pairs(storage.groups) do
    table.insert(list, group)
  end
  table.sort(list, function(a, b)
    return a.id < b.id
  end)
  return list
end

function groups.create()
  local id = storage.next_group_id
  storage.next_group_id = id + 1

  local group = {
    id = id,
    name = "Group " .. id,
    pattern = "rainbow",
    speed = 1,
    direction = "left-right",
    color_mode = "rainbow",
    color_count = 2,
    colors = {
      { r = 1, g = 0, b = 0 },
      { r = 0, g = 0.4, b = 1 },
      { r = 1, g = 1, b = 1 }
    },
    enabled = true,
    lamps = {},
    dirty = true
  }

  storage.groups[id] = group
  return group
end

-- Some lamp settings might not exist on every lamp type, so try them safely.
local function set_always_on(entity, value)
  pcall(function()
    entity.always_on = value
  end)
end

local function get_always_on(entity)
  local ok, value = pcall(function()
    return entity.always_on
  end)
  if ok then
    return value
  end
  return false
end

-- Put a lamp back the way it was before it joined a show.
local function restore_lamp(record)
  local entity = record.entity
  if entity and entity.valid then
    entity.color = record.original_color or WHITE
    set_always_on(entity, record.original_always_on or false)
  end
  record.last_key = nil
end

-- Find a lamp's record in its group, or nil if it isn't in a show.
local function find_record(entity)
  if not (entity and entity.valid and entity.unit_number) then
    return nil
  end
  local group_id = storage.lamp_group[entity.unit_number]
  local group = group_id and storage.groups[group_id]
  return group and group.lamps[entity.unit_number]
end

-- Put a lamp back to normal right before it's removed, so the undo history
-- and the item remember its original color, not a frozen show color.
-- It stays in its group, paused, in case the removal is cancelled.
function groups.pause_lamp(entity)
  local record = find_record(entity)
  if record and not record.paused then
    restore_lamp(record)
    record.paused = true
  end
end

-- The removal was cancelled, so the lamp rejoins the show.
function groups.resume_lamp(entity)
  local record = find_record(entity)
  if record and record.paused then
    record.paused = nil
    record.last_key = nil
    local group = storage.groups[storage.lamp_group[entity.unit_number]]
    if group and group.enabled then
      set_always_on(entity, true)
    end
  end
end

-- Take a lamp out of its group. If restore is true, it goes back to normal.
function groups.remove_lamp(unit, restore)
  local group_id = storage.lamp_group[unit]
  if not group_id then
    return
  end

  local group = storage.groups[group_id]
  if group then
    local record = group.lamps[unit]
    if record and restore then
      restore_lamp(record)
    end
    group.lamps[unit] = nil
    group.dirty = true
  end

  storage.lamp_group[unit] = nil
  storage.queue_dirty = true
end

-- Does this lamp get its color from circuit signals? Then Lumify leaves it alone.
local function uses_circuit_colors(entity)
  local behavior = entity.get_control_behavior()
  return behavior ~= nil and behavior.use_colors == true
end

-- Add lamps to a group. Returns how many were added and how many skipped.
function groups.add_lamps(group, entities)
  local added = 0
  local skipped = 0

  for _, entity in pairs(entities) do
    if entity.valid and entity.type == "lamp" then
      if uses_circuit_colors(entity) then
        skipped = skipped + 1
      else
        local unit = entity.unit_number
        local old_group_id = storage.lamp_group[unit]

        if old_group_id ~= group.id then
          local original_color = entity.color
          local original_always_on = get_always_on(entity)

          -- Moving from another group: keep the lamp's true original settings.
          if old_group_id and storage.groups[old_group_id] then
            local old_record = storage.groups[old_group_id].lamps[unit]
            if old_record then
              original_color = old_record.original_color
              original_always_on = old_record.original_always_on
            end
          end
          groups.remove_lamp(unit, false)

          group.lamps[unit] = {
            entity = entity,
            unit = unit,
            original_color = original_color,
            original_always_on = original_always_on
          }
          storage.lamp_group[unit] = group.id

          -- A lamp already marked for removal joins paused.
          if entity.to_be_deconstructed() then
            group.lamps[unit].paused = true
          else
            set_always_on(entity, true)
          end

          group.dirty = true
          storage.queue_dirty = true
          added = added + 1
        end
      end
    end
  end

  return added, skipped
end

-- Remove lamps from whatever group they're in and put them back to normal.
function groups.remove_lamps(entities)
  local removed = 0
  for _, entity in pairs(entities) do
    if entity.valid and storage.lamp_group[entity.unit_number] then
      groups.remove_lamp(entity.unit_number, true)
      removed = removed + 1
    end
  end
  return removed
end

function groups.delete(group)
  for unit, record in pairs(group.lamps) do
    restore_lamp(record)
    storage.lamp_group[unit] = nil
  end
  storage.groups[group.id] = nil
  storage.queue_dirty = true

  -- Anyone who had this group picked moves to another one.
  for player_index, selected_id in pairs(storage.selected) do
    if selected_id == group.id then
      storage.selected[player_index] = nil
    end
  end
end

-- Turn a group's show on or off. Off puts its lamps back to normal colors,
-- but they stay in the group.
function groups.set_enabled(group, enabled)
  group.enabled = enabled
  for _, record in pairs(group.lamps) do
    if enabled then
      -- Paused lamps are waiting to be removed, so leave them alone.
      if record.entity.valid and not record.paused then
        set_always_on(record.entity, true)
      end
      record.last_key = nil
    else
      restore_lamp(record)
    end
  end
end

function groups.count_lamps(group)
  local count = 0
  for _ in pairs(group.lamps) do
    count = count + 1
  end
  return count
end

-- Give each value in a list its position when sorted, so lamps every 2 tiles
-- become columns 0, 1, 2... instead of 0, 2, 4...
local function rank_values(values)
  local unique = {}
  local seen = {}
  for _, value in pairs(values) do
    if not seen[value] then
      seen[value] = true
      table.insert(unique, value)
    end
  end
  table.sort(unique)

  local ranks = {}
  for index, value in pairs(unique) do
    ranks[value] = index - 1
  end
  return ranks, #unique
end

-- Work out the layout info patterns need: the center, each lamp's grid
-- column and row, and an order for Chase. Runs again whenever lamps change.
function groups.update_layout(group)
  -- Drop lamps that were mined or destroyed.
  for unit, record in pairs(group.lamps) do
    if not record.entity.valid then
      group.lamps[unit] = nil
      storage.lamp_group[unit] = nil
      storage.queue_dirty = true
    end
  end

  local list = {}
  local xs = {}
  local ys = {}
  local min_x, max_x, min_y, max_y = math.huge, -math.huge, math.huge, -math.huge

  for unit, record in pairs(group.lamps) do
    local position = record.entity.position
    record.x = position.x
    record.y = position.y
    record.seed = (unit % 10007) / 10007
    table.insert(list, record)
    table.insert(xs, position.x)
    table.insert(ys, position.y)
    min_x = math.min(min_x, position.x)
    max_x = math.max(max_x, position.x)
    min_y = math.min(min_y, position.y)
    max_y = math.max(max_y, position.y)
  end

  local column_of, column_count = rank_values(xs)
  local row_of, row_count = rank_values(ys)

  group.cells = {}
  for _, record in pairs(list) do
    record.ix = column_of[record.x]
    record.iy = row_of[record.y]
    record.key = record.ix .. ":" .. record.iy
    group.cells[record.key] = record
  end

  -- Chase order: row by row, snaking back and forth like reading a zigzag.
  table.sort(list, function(a, b)
    if a.iy ~= b.iy then
      return a.iy < b.iy
    end
    if a.iy % 2 == 0 then
      return a.ix < b.ix
    end
    return a.ix > b.ix
  end)
  for index, record in pairs(list) do
    record.order = index - 1
  end

  group.list = list
  group.count = #list
  group.column_count = column_count
  group.row_count = row_count
  if #list > 0 then
    group.center_x = (min_x + max_x) / 2
    group.center_y = (min_y + max_y) / 2
  else
    group.center_x = 0
    group.center_y = 0
  end

  -- The Game of Life grid changed, so it starts over.
  group.life = nil
  group.life_steps = 0
  group.dirty = false
end

-- Rebuild the list of lamps the update loop works through.
function groups.rebuild_queue()
  local queue = {}
  for unit in pairs(storage.lamp_group) do
    table.insert(queue, unit)
  end
  table.sort(queue)
  storage.queue = queue
  if storage.queue_position > #queue then
    storage.queue_position = 1
  end
  storage.queue_dirty = false
end

return groups
