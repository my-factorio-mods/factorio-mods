-- Lumify prototypes: the lamp selection tool, the shortcut bar button, and the hotkey.

data:extend({
  -- Drag over lamps to add them to the selected group. Alt-drag removes them.
  {
    type = "selection-tool",
    name = "lumify-tool",
    icon = "__base__/graphics/icons/small-lamp.png",
    icon_size = 64,
    flags = { "only-in-cursor", "not-stackable", "spawnable" },
    hidden = true,
    subgroup = "tool",
    order = "z[lumify-tool]",
    stack_size = 1,
    select = {
      border_color = { r = 0.3, g = 0.8, b = 1 },
      cursor_box_type = "entity",
      mode = { "same-force", "any-entity" },
      entity_type_filters = { "lamp" }
    },
    alt_select = {
      border_color = { r = 1, g = 0.4, b = 0.3 },
      cursor_box_type = "not-allowed",
      mode = { "same-force", "any-entity" },
      entity_type_filters = { "lamp" }
    }
  },

  -- Opens the Lumify window.
  {
    type = "custom-input",
    name = "lumify-toggle-window",
    key_sequence = "CONTROL + SHIFT + L",
    consuming = "none"
  },

  {
    type = "shortcut",
    name = "lumify-shortcut",
    action = "lua",
    icon = "__base__/graphics/icons/small-lamp.png",
    icon_size = 64,
    small_icon = "__base__/graphics/icons/small-lamp.png",
    small_icon_size = 64,
    associated_control_input = "lumify-toggle-window",
    order = "z[lumify]"
  }
})
