-- Lumify patterns: work out what color one lamp should be right now.
--
-- Every pattern gets:
--   group: the lamp's group (pattern, colors, plus layout info like the center)
--   lamp:  the lamp's record (map position x/y, grid column ix / row iy, etc.)
--   t:     time in seconds, already multiplied by the group's speed
-- and returns a color like { r = 1, g = 0.5, b = 0 } with values from 0 to 1.

local patterns = {}

-- The order patterns appear in the window's dropdown.
patterns.names = {
  "rainbow", "wave", "twinkle", "breathe", "rainfall", "ripple",
  "spiral", "checkerboard", "fireworks", "life", "fire", "aurora",
  "ocean", "code-rain", "chase", "heartbeat", "sparkle", "strobe"
}

-- Patterns that always use their own colors, ignoring Rainbow/Custom.
patterns.themed = {
  ["fire"] = true,
  ["aurora"] = true,
  ["ocean"] = true,
  ["code-rain"] = true
}

-- The wave directions, in dropdown order.
patterns.directions = { "left-right", "right-left", "top-bottom", "bottom-top", "diagonal" }

-- How dark "off" lamps are. Fully black would look like a dead lamp.
local DIM = 0.04

-- Color helpers -------------------------------------------------------------

local function make_color(r, g, b)
  return { r = r, g = g, b = b }
end

local function scale(color, amount)
  return make_color(color.r * amount, color.g * amount, color.b * amount)
end

local function mix(a, b, amount)
  return make_color(
    a.r + (b.r - a.r) * amount,
    a.g + (b.g - a.g) * amount,
    a.b + (b.b - a.b) * amount
  )
end

local function clamp(value, low, high)
  return math.max(low, math.min(high, value))
end

-- Keep just the part after the decimal point, so 2.25 becomes 0.25.
local function wrap(value)
  return value - math.floor(value)
end

-- Turn a hue (0 to 1, around the color wheel) into a fully bright color.
local function hue_to_color(hue)
  hue = wrap(hue) * 6
  local section = math.floor(hue)
  local f = hue - section
  if section == 0 then return make_color(1, f, 0) end
  if section == 1 then return make_color(1 - f, 1, 0) end
  if section == 2 then return make_color(0, 1, f) end
  if section == 3 then return make_color(0, 1 - f, 1) end
  if section == 4 then return make_color(f, 0, 1) end
  return make_color(1, 0, 1 - f)
end

-- A repeatable "random" number from 0 to 1. The same inputs always give the
-- same answer, which keeps multiplayer games in sync.
local function noise(a, b)
  local x = math.sin(a * 12.9898 + b * 78.233) * 43758.5453
  return wrap(x)
end

-- Pick a color from a list. If loop is true, the end blends back into the start.
local function sample(list, position, loop)
  local count = #list
  if count == 1 then
    return list[1]
  end

  if loop then
    position = wrap(position) * count
    local index = math.floor(position)
    local next_index = (index + 1) % count
    return mix(list[index + 1], list[next_index + 1], position - index)
  end

  position = clamp(position, 0, 1) * (count - 1)
  local index = math.min(math.floor(position), count - 2)
  return mix(list[index + 1], list[index + 2], position - index)
end

-- The group's main color source: the rainbow, or the player's custom colors.
-- position goes from 0 to 1 and loops.
local function palette(group, position)
  if group.color_mode == "custom" then
    local list = {}
    for i = 1, group.color_count do
      table.insert(list, group.colors[i])
    end
    return sample(list, position, true)
  end
  return hue_to_color(position)
end

-- Fixed color schemes for the themed patterns.
local FIRE = {
  make_color(0.15, 0, 0),
  make_color(0.8, 0.1, 0),
  make_color(1, 0.45, 0),
  make_color(1, 0.85, 0.25)
}
local AURORA = {
  make_color(0, 0.9, 0.4),
  make_color(0, 0.7, 0.8),
  make_color(0.5, 0.2, 0.9)
}
local OCEAN = {
  make_color(0, 0.12, 0.45),
  make_color(0, 0.45, 0.8),
  make_color(0.1, 0.8, 0.9)
}
local CODE_GREEN = make_color(0, 1, 0.3)
local CODE_HEAD = make_color(0.75, 1, 0.8)
local WHITE = make_color(1, 1, 1)
local HEART_RED = make_color(1, 0.05, 0.1)

-- How bright one lamp is in a falling column (used by Rainfall and Code rain).
-- Returns 0 to 1, and how far the lamp is behind the drop's head.
local function falling_drop(group, lamp, t)
  local tail = 6
  local column_speed = 0.6 + 0.8 * noise(lamp.ix, group.id + 7)
  local start_offset = noise(lamp.ix, group.id)
  local span = group.row_count + tail

  local head = (t * 4 * column_speed + start_offset * span) % span
  local behind = head - lamp.iy
  if behind >= 0 and behind < tail then
    return 1 - behind / tail, behind
  end
  return 0, behind
end

-- The patterns ---------------------------------------------------------------

local compute = {}

compute["rainbow"] = function(group, lamp, t)
  return palette(group, t * 0.1)
end

compute["wave"] = function(group, lamp, t)
  local distance
  local direction = group.direction
  if direction == "right-left" then
    distance = -lamp.x
  elseif direction == "top-bottom" then
    distance = lamp.y
  elseif direction == "bottom-top" then
    distance = -lamp.y
  elseif direction == "diagonal" then
    distance = (lamp.x + lamp.y) * 0.7
  else
    distance = lamp.x
  end
  -- One full color cycle every 16 tiles, moving 4 tiles per second.
  return palette(group, distance / 16 - t * 0.25)
end

compute["twinkle"] = function(group, lamp, t)
  local slot = math.floor(t * 1.5 + lamp.seed * 3)
  return palette(group, noise(lamp.seed, slot))
end

compute["breathe"] = function(group, lamp, t)
  local brightness = 0.1 + 0.9 * (0.5 + 0.5 * math.sin(t * 1.2))
  return scale(palette(group, t * 0.04), brightness)
end

compute["rainfall"] = function(group, lamp, t)
  local brightness = falling_drop(group, lamp, t)
  local color = palette(group, noise(lamp.ix, 3))
  return scale(color, math.max(brightness, DIM))
end

compute["ripple"] = function(group, lamp, t)
  local dx = lamp.x - group.center_x
  local dy = lamp.y - group.center_y
  local distance = math.sqrt(dx * dx + dy * dy)
  return palette(group, distance / 12 - t * 0.4)
end

compute["spiral"] = function(group, lamp, t)
  local dx = lamp.x - group.center_x
  local dy = lamp.y - group.center_y
  local distance = math.sqrt(dx * dx + dy * dy)
  local angle = math.atan2(dy, dx) / (2 * math.pi)
  return palette(group, angle + distance / 40 - t * 0.15)
end

compute["checkerboard"] = function(group, lamp, t)
  -- Custom colors stay put; the rainbow slowly drifts.
  local drift = 0
  if group.color_mode ~= "custom" then
    drift = t * 0.03
  end

  local square = (lamp.ix + lamp.iy) % 2
  local flip = math.floor(t) % 2
  if square == flip then
    return palette(group, drift)
  end
  return palette(group, drift + 0.5)
end

compute["fireworks"] = function(group, lamp, t)
  local interval = 0.6
  local lifetime = 2
  local now = math.floor(t / interval)
  local best = 0
  local best_color = palette(group, 0)

  -- Check the last few bursts, since each one lasts a couple of seconds.
  for burst = now - 3, now do
    local age = t - burst * interval
    if age >= 0 and age < lifetime then
      local center = group.list[math.floor(noise(burst, group.id) * group.count) + 1]
      if center then
        local dx = lamp.x - center.x
        local dy = lamp.y - center.y
        local distance = math.sqrt(dx * dx + dy * dy)
        local radius = age * 8
        local ring = 1 - math.abs(distance - radius) / 2.5
        local brightness = ring * (1 - age / lifetime)
        if brightness > best then
          best = brightness
          best_color = palette(group, noise(burst, 11))
        end
      end
    end
  end

  return scale(best_color, math.max(best, DIM))
end

compute["life"] = function(group, lamp, t)
  if group.life and group.life[lamp.key] then
    return palette(group, t * 0.05 + lamp.ix * 0.02)
  end
  return scale(palette(group, t * 0.05), DIM)
end

compute["fire"] = function(group, lamp, t)
  -- 0 at the top row, 1 at the bottom row. Bottom burns hottest.
  local height = 0.7
  if group.row_count > 1 then
    height = lamp.iy / (group.row_count - 1)
  end
  local flicker = noise(lamp.seed, math.floor(t * 8))
  local heat = clamp(height * 0.8 + flicker * 0.5 - 0.15, 0, 1)
  return sample(FIRE, heat, false)
end

compute["aurora"] = function(group, lamp, t)
  local position = 0.5 * math.sin(lamp.x * 0.15 + t * 0.6) + 0.25 * math.sin(lamp.y * 0.1 - t * 0.4)
  local brightness = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(lamp.x * 0.08 - t * 0.5 + lamp.y * 0.05))
  return scale(sample(AURORA, position, true), brightness)
end

compute["ocean"] = function(group, lamp, t)
  local position = 0.5 + 0.25 * math.sin(lamp.x * 0.2 - t * 0.8) + 0.25 * math.sin(lamp.y * 0.15 + t * 0.5)
  return sample(OCEAN, position, false)
end

compute["code-rain"] = function(group, lamp, t)
  local brightness, behind = falling_drop(group, lamp, t)
  if brightness > 0 and behind < 1 then
    return CODE_HEAD
  end
  return scale(CODE_GREEN, math.max(brightness, DIM))
end

compute["chase"] = function(group, lamp, t)
  local count = group.count
  local tail = clamp(count * 0.05, 3, 12)
  local head = (t * 6) % count
  local behind = (head - lamp.order) % count
  local brightness = 0
  if behind < tail then
    brightness = 1 - behind / tail
  end
  return scale(palette(group, t * 0.05), math.max(brightness, DIM))
end

compute["heartbeat"] = function(group, lamp, t)
  local beat = t % 1.2
  local first = math.exp(-((beat - 0.1) / 0.05) ^ 2)
  local second = 0.7 * math.exp(-((beat - 0.35) / 0.06) ^ 2)
  local brightness = math.max(first + second, DIM)

  local color = HEART_RED
  if group.color_mode == "custom" then
    color = palette(group, 0)
  end
  return scale(color, brightness)
end

compute["sparkle"] = function(group, lamp, t)
  if noise(lamp.seed, math.floor(t * 6)) > 0.93 then
    return WHITE
  end
  return scale(palette(group, t * 0.03), 0.5)
end

compute["strobe"] = function(group, lamp, t)
  local color = WHITE
  if group.color_mode == "custom" then
    color = palette(group, 0)
  end
  if math.floor(t * 8) % 2 == 0 then
    return color
  end
  return scale(color, DIM)
end

-- Work out a lamp's color. Unknown patterns fall back to Rainbow.
function patterns.get_color(group, lamp, t)
  local pattern = compute[group.pattern] or compute["rainbow"]
  return pattern(group, lamp, t)
end

-- Game of Life ---------------------------------------------------------------

-- Fill the grid randomly, about 30% alive.
local function seed_life(group, generation)
  group.life = {}
  for key, lamp in pairs(group.cells) do
    if noise(lamp.ix * 31 + lamp.iy, generation) < 0.3 then
      group.life[key] = true
    end
  end
end

-- Move the Game of Life forward one generation, using each lamp's grid
-- column and row, so lamp spacing doesn't matter.
function patterns.step_life(group, generation)
  group.life_steps = (group.life_steps or 0) + 1

  -- Start fresh at the beginning, and every so often so it never gets stuck.
  if not group.life or group.life_steps % 150 == 1 then
    seed_life(group, generation)
    return
  end

  local new_life = {}
  local alive_count = 0
  local changed = false

  for key, lamp in pairs(group.cells) do
    local neighbors = 0
    for dx = -1, 1 do
      for dy = -1, 1 do
        if not (dx == 0 and dy == 0) then
          if group.life[(lamp.ix + dx) .. ":" .. (lamp.iy + dy)] then
            neighbors = neighbors + 1
          end
        end
      end
    end

    local alive = group.life[key]
    local alive_next = neighbors == 3 or (alive and neighbors == 2)
    if alive_next then
      new_life[key] = true
      alive_count = alive_count + 1
    end
    if (alive and not alive_next) or (alive_next and not alive) then
      changed = true
    end
  end

  -- Everything died or froze in place, so start over.
  if alive_count == 0 or not changed then
    seed_life(group, generation)
    return
  end

  group.life = new_life
end

return patterns
