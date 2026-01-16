-- Formation Engine: Moves 11 player instances smoothly across the pitch
-- with fading trail effects behind each player
-- Uses ViewModel properties (posX, posY) instead of direct node access

type FormationEngine = {
  players: { PlayerState },
  context: Context?,
  isAnimating: boolean,
}

local PLAYER_COUNT = 11
local ARRIVAL_THRESHOLD = 0.1
local TRAIL_LENGTH_RATIO = 1 / 3 -- Trail is 1/3 of total distance

local TRAIL_FADE_SPEED = 3 -- How fast the trail fades out after arrival

type PlayerState = {
  vm: ViewModel,
  posX: Property<number>,
  posY: Property<number>,
  targetX: Property<number>,
  targetY: Property<number>,
  startX: number,
  startY: number,
  totalDistance: number,
  trailPath: Path,
  teamColor: Color,
  trailOpacity: number, -- Current trail opacity for fade out
  hasArrived: boolean,  -- Whether player has reached target
}

-- Get ViewModel property values safely
local function getVMNumber(vm: ViewModel, name: string): number
  local prop = vm:getNumber(name)
  if prop then
    return prop.value
  end
  return 0
end

local function getVMColor(vm: ViewModel, name: string): Color
  local prop = vm:getColor(name)
  if prop then
    return prop.value
  end
  return Color.rgb(255, 255, 255)
end

-- Callback to trigger animation when target changes
local function onTargetChanged(self: FormationEngine)
  if self.context then
    self.isAnimating = true
    -- Recalculate start positions for all players
    for _, player in ipairs(self.players) do
      local currentX = player.posX.value
      local currentY = player.posY.value
      local targetX = player.targetX.value
      local targetY = player.targetY.value

      local dx = targetX - currentX
      local dy = targetY - currentY
      player.totalDistance = math.sqrt(dx * dx + dy * dy)
      player.startX = currentX
      player.startY = currentY
      player.teamColor = getVMColor(player.vm, "teamColor")
      player.trailOpacity = 1 -- Reset opacity to full
      player.hasArrived = false -- Mark as moving
    end
    self.context:markNeedsUpdate()
  end
end

function init(self: FormationEngine, context: Context): boolean
  self.context = context
  self.players = {}
  self.isAnimating = false

  local mainVM = context:viewModel()
  if not mainVM then
    print('FormationEngine: No ViewModel available')
    return false
  end

  for i = 1, PLAYER_COUNT do
    local playerName = 'player' .. tostring(i)
    local playerVMProp = mainVM:getViewModel(playerName)

    if playerVMProp then
      local playerVM = playerVMProp.value

      -- Get position properties (these should be bound to node positions in Rive)
      local posXProp = playerVM:getNumber('posX')
      local posYProp = playerVM:getNumber('posY')
      local targetXProp = playerVM:getNumber('targetX')
      local targetYProp = playerVM:getNumber('targetY')

      if posXProp and posYProp and targetXProp and targetYProp then
        local currentX = posXProp.value
        local currentY = posYProp.value
        local targetX = targetXProp.value
        local targetY = targetYProp.value

        local dx = targetX - currentX
        local dy = targetY - currentY
        local totalDist = math.sqrt(dx * dx + dy * dy)

        local state: PlayerState = {
          vm = playerVM,
          posX = posXProp,
          posY = posYProp,
          targetX = targetXProp,
          targetY = targetYProp,
          startX = currentX,
          startY = currentY,
          totalDistance = totalDist,
          trailPath = Path.new(),
          teamColor = getVMColor(playerVM, "teamColor"),
          trailOpacity = 0,
          hasArrived = true,
        }

        -- Add listeners for target changes
        targetXProp:addListener(self, function(_self: FormationEngine)
          onTargetChanged(_self)
        end)
        targetYProp:addListener(self, function(_self: FormationEngine)
          onTargetChanged(_self)
        end)

        table.insert(self.players, state)
      end
    end
  end

  print('FormationEngine: Initialized with', #self.players, 'players')
  return #self.players > 0
end

function update(self: FormationEngine)
  if not self.isAnimating then
    for _, player in ipairs(self.players) do
        local dist = math.abs(player.posX.value - player.targetX.value) + math.abs(player.posY.value - player.targetY.value)
        if dist > ARRIVAL_THRESHOLD then
            onTargetChanged(self)
            break
        end
    end
  end
end

function advance(self: FormationEngine, seconds: number): boolean
  if not self.isAnimating then
    return true -- Keep alive but don't process
  end

  local anyActive = false

  for _, player in ipairs(self.players) do
    local currentX = player.posX.value
    local currentY = player.posY.value
    local targetX = player.targetX.value
    local targetY = player.targetY.value
    local speed = getVMNumber(player.vm, "speed")

    if speed <= 0 then
      speed = 5 -- Default speed
    end

    local dx = targetX - currentX
    local dy = targetY - currentY
    local distanceSquared = dx * dx + dy * dy

    if not player.hasArrived then
      if distanceSquared <= ARRIVAL_THRESHOLD * ARRIVAL_THRESHOLD then
        -- Snap to target and mark as arrived
        player.posX.value = targetX
        player.posY.value = targetY
        player.hasArrived = true
        -- Don't reset trail yet - let it fade out
      else
        -- Exponential interpolation: 1 - e^(-speed * dt)
        local lerpFactor = 1 - math.exp(-speed * seconds)

        local newX = currentX + dx * lerpFactor
        local newY = currentY + dy * lerpFactor

        -- Update position via ViewModel (data binding moves the node)
        player.posX.value = newX
        player.posY.value = newY

        -- Update trail path
        local distanceRemaining = math.sqrt(distanceSquared)
        local distanceTraveled = player.totalDistance - distanceRemaining
        local trailLength = player.totalDistance * TRAIL_LENGTH_RATIO

        -- Trail starts from current position and extends back along the path
        player.trailPath:reset()

        if distanceTraveled > 0 and player.totalDistance > 0 then
          -- Direction from start to target (normalized)
          local dirX = (targetX - player.startX) / player.totalDistance
          local dirY = (targetY - player.startY) / player.totalDistance

          -- Trail end is at current position
          local trailEndX = newX
          local trailEndY = newY

          -- Trail start is behind the player (clamped to start position)
          local trailStartDist = math.max(0, distanceTraveled - trailLength)
          local trailStartX = player.startX + dirX * trailStartDist
          local trailStartY = player.startY + dirY * trailStartDist

          player.trailPath:moveTo(Vector.xy(trailStartX, trailStartY))
          player.trailPath:lineTo(Vector.xy(trailEndX, trailEndY))
        end

        anyActive = true
      end
    end

    -- Handle trail fade out after arrival
    if player.hasArrived and player.trailOpacity > 0 then
      -- Fade out using exponential interpolation
      player.trailOpacity = player.trailOpacity * math.exp(-TRAIL_FADE_SPEED * seconds)
      
      -- Clamp to zero when very small
      if player.trailOpacity < 0.01 then
        player.trailOpacity = 0
        player.trailPath:reset()
      else
        anyActive = true
      end
    end
  end

  -- Stop animating when all players have arrived and trails have faded
  if not anyActive then
    self.isAnimating = false
  end

  return true -- Always return true to keep advance being called
end

function draw(self: FormationEngine, renderer: Renderer)
  for _, player in ipairs(self.players) do
    local pathLen = #player.trailPath
    if pathLen > 0 and player.trailOpacity > 0 then
      local currentX = player.posX.value
      local currentY = player.posY.value
      local targetX = player.targetX.value
      local targetY = player.targetY.value

      local dx = targetX - currentX
      local dy = targetY - currentY
      local distanceRemaining = math.sqrt(dx * dx + dy * dy)
      local distanceTraveled = player.totalDistance - distanceRemaining

      -- Calculate trail bounds for gradient
      local trailLength = player.totalDistance * TRAIL_LENGTH_RATIO
      local trailStartDist = math.max(0, distanceTraveled - trailLength)

      if player.totalDistance > 0 then
        local dirX = (targetX - player.startX) / player.totalDistance
        local dirY = (targetY - player.startY) / player.totalDistance

        local trailStartX = player.startX + dirX * trailStartDist
        local trailStartY = player.startY + dirY * trailStartDist
        local trailEndX = currentX
        local trailEndY = currentY

        -- Apply overall trail opacity for fade out effect
        local baseColor = Color.opacity(player.teamColor, player.trailOpacity)
        local transparentColor = Color.opacity(player.teamColor, 0)

        -- Gradient: solid (baseColor) near player (trailEnd), transparent far from player (trailStart)
        local gradient = Gradient.linear(
          Vector.xy(trailStartX, trailStartY),
          Vector.xy(trailEndX, trailEndY),
          {
            { position = 0, color = transparentColor }, -- Far from player (trail start)
            { position = 1, color = baseColor },        -- Near player (trail end)
          }
        )

        local trailPaint = Paint.with({
          style = "stroke",
          thickness = 4,
          cap = "round",
          gradient = gradient,
        })

        renderer:drawPath(player.trailPath, trailPaint)
      end
    end
  end
end

return function(): Node<FormationEngine>
  return {
    players = {},
    context = nil,
    isAnimating = false,
    init = init,
    update = update,
    advance = advance,
    draw = draw,
  }
end
