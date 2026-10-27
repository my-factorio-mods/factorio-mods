-- Lumify window: pick a group, then set its pattern, speed, and colors.
--
-- Every clickable element has a tag called "action" so the event handlers
-- know what it does. Big changes rebuild the whole window, which keeps the
-- code simple. Typing and sliders update in place so you don't lose focus.

local groups = require("groups")
local patterns = require("patterns")

local gui = {}

-- Which players are typing a new group name. Created on first use, so saves
-- from the earlier test build keep working.
local function renaming()
  storage.renaming = storage.renaming or {}
  return storage.renaming
end

local WINDOW_NAME = "lumify_window"
local SPEED_MIN = 0.25
local SPEED_MAX = 4

-- Helpers --------------------------------------------------------------------

local function get_selected_group(player)
  local id = storage.selected[player.index]
  local group = id and storage.groups[id]
  if group then
    return group
  end

  -- Nothing picked yet (or it was deleted): pick the first group, if any.
  local list = groups.sorted_list()
  if list[1] then
    storage.selected[player.index] = list[1].id
    return list[1]
  end
  return nil
end
gui.get_selected_group = get_selected_group

local function index_of(list, value)
  for index, item in pairs(list) do
    if item == value then
      return index
    end
  end
  return 1
end

local function to_byte(value)
  return math.floor(value * 255 + 0.5)
end

local function add_row(parent, caption)
  local row = parent.add({ type = "flow", direction = "horizontal" })
  row.style.vertical_align = "center"
  if caption then
    local label = row.add({ type = "label", caption = caption })
    label.style.minimal_width = 110
  end
  return row
end

local function speed_text(speed)
  return string.format("%.2fx", speed)
end

-- Add a small button using one of the game's own icons, like vanilla's
-- rename pencil. If the icon or style can't be found, use a plain text
-- button instead so the window never breaks.
local function sprite_exists(sprite)
  if helpers and helpers.is_valid_sprite_path then
    return helpers.is_valid_sprite_path(sprite)
  end
  return false
end

local function add_icon_button(parent, sprite, style, fallback_text, tooltip, action)
  if sprite_exists(sprite) then
    local ok, button = pcall(function()
      return parent.add({
        type = "sprite-button",
        sprite = sprite,
        style = style,
        tooltip = tooltip,
        tags = { action = action }
      })
    end)
    if ok then
      return button
    end
  end

  return parent.add({
    type = "button",
    caption = fallback_text,
    tooltip = tooltip,
    tags = { action = action }
  })
end

-- Building the window ----------------------------------------------------------

local function add_color_rows(parent, group)
  parent.add({
    type = "label",
    caption = { "lumify.color-count" }
  })

  local count_row = add_row(parent, nil)
  count_row.add({
    type = "drop-down",
    items = { "1", "2", "3" },
    selected_index = group.color_count,
    tags = { action = "set_color_count" }
  })

  for i = 1, group.color_count do
    local color = group.colors[i]
    local row = add_row(parent, nil)

    local swatch = row.add({ type = "label", name = "lumify_swatch_" .. i, caption = "██████" })
    swatch.style.font_color = color
    swatch.style.minimal_width = 60

    for _, channel in pairs({ "r", "g", "b" }) do
      local field = row.add({
        type = "textfield",
        text = tostring(to_byte(color[channel])),
        numeric = true,
        allow_decimal = false,
        allow_negative = false,
        tooltip = string.upper(channel) .. " (0 to 255)",
        tags = { action = "set_color", index = i, channel = channel }
      })
      field.style.width = 50
    end
  end
end

local function fill_window(player, frame)
  local list = groups.sorted_list()
  local group = get_selected_group(player)

  -- Group picker and new/delete buttons.
  local group_row = add_row(frame, { "lumify.group" })
  if group then
    local names = {}
    for _, item in pairs(list) do
      table.insert(names, item.name)
    end
    local dropdown = group_row.add({
      type = "drop-down",
      name = "lumify_group_dropdown",
      items = names,
      selected_index = index_of(list, group),
      tags = { action = "select_group" }
    })
    dropdown.style.minimal_width = 160
  end
  group_row.add({
    type = "button",
    caption = { "lumify.new-group" },
    tooltip = { "lumify.new-group-tooltip" },
    tags = { action = "new_group" }
  })
  if group then
    group_row.add({
      type = "button",
      caption = { "lumify.delete-group" },
      tooltip = { "lumify.delete-group-tooltip" },
      style = "red_button",
      tags = { action = "delete_group" }
    })
  end

  if not group then
    frame.add({ type = "label", caption = { "lumify.no-groups" } })
    frame.add({ type = "button", caption = { "lumify.close" }, tags = { action = "close" } })
    return
  end

  -- Name, shown like vanilla: the name with a pencil button, which turns into
  -- a text box with a checkmark while renaming.
  local name_row = add_row(frame, { "lumify.name" })
  if renaming()[player.index] then
    local name_field = name_row.add({
      type = "textfield",
      text = group.name,
      tags = { action = "rename" }
    })
    name_field.style.width = 200
    name_field.focus()
    name_field.select_all()
    add_icon_button(name_row, "utility/check_mark", "item_and_count_select_confirm", "✔",
      { "lumify.confirm-rename" }, "confirm_rename")
  else
    local name_label = name_row.add({ type = "label", caption = group.name })
    name_label.style.font = "default-bold"
    add_icon_button(name_row, "utility/rename_icon", "mini_button_aligned_to_text_vertically_when_centered", "✎",
      { "lumify.rename" }, "start_rename")
  end

  local lamp_row = add_row(frame, nil)
  lamp_row.add({
    type = "button",
    caption = { "lumify.select-lamps" },
    tooltip = { "lumify.select-lamps-tooltip" },
    tags = { action = "give_tool" }
  })
  lamp_row.add({ type = "label", caption = { "lumify.lamp-count", groups.count_lamps(group) } })

  frame.add({
    type = "checkbox",
    caption = { "lumify.enabled" },
    state = group.enabled,
    tags = { action = "toggle_enabled" }
  })

  frame.add({ type = "line" })

  -- Pattern and speed.
  local pattern_items = {}
  for _, name in pairs(patterns.names) do
    table.insert(pattern_items, { "lumify-pattern." .. name })
  end
  local pattern_row = add_row(frame, { "lumify.pattern" })
  pattern_row.add({
    type = "drop-down",
    items = pattern_items,
    selected_index = index_of(patterns.names, group.pattern),
    tags = { action = "set_pattern" }
  })

  if group.pattern == "strobe" then
    local warning = frame.add({ type = "label", caption = { "lumify.strobe-warning" } })
    warning.style.font_color = { r = 1, g = 0.6, b = 0.2 }
    warning.style.single_line = false
    warning.style.maximal_width = 330
  end

  local speed_row = add_row(frame, { "lumify.speed" })
  speed_row.add({
    type = "slider",
    minimum_value = SPEED_MIN,
    maximum_value = SPEED_MAX,
    value = group.speed,
    value_step = 0.25,
    tags = { action = "set_speed" }
  })
  speed_row.add({ type = "label", name = "lumify_speed_label", caption = speed_text(group.speed) })

  if group.pattern == "wave" then
    local direction_items = {}
    for _, name in pairs(patterns.directions) do
      table.insert(direction_items, { "lumify-direction." .. name })
    end
    local direction_row = add_row(frame, { "lumify.direction" })
    direction_row.add({
      type = "drop-down",
      items = direction_items,
      selected_index = index_of(patterns.directions, group.direction),
      tags = { action = "set_direction" }
    })
  end

  frame.add({ type = "line" })

  -- Colors.
  if patterns.themed[group.pattern] then
    frame.add({ type = "label", caption = { "lumify.themed-note" } })
  else
    local color_row = add_row(frame, { "lumify.colors" })
    color_row.add({
      type = "drop-down",
      items = { { "lumify.color-rainbow" }, { "lumify.color-custom" } },
      selected_index = group.color_mode == "custom" and 2 or 1,
      tags = { action = "set_color_mode" }
    })

    if group.color_mode == "custom" then
      add_color_rows(frame, group)
    end
  end

  frame.add({ type = "line" })
  frame.add({ type = "button", caption = { "lumify.close" }, tags = { action = "close" } })
end

function gui.open(player)
  local old = player.gui.screen[WINDOW_NAME]
  local location = nil
  if old then
    location = old.location
    old.destroy()
  end

  local frame = player.gui.screen.add({
    type = "frame",
    name = WINDOW_NAME,
    direction = "vertical",
    caption = { "lumify.window-title" }
  })

  if location then
    frame.location = location
  else
    frame.auto_center = true
  end

  fill_window(player, frame)
  player.opened = frame
end

function gui.close(player)
  renaming()[player.index] = nil
  local frame = player.gui.screen[WINDOW_NAME]
  if frame then
    frame.destroy()
  end
end

function gui.toggle(player)
  if player.gui.screen[WINDOW_NAME] then
    gui.close(player)
  else
    gui.open(player)
  end
end

-- Rebuild the window for everyone who has it open, so changes show up for all.
function gui.refresh_all()
  for _, player in pairs(game.connected_players) do
    if player.gui.screen[WINDOW_NAME] then
      gui.open(player)
    end
  end
end

local function is_our_element(element)
  return element and element.valid and element.tags and element.tags.action ~= nil
end

-- Remove spaces from the start and end of a name.
local function trim(text)
  local trimmed = text:gsub("^%s+", ""):gsub("%s+$", "")
  return trimmed
end

-- Save the name from the text box and switch back to showing it as text.
-- An empty name is ignored, so a group always keeps a name.
local function finish_rename(player)
  local frame = player.gui.screen[WINDOW_NAME]
  local group = get_selected_group(player)
  if frame and group then
    local field = nil
    for _, row in pairs(frame.children) do
      for _, child in pairs(row.children) do
        if child.valid and child.tags and child.tags.action == "rename" then
          field = child
        end
      end
    end

    if field then
      local name = trim(field.text)
      if name ~= "" then
        group.name = name
      end
    end
  end

  renaming()[player.index] = nil
  gui.refresh_all()
end

-- Event handlers -------------------------------------------------------------

function gui.on_click(event)
  local element = event.element
  if not is_our_element(element) then
    return
  end

  local player = game.get_player(event.player_index)
  local action = element.tags.action

  if action == "close" then
    gui.close(player)

  elseif action == "start_rename" then
    renaming()[player.index] = true
    gui.open(player)

  elseif action == "confirm_rename" then
    finish_rename(player)

  elseif action == "new_group" then
    local group = groups.create()
    storage.selected[player.index] = group.id
    renaming()[player.index] = nil
    gui.refresh_all()

  elseif action == "delete_group" then
    local group = get_selected_group(player)
    if group then
      groups.delete(group)
      gui.refresh_all()
    end

  elseif action == "give_tool" then
    local group = get_selected_group(player)
    if group and player.clear_cursor() then
      player.cursor_stack.set_stack({ name = "lumify-tool", count = 1 })
      gui.close(player)
      player.create_local_flying_text({
        text = { "lumify.tool-hint", group.name },
        create_at_cursor = true
      })
    end
  end
end

function gui.on_checked(event)
  local element = event.element
  if not is_our_element(element) or element.tags.action ~= "toggle_enabled" then
    return
  end

  local player = game.get_player(event.player_index)
  local group = get_selected_group(player)
  if group then
    groups.set_enabled(group, element.state)
    gui.refresh_all()
  end
end

function gui.on_dropdown(event)
  local element = event.element
  if not is_our_element(element) then
    return
  end

  local player = game.get_player(event.player_index)
  local action = element.tags.action
  local index = element.selected_index

  if action == "select_group" then
    local list = groups.sorted_list()
    if list[index] then
      storage.selected[player.index] = list[index].id
    end
    renaming()[player.index] = nil
    gui.open(player)
    return
  end

  local group = get_selected_group(player)
  if not group then
    return
  end

  if action == "set_pattern" then
    group.pattern = patterns.names[index]
    group.life = nil
    group.life_steps = 0
  elseif action == "set_direction" then
    group.direction = patterns.directions[index]
  elseif action == "set_color_mode" then
    if index == 2 then
      group.color_mode = "custom"
    else
      group.color_mode = "rainbow"
    end
  elseif action == "set_color_count" then
    group.color_count = index
  else
    return
  end

  gui.refresh_all()
end

function gui.on_slider(event)
  local element = event.element
  if not is_our_element(element) or element.tags.action ~= "set_speed" then
    return
  end

  local player = game.get_player(event.player_index)
  local group = get_selected_group(player)
  if not group then
    return
  end

  group.speed = element.slider_value
  local label = element.parent["lumify_speed_label"]
  if label then
    label.caption = speed_text(group.speed)
  end
end

function gui.on_text_changed(event)
  local element = event.element
  if not is_our_element(element) or element.tags.action ~= "set_color" then
    return
  end

  local player = game.get_player(event.player_index)
  local group = get_selected_group(player)
  if not group then
    return
  end

  -- Empty or bad input counts as 0, and anything over 255 is capped.
  local value = tonumber(element.text) or 0
  value = math.max(0, math.min(255, value))

  local color = group.colors[element.tags.index]
  color[element.tags.channel] = value / 255

  -- Update the color swatch next to the boxes.
  local swatch = element.parent["lumify_swatch_" .. element.tags.index]
  if swatch then
    swatch.style.font_color = color
  end
end

function gui.on_confirmed(event)
  local element = event.element
  if not is_our_element(element) or element.tags.action ~= "rename" then
    return
  end

  -- Pressing Enter in the name box saves it, like the checkmark.
  finish_rename(game.get_player(event.player_index))
end

function gui.on_closed(event)
  local element = event.element
  if element and element.valid and element.name == WINDOW_NAME then
    renaming()[event.player_index] = nil
    element.destroy()
  end
end

return gui
