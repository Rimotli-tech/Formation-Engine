-- Formation Engine: Physics Follower + Polar Sorting Logic
-- Logic: Hitbox (Input Driver) -> Target (Memory) -> Visual (Chase) -> Selection Math

local FORMATIONS = require('FormationData')

type PlayerState = {
  vm: ViewModel,
  posX: Property<number>,
  posY: Property<number>,
  targetX: Property<number>,
  targetY: Property<number>,
  hitboxX: Property<number>,
  hitboxY: Property<number>,
  speed: Property<number>,
  isDragged: Property<boolean>,
  isActive: Property<boolean>,
}

type SortablePoint = {
  x: number,
  y: number,
  angle: number,
}

type ShapeState = {
  vm: ViewModel,
  v1x: Property<number>,
  v1y: Property<number>,
  v2x: Property<number>,
  v2y: Property<number>,
  v3x: Property<number>,
  v3y: Property<number>,
  v4x: Property<number>,
  v4y: Property<number>,
  centerX: Property<number>,
  centerY: Property<number>,
  btnVis: Property<number>,
  shapeVis: Property<number>,
  isCommitted: Property<boolean>,
  confirmTrigger: PropertyTrigger,
}

type Coordinate = { number }
type FormationData = { Coordinate }

type FormationEngine = {
  players: { PlayerState },
  shape: ShapeState?,
  context: Context?,
  isInitialized: boolean,
  formationIndex: Property<number>?,
}

local PLAYER_COUNT = 11
local ARRIVAL_THRESHOLD = 0.1

local function updateSelectionShape(self: FormationEngine)
  local s = self.shape
  if not s then
    return
  end

  local activePoints: { SortablePoint } = {}
  local avgX, avgY = 0, 0
  local count = 0
  local isMoving = false

  for i, player in ipairs(self.players) do
    if player.isActive and player.isActive.value == true then
      local px = player.posX.value
      local py = player.posY.value

      table.insert(activePoints, {
        x = px,
        y = py,
        angle = 0,
      })

      avgX = avgX + px
      avgY = avgY + py
      count = count + 1

      if player.isDragged.value then
        isMoving = true
      end
    end
  end

  if isMoving then
    s.isCommitted.value = false
  end

  if count < 2 then
    s.btnVis.value = 0
    s.shapeVis.value = 0
    s.isCommitted.value = false
    return
  end

  local centerX = avgX / count
  local centerY = avgY / count
  s.centerX.value = centerX
  s.centerY.value = centerY
  s.btnVis.value = 100
  s.shapeVis.value = 100

  for _, pt in ipairs(activePoints) do
    pt.angle = math.atan2(pt.y - centerY, pt.x - centerX)
  end

  table.sort(activePoints, function(a: SortablePoint, b: SortablePoint)
    return a.angle < b.angle
  end)

  local p1 = activePoints[1] or { x = centerX, y = centerY }
  local p2 = activePoints[2] or p1
  local p3 = activePoints[3] or p2
  local p4 = activePoints[4] or p3

  s.v1x.value = p1.x
  s.v1y.value = p1.y
  s.v2x.value = p2.x
  s.v2y.value = p2.y
  s.v3x.value = p3.x
  s.v3y.value = p3.y
  s.v4x.value = p4.x
  s.v4y.value = p4.y
end

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
      player.hitboxX.value = coords[1]
      player.hitboxY.value = coords[2]
      player.targetX.value = coords[1]
      player.targetY.value = coords[2]
      if snapImmediately then
        player.posX.value = coords[1]
        player.posY.value = coords[2]
        player.isDragged.value = false
      end
    end
  end
end

function init(self: FormationEngine, context: Context): boolean
  print('Init: Starting Formation Engine...')
  self.context = context
  self.players = {}
  self.isInitialized = false

  local mainVM = context:viewModel()
  if not mainVM then
    print('Init Error: Could not find Main ViewModel')
    return false
  end

  for i = 1, PLAYER_COUNT do
    local pVMName = 'player' .. i
    local pVMProp = mainVM:getViewModel(pVMName)
    if pVMProp and pVMProp.value then
      local pVM = pVMProp.value
      local pX, pY = pVM:getNumber('posX'), pVM:getNumber('posY')
      local tX, tY = pVM:getNumber('targetX'), pVM:getNumber('targetY')
      local hX, hY = pVM:getNumber('hitboxX'), pVM:getNumber('hitboxY')
      local spd = pVM:getNumber('speed')
      local drag = pVM:getBoolean('isDragged')
      local active = pVM:getBoolean('isActive')

      if pX and pY and tX and tY and hX and hY and spd and drag and active then
        table.insert(self.players, {
          vm = pVM,
          posX = pX,
          posY = pY,
          targetX = tX,
          targetY = tY,
          hitboxX = hX,
          hitboxY = hY,
          speed = spd,
          isDragged = drag,
          isActive = active,
        })
      else
        print('Init Warning: Missing properties for ' .. pVMName)
      end
    else
      print('Init Warning: ViewModel not found: ' .. pVMName)
    end
  end
  print('Init: Players bound: ' .. #self.players)

  -- CHANGED: Using instance name 'selectionShape' from your screenshot
  local sVMProp = mainVM:getViewModel('selectionShape')
  if sVMProp and sVMProp.value then
    local sVM = sVMProp.value

    -- Detailed Property Probing
    local v1x, v1y = sVM:getNumber('v1x'), sVM:getNumber('v1y')
    local v2x, v2y = sVM:getNumber('v2x'), sVM:getNumber('v2y')
    local v3x, v3y = sVM:getNumber('v3x'), sVM:getNumber('v3y')
    local v4x, v4y = sVM:getNumber('v4x'), sVM:getNumber('v4y')
    local cx, cy = sVM:getNumber('centerX'), sVM:getNumber('centerY')
    local bv = sVM:getNumber('btnVis') -- Matches screenshot
    local sv = sVM:getNumber('shapeVis') -- Matches screenshot
    local ic = sVM:getBoolean('isCommitted')
    local ct = sVM:getTrigger('confirmTrigger')

    -- DEBUG BLOCK: Pinpoint which property is missing
    if not v1x or not v1y then
      print('Debug: v1x/y missing')
    end
    if not v2x or not v2y then
      print('Debug: v2x/y missing')
    end
    if not v3x or not v3y then
      print('Debug: v3x/y missing')
    end
    if not v4x or not v4y then
      print('Debug: v4x/y missing')
    end
    if not cx or not cy then
      print('Debug: centerX/Y missing')
    end
    if not bv then
      print('Debug: btnVis missing')
    end
    if not sv then
      print('Debug: shapeVis missing')
    end
    if not ic then
      print('Debug: isCommitted missing')
    end
    if not ct then
      print('Debug: confirmTrigger missing')
    end

    if
      v1x
      and v1y
      and v2x
      and v2y
      and v3x
      and v3y
      and v4x
      and v4y
      and cx
      and cy
      and bv
      and sv
      and ic
      and ct
    then
      self.shape = {
        vm = sVM,
        v1x = v1x,
        v1y = v1y,
        v2x = v2x,
        v2y = v2y,
        v3x = v3x,
        v3y = v3y,
        v4x = v4x,
        v4y = v4y,
        centerX = cx,
        centerY = cy,
        btnVis = bv,
        shapeVis = sv,
        isCommitted = ic,
        confirmTrigger = ct,
      }
      ct:addListener(self, function()
        if self.shape then
          self.shape.isCommitted.value = true
        end
      end)
      print('Init: selectionShape successfully bound')
    else
      print(
        'Init Error: selectionShape missing core properties (see Debug above)'
      )
    end
  else
    print('Init Error: selectionShape instance not found')
  end

  --applyFormation(self, '4-4-2 (Box)', true)

  local formationMapping = {
    [0] = '4-4-2 (Box)',
    [1] = '4-4-2 (Diamond)',
    [2] = '4-4-2 (Flat)',
    [3] = '4-2-3-1',
    [4] = '3-4-2-1',
    [5] = '3-5-2',
    [6] = '4-1-4-1',
    [7] = '4-3-2-1',
    [8] = '4-4-1-1',
    [9] = '4-3-2-1',
    [10] = '4-4-2 (Box)',
    [11] = '5-3-2',
  }

  local selector = mainVM:getNumber('formationIndex')
  if selector then
    self.formationIndex = selector
    applyFormation(
      self,
      formationMapping[math.floor(selector.value)] or '4-4-2 (Box)',
      true
    )
    selector:addListener(self, function(engine)
      local index = math.floor(selector.value)
      local formationName = formationMapping[index]
      applyFormation(engine, formationName or '4-4-2 (Box)', false)
    end)
  end

  return #self.players > 0
end

function advance(self: FormationEngine, seconds: number): boolean
  if not self.isInitialized then
    applyFormation(self, '4-4-2 (Box)', true)
    self.isInitialized = true
  end

  for _, player in ipairs(self.players) do
    player.targetX.value = player.hitboxX.value
    player.targetY.value = player.hitboxY.value
    local curX, curY = player.posX.value, player.posY.value
    local tarX, tarY = player.targetX.value, player.targetY.value
    local moveSpeed = player.speed.value > 0 and player.speed.value or 5
    local dx, dy = tarX - curX, tarY - curY

    if math.abs(dx) > ARRIVAL_THRESHOLD or math.abs(dy) > ARRIVAL_THRESHOLD then
      player.isDragged.value = true
      local lerp = 1 - math.exp(-moveSpeed * seconds)
      player.posX.value = curX + (dx * lerp)
      player.posY.value = curY + (dy * lerp)
    else
      player.posX.value, player.posY.value = tarX, tarY
      player.isDragged.value = false
    end
  end

  updateSelectionShape(self)
  return true
end

return function(): Node<FormationEngine>
  return {
    players = {},
    shape = nil,
    context = nil,
    isInitialized = false,
    formationIndex = nil,
    init = init,
    advance = advance,
  }
end
