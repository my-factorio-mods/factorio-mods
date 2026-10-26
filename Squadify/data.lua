-- The hotkey that turns auto-deploy on and off. Players can rebind it in Controls.
data:extend({
  {
    type = "custom-input",
    name = "squadify-toggle",
    key_sequence = "CONTROL + SHIFT + G",
    consuming = "none"
  }
})
