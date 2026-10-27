-- Lumify: animated RGB light shows for groups of lamps.
--
-- The pieces:
--   patterns.lua  works out what color each lamp should be
--   groups.lua    keeps track of groups and which lamps are in them
--   gui.lua       the Lumify window
--   control.lua   (this file) connects game events to all of the above

local groups = require("groups")
local gui = require("gui")
local patterns = require("patterns")

-- Turn a color into one number, so we can skip lamps that haven't changed.
local function color_key(color)
  local r = math.floor(color.r * 255 + 0.5)
  local g = math.floor(color.g * 255 + 0.5)
  local b = math.floor(color.b * 255 + 0.5)
  return r * 65536 + g * 256 + b
end

-- Setup ------------------------------------------------------------------------

script.on_init(function()
  groups.init_storage()
end)

script.on_configuration_changed(function()
  groups.init_storage()
end)

-- The main loop ----------------------------------------------------------------

-- Recolor one lamp.
local function update_lamp(unit, tick)
  local group_id = storage.lamp_group[unit]
  local group = group_id and storage.groups[group_id]
  if not group then
    storage.lamp_group[unit] = nil
    storage.queue_dirty = true
    return
  end

  local record = group.lamps[unit]
  if not record or not record.entity.valid then
    groups.remove_lamp(unit, false)
    return
  end

  -- Paused lamps are about to be removed, so they keep their normal color.
  if not group.enabled or group.dirty or record.paused then
    return
  end

  local t = tick / 60 * group.speed
  local color = patterns.get_color(group, record, t)

  -- Only talk to the game when the color actually changed.
  local key = color_key(color)
  if key ~= record.last_key then
    record.last_key = key
    record.entity.color = { r = color.r, g = color.g, b = color.b, a = 1 }
  end
end

script.on_event(defines.events.on_tick, function(event)
  if storage.queue_dirty then
    groups.rebuild_queue()
  end

  -- Refresh layouts that changed, and move Game of Life shows forward.
  for _, group in pairs(storage.groups) do
    if group.dirty then
      groups.update_layout(group)
    end

    if group.enabled and group.pattern == "life" and group.count > 0 then
      -- Two generations per second at normal speed.
      local generation = math.floor(event.tick / 60 * group.speed * 2)
      if generation ~= group.life_generation then
        group.life_generation = generation
        patterns.step_life(group, generation)
      end
    end
  end

  -- Recolor a limited number of lamps this tick, picking up where we left off.
  local queue = storage.queue
  local total = #queue
  if total == 0 then
    return
  end

  local budget = math.min(settings.global["lumify-updates-per-tick"].value, total)
  local position = storage.queue_position
  for _ = 1, budget do
    if position > total then
      position = 1
    end
    update_lamp(queue[position], event.tick)
    position = position + 1
  end
  storage.queue_position = position
end)

-- The selection tool -------------------------------------------------------------

script.on_event(defines.events.on_player_selected_area, function(event)
  if event.item ~= "lumify-tool" then
    return
  end

  local player = game.get_player(event.player_index)
  local group = gui.get_selected_group(player)
  if not group then
    player.print({ "lumify.pick-group-first" })
    return
  end

  local added, skipped = groups.add_lamps(group, event.entities)
  player.create_local_flying_text({
    text = { "lumify.added", added, group.name },
    create_at_cursor = true
  })
  if skipped > 0 then
    player.print({ "lumify.skipped-circuit", skipped })
  end
end)

script.on_event(defines.events.on_player_alt_selected_area, function(event)
  if event.item ~= "lumify-tool" then
    return
  end

  local player = game.get_player(event.player_index)
  local removed = groups.remove_lamps(event.entities)
  player.create_local_flying_text({
    text = { "lumify.removed", removed },
    create_at_cursor = true
  })
end)

-- Lamps being removed ------------------------------------------------------------
-- Put show lamps back to normal just before they're removed, so Ctrl+Z (and
-- the picked-up item) don't bring them back stuck on a show color.

local LAMP_FILTER = { { filter = "type", type = "lamp" } }

local function pause_removed_lamp(event)
  groups.pause_lamp(event.entity)
end

script.on_event(defines.events.on_pre_player_mined_item, pause_removed_lamp, LAMP_FILTER)
script.on_event(defines.events.on_robot_pre_mined, pause_removed_lamp, LAMP_FILTER)
script.on_event(defines.events.on_marked_for_deconstruction, pause_removed_lamp, LAMP_FILTER)

script.on_event(defines.events.on_cancelled_deconstruction, function(event)
  groups.resume_lamp(event.entity)
end, LAMP_FILTER)

-- The window ---------------------------------------------------------------------

script.on_event("lumify-toggle-window", function(event)
  gui.toggle(game.get_player(event.player_index))
end)

script.on_event(defines.events.on_lua_shortcut, function(event)
  if event.prototype_name == "lumify-shortcut" then
    gui.toggle(game.get_player(event.player_index))
  end
end)

script.on_event(defines.events.on_gui_click, gui.on_click)
script.on_event(defines.events.on_gui_checked_state_changed, gui.on_checked)
script.on_event(defines.events.on_gui_selection_state_changed, gui.on_dropdown)
script.on_event(defines.events.on_gui_value_changed, gui.on_slider)
script.on_event(defines.events.on_gui_text_changed, gui.on_text_changed)
script.on_event(defines.events.on_gui_confirmed, gui.on_confirmed)
script.on_event(defines.events.on_gui_closed, gui.on_closed)

script.on_event(defines.events.on_player_removed, function(event)
  storage.selected[event.player_index] = nil
end)
