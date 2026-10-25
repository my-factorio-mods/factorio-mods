-- ForeverMine: make the chosen resources infinite.
--
-- This runs in data-final-fixes so ores added by other mods are included.
-- Each resource's "Infinite" checkbox (a startup setting) decides whether it
-- gets changed. Unchecked resources stay vanilla.
--
-- For an infinite resource, drill speed is (amount / normal). control.lua sets
-- each tile's amount to match the yield % picked in Mod settings.

local resources = require("resources")

-- Is the "Infinite" checkbox ticked for this resource?
-- Ores without their own checkbox use the "other" one.
local function infinite_enabled(name)
  local setting = settings.startup[resources.INFINITE_PREFIX .. name]
  if setting == nil then
    setting = settings.startup[resources.INFINITE_PREFIX .. "other"]
  end
  return setting.value
end

local is_fluid = {}
for _, name in pairs(resources.fluids) do
  is_fluid[name] = true
end

local managed_ores = {}
local managed_fluids = {}

for _, resource in pairs(data.raw.resource) do
  local name = resource.name

  if is_fluid[name] then
    -- Fluid with its own setting: just stop it from depleting.
    if infinite_enabled(name) then
      resource.infinite_depletion_amount = 0
      managed_fluids[name] = true
    end

  elseif not resource.infinite and infinite_enabled(name) then
    -- Finite ore: turn it into an infinite one.
    resource.infinite = true

    -- "normal" is the amount that counts as 100% yield. control.lua sets
    -- every tile relative to this, so the exact number doesn't change
    -- gameplay. A bigger number just means more ore is left in each tile
    -- if infinite is ever turned off again.
    if resource.normal == nil then
      resource.normal = 10000
    end

    -- Never let the amount go down when mined.
    resource.infinite_depletion_amount = 0
    resource.minimum = 1

    managed_ores[name] = true
  end
end

-- Pass the lists to control.lua.
data:extend({
  {
    type = "mod-data",
    name = "forever-mine-managed",
    data = { ores = managed_ores, fluids = managed_fluids },
  },
})
