local Radar = {}

-- ==========================================
-- CONFIGURATION
-- ==========================================
local PITCH_WIDTH, PITCH_HEIGHT = 407, 728.5
local SENSORS = {
  { x = 0, y = -PITCH_HEIGHT/2 },              -- Top
  { x = PITCH_WIDTH/2, y = -PITCH_HEIGHT/4 },  -- Top-Right
  { x = PITCH_WIDTH/2, y = PITCH_HEIGHT/4 },   -- Bottom-Right
  { x = 0, y = PITCH_HEIGHT/2 },               -- Bottom
  { x = -PITCH_WIDTH/2, y = PITCH_HEIGHT/4 },  -- Bottom-Left
  { x = -PITCH_WIDTH/2, y = -PITCH_HEIGHT/4 }, -- Top-Left
}

-- Persistent state
local currentValues = {0, 0, 0, 0, 0, 0}
local lastTotal = 0

function Radar.calculateMetrics(players: { any }): any
  local totalPlayers = #players
  
  -- 1. DETECT FORMATION CHANGE: Snap to 0 to start the cycle
  if totalPlayers ~= lastTotal then
    for i = 1, 6 do currentValues[i] = 0 end
    lastTotal = totalPlayers
  end

  -- 2. SPATIAL SENSING: Get raw swarm density
  local raw = {0, 0, 0, 0, 0, 0}
  local maxRaw = 0
  
  for _, p in ipairs(players) do
    local px, py = p.posX.value, p.posY.value
    for i, sensor in ipairs(SENSORS) do
      local dist = math.sqrt((px - sensor.x)^2 + (py - sensor.y)^2)
      if dist < 200 then
        local pWeight = (1 - (dist / 200))
        raw[i] = raw[i] + pWeight
        if raw[i] > maxRaw then maxRaw = raw[i] end
      end
    end
  end

  -- 3. THE 0 -> 100 -> 50 FLOW
  for i = 1, 6 do
    local relativeRatio = maxRaw > 0 and (raw[i] / maxRaw) or 0
    local target = 0
    
    -- If we are in the "Explosion" phase (started from 0)
    if currentValues[i] < 80 then
      target = relativeRatio * 105 -- Target slightly past 100 for impact
    else
      -- Once high enough, target drops to the 50 midpoint
      target = relativeRatio * 50
    end

    -- Dynamic speed: Faster on the rise, smoother on the settle
    local k = (target > currentValues[i]) and 0.3 or 0.1
    currentValues[i] = currentValues[i] + (target - currentValues[i]) * k
  end

  return {
    offence     = currentValues[1],
    width       = currentValues[2],
    depth       = currentValues[3],
    defence     = currentValues[4],
    compactness = currentValues[5],
    symmetry    = currentValues[6]
  }
end

return Radar