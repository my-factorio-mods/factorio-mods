-- The soft round glow drawn under each power pole.
-- The texture is 256 pixels wide: brightest at the center, fading gradually
-- all the way out to nothing at the edge, like the game's own lamp glow.
data:extend({
  {
    type = "sprite",
    name = "citify-glow",
    filename = "__Citify__/graphics/glow.png",
    width = 256,
    height = 256,
    flags = { "light" }
  }
})
