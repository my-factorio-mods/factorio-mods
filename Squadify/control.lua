-- Squadify: automatically use combat robot capsules from the player's
-- inventory, keeping the number of following robots up to a cap.

-- How often to check, in ticks. 60 ticks is one second, so 10 is 6 times a second.
local CHECK_INTERVAL = 10

-- The capsules Squadify can use, strongest first. If the research limit is
-- reached, types higher on this list get filled first.
-- robot_count is how many robots one capsule makes in vanilla.
local CAPSULES = {
  { capsule = "destroyer-capsule", robot = "destroyer", robot_count = 5, setting = "squadify-cap-destroyer" },
  { capsule = "defender-capsule", robot = "defender", robot_count = 1, setting = "squadify-cap-defender" },
  { capsule = "distractor-capsule", robot = "distractor", robot_count = 3, setting = "squadify-cap-distractor" }
}

-- The most robots of any kind the game lets this player have following them.
local function get_research_limit(player, character)
  return player.force.maximum_following_robot_count
    + character.character_maximum_following_robot_count_bonus
end

-- Count the player's following robots by name, plus the total.
local function count_robots(character)
  local counts = {}
  local total = 0
  for _, robot in pairs(character.following_robots) do
    counts[robot.name] = (counts[robot.name] or 0) + 1
    total = total + 1
  end
  return counts, total
end

-- Find a stack of this capsule in the player's inventory, or nil.
local function find_capsule_stack(inventory, capsule_name)
  for i = 1, #inventory do
    local stack = inventory[i]
    if stack.valid_for_read and stack.name == capsule_name then
      return stack
    end
  end
  return nil
end

-- Use one capsule from the stack and spawn its robots following the character.
local function deploy(player, character, stack, capsule)
  local quality = stack.quality.name

  -- Take one capsule.
  if stack.count > 1 then
    stack.count = stack.count - 1
  else
    stack.clear()
  end

  for _ = 1, capsule.robot_count do
    -- Spread them out a little so they don't all start on top of each other.
    local position = {
      x = character.position.x + (math.random() - 0.5) * 2,
      y = character.position.y + (math.random() - 0.5) * 2
    }

    local robot = character.surface.create_entity({
      name = capsule.robot,
      position = position,
      force = player.force,
      quality = quality
    })

    if robot then
      robot.combat_robot_owner = character
    end
  end
end

local function check_player(player)
  -- Needs a character (not a space platform, remote view only, or god mode).
  local character = player.character
  if not character then
    return
  end

  local player_settings = settings.get_player_settings(player)
  if not player_settings["squadify-enabled"].value then
    return
  end

  -- Only deploy when enemies are close, unless the player turned that off.
  if player_settings["squadify-only-near-enemies"].value then
    local enemy = character.surface.find_nearest_enemy({
      position = character.position,
      max_distance = player_settings["squadify-range"].value,
      force = player.force
    })
    if not enemy then
      return
    end
  end

  local counts, total = count_robots(character)
  local total_room = get_research_limit(player, character) - total
  if total_room <= 0 then
    return
  end

  local inventory = player.get_main_inventory()
  if not inventory then
    return
  end

  -- Use the first capsule type that's under its own cap, where all of its
  -- robots fit under both that cap and the research limit.
  -- Only one capsule per check, so robots come out gradually.
  for _, capsule in pairs(CAPSULES) do
    local type_room = player_settings[capsule.setting].value - (counts[capsule.robot] or 0)
    local room = math.min(type_room, total_room)

    if capsule.robot_count <= room then
      local stack = find_capsule_stack(inventory, capsule.capsule)
      if stack then
        deploy(player, character, stack, capsule)
        return
      end
    end
  end
end

script.on_nth_tick(CHECK_INTERVAL, function()
  for _, player in pairs(game.connected_players) do
    check_player(player)
  end
end)

-- Hotkey flips the "Auto-deploy" setting so it stays in sync with Mod settings.
script.on_event("squadify-toggle", function(event)
  local player = game.get_player(event.player_index)
  if not player then
    return
  end

  local turned_on = not player.mod_settings["squadify-enabled"].value
  player.mod_settings["squadify-enabled"] = { value = turned_on }

  local text = "Squadify off"
  if turned_on then
    text = "Squadify on"
  end

  player.create_local_flying_text({
    text = text,
    create_at_cursor = true
  })
end)
