-- Formation Engine: Physics Follower with Reinstated Target & Hitbox Logic
-- Logic: Hitbox (Input Driver) -> Target (Memory) -> Visual (Chase)

type PlayerState = {
  vm: ViewModel,
  posX: Property<number>,
  posY: Property<number>,
  targetX: Property<number>,
  targetY: Property<number>,
  hitboxX: Property<number>, -- Added Hitbox Logic
  hitboxY: Property<number>, -- Added Hitbox Logic
  speed: Property<number>,
}

type Coordinate = { number }
type FormationData = { Coordinate }

type FormationEngine = {
  players: { PlayerState },
  context: Context?,
  isInitialized: boolean, -- Added to force first-frame snap
}

local FORMATIONS: { [string]: FormationData } = {
  ['4-4-2'] = {
    { 13, 511.96 },
    { 95, 361.96 },
    { -68, 361.96 },
    { -231, 298.96 },
    { 258, 298.96 },
    { -105.5, 56.96 },
    { 115.5, 56.96 },
    { 192, -162.29 },
    { -186, -162.29 },
    { 75.5, -490.54 },
    { -73.5, -424.04 },
  },
  ['4-3-3'] = {
    { 13, 511.96 },
    { 95, 361.96 },
    { -68, 361.96 },
    { -231, 298.96 },
    { 258, 298.96 },
    { 13, 160 },
    { -120, 25 },
    { 146, 25 },
    { -240, -320 },
    { 266, -320 },
    { 13, -485 },
  },
}

local PLAYER_COUNT = 11
local ARRIVAL_THRESHOLD = 0.1

-- Helper to update target and hitbox values
local function applyFormation(
  self: FormationEngine,
  name: string,
  snapImmediately: boolean
)
  local data = FORMATIONS[name]
  if not data then
    return
  end

  for i, player in ipairs(self.players) do
    local coords = data[i]
    if coords then
      -- Formation updates BOTH the Hitbox and the Target
      player.hitboxX.value = coords[1]
      player.hitboxY.value = coords[2]
      player.targetX.value = coords[1]
      player.targetY.value = coords[2]

      -- If snapImmediately is true, we set the current pos to the target pos
      if snapImmediately then
        player.posX.value = coords[1]
        player.posY.value = coords[2]
      end
    end
  end
end

function init(self: FormationEngine, context: Context): boolean
  self.context = context
  self.players = {}
  self.isInitialized = false -- Set to false to trigger first-frame snap

  local mainVM = context:viewModel()
  if not mainVM then
    return false
  end

  -- 1. Initialize Players (Updated to include hitbox properties)
  for i = 1, PLAYER_COUNT do
    local pVMProp = mainVM:getViewModel('player' .. i)
    if pVMProp then
      local pVM = pVMProp.value
      local pX, pY = pVM:getNumber('posX'), pVM:getNumber('posY')
      local tX, tY = pVM:getNumber('targetX'), pVM:getNumber('targetY')
      local hX, hY = pVM:getNumber('hitboxX'), pVM:getNumber('hitboxY')
      local spd = pVM:getNumber('speed')

      if pX and pY and tX and tY and hX and hY and spd then
        table.insert(self.players, {
          vm = pVM,
          posX = pX,
          posY = pY,
          targetX = tX,
          targetY = tY,
          hitboxX = hX,
          hitboxY = hY,
          speed = spd,
        })
      end
    end
  end

  -- 2. Initial Snap setup (will be reinforced in advance)
  applyFormation(self, '4-4-2', true)

  -- 3. Setup Selector Listener
  local selector = mainVM:getNumber('formationIndex')
  if selector then
    selector:addListener(self, function(engine)
      local val = selector.value
      if val == 0 then
        applyFormation(engine, '4-4-2', false) -- Smooth move
      elseif val == 1 then
        applyFormation(engine, '4-3-3', false) -- Smooth move
      end
    end)
  end

  return #self.players > 0
end

function advance(self: FormationEngine, seconds: number): boolean
  -- FORCE SNAP ON FIRST FRAME: Ensures hitboxes move to 4-4-2 coordinates
  if not self.isInitialized then
    applyFormation(self, '4-4-2', true)
    self.isInitialized = true
  end

  for _, player in ipairs(self.players) do
    -- A. CAPTURE: Constantly feed Hitbox (Drag Input) into Target (Memory)
    player.targetX.value = player.hitboxX.value
    player.targetY.value = player.hitboxY.value

    -- B. CHASE: Calculate the visual movement
    local curX, curY = player.posX.value, player.posY.value
    local tarX, tarY = player.targetX.value, player.targetY.value
    local moveSpeed = player.speed.value

    if moveSpeed <= 0 then
      moveSpeed = 5
    end

    local dx = tarX - curX
    local dy = tarY - curY

    if math.abs(dx) > ARRIVAL_THRESHOLD or math.abs(dy) > ARRIVAL_THRESHOLD then
      local lerpFactor = 1 - math.exp(-moveSpeed * seconds)
      player.posX.value = curX + (dx * lerpFactor)
      player.posY.value = curY + (dy * lerpFactor)
    else
      player.posX.value = tarX
      player.posY.value = tarY
    end
  end

  return true
end

return function(): Node<FormationEngine>
  return {
    players = {},
    context = nil,
    isInitialized = false,
    init = init,
    advance = advance,
  }
end