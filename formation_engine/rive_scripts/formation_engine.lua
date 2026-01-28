local FORMATIONS = require('formation_data')
local Radar = require('radar_system')
local ToolManager = require('tool_manager')
local Utils = require('formation_utils')

-- ======================================================================================
-- TYPE DEFINITIONS
-- ======================================================================================
type PlayerState = Utils.PlayerState
type ShapeState = Utils.ShapeState
type Tool = ToolManager.Tool

type GameEngine = {
  -- Core State
  players: { PlayerState },
  shape: ShapeState?,
  context: Context?,
  isInitialized: boolean,
  formationIndex: Property<number>?,
  radarVM: ViewModel?,

  -- Clipping / Bounds State
  hasBounds: boolean,
  minX: number,
  minY: number,
  maxX: number,
  maxY: number,

  -- Tool State
  activeToolIndex: number,
  tools: { [number]: Tool },
  clearAll: boolean,
  justCleared: boolean,
}

local function isPointInBounds(self: GameEngine, vec: Vector): boolean
  if not self.hasBounds then
    return true
  end

  -- We pass the Vector first, and a table of the 4 numbers second
  return Utils.isPointInBounds(vec, {
    minX = self.minX,
    minY = self.minY,
    maxX = self.maxX,
    maxY = self.maxY,
  })
end

-- ======================================================================================
-- LOGIC: FORMATIONS
-- ======================================================================================
local function applyFormation(
  self: GameEngine,
  name: string,
  snapImmediately: boolean
)
  local data = FORMATIONS[name]
  if not data then
    return
  end

  local C = Utils.CONSTANTS

  for i, player in ipairs(self.players) do
    local coords = data[i]
    if coords then
      -- Convert normalized coordinates (0-1) to pitch dimensions
      local targetX = coords[1] * C.PITCH_WIDTH
      local targetY = coords[2] * C.PITCH_HEIGHT

      player.targetX.value = targetX
      player.targetY.value = targetY
      player.hitboxX.value = targetX
      player.hitboxY.value = targetY

      if snapImmediately then
        player.posX.value = targetX
        player.posY.value = targetY
      end
    end
  end

  -- Calculate Radar Stats (Logic preserved from original)
  local stats = Radar.calculateMetrics(self.players)
  if self.radarVM then
    local off = self.radarVM:getNumber('offence')
    local def = self.radarVM:getNumber('defence')
    local wid = self.radarVM:getNumber('width')
    local dep = self.radarVM:getNumber('depth')
    local com = self.radarVM:getNumber('compactness')
    local sym = self.radarVM:getNumber('symmetry')

    if off and def and wid and dep and com and sym then
      off.value = stats.offence
      def.value = stats.defence
      wid.value = stats.width
      dep.value = stats.depth
      com.value = stats.compactness
      sym.value = stats.symmetry
    end
  end
end

-- ======================================================================================
-- LIFECYCLE
-- ======================================================================================
function init(self: GameEngine, context: Context): boolean
  print('Init: Starting Slimmed Game Engine...')
  self.context = context
  self.players = {}
  self.isInitialized = false
  self.activeToolIndex = 1
  self.tools = ToolManager.createTools() -- Initialize the Toolbox
  self.clearAll = false
  self.justCleared = false

  local mainVM = context:viewModel()
  if not mainVM then
    return false
  end

  -- 1. Setup Bounds
  local bMinX = mainVM:getNumber('boundsMinX')
  local bMinY = mainVM:getNumber('boundsMinY')
  local bMaxX = mainVM:getNumber('boundsMaxX')
  local bMaxY = mainVM:getNumber('boundsMaxY')

  if bMinX and bMinY and bMaxX and bMaxY then
    self.hasBounds = true
    self.minX, self.minY = bMinX.value, bMinY.value
    self.maxX, self.maxY = bMaxX.value, bMaxY.value

    bMinX:addListener(self, function()
      self.minX = bMinX.value
    end)
    bMinY:addListener(self, function()
      self.minY = bMinY.value
    end)
    bMaxX:addListener(self, function()
      self.maxX = bMaxX.value
    end)
    bMaxY:addListener(self, function()
      self.maxY = bMaxY.value
    end)
  else
    self.hasBounds = false
  end

  -- 2. Setup Tool Switching
  local toolProp = mainVM:getNumber('activeTool')
  if toolProp then
    self.activeToolIndex = math.floor(toolProp.value)
    toolProp:addListener(self, function()
      self.activeToolIndex = math.floor(toolProp.value)
      -- Reset current interactions when switching tools
      for _, tool in pairs(self.tools) do
        -- Optional: specific reset logic per tool switch if needed
      end
    end)
  end

  local clearTrigger = mainVM:getTrigger('clearDrawingsTrigger')
  if clearTrigger then
    clearTrigger:addListener(self, function()
      self.clearAll = true
    end)
  end

  -- 3. Setup Players
  local C = Utils.CONSTANTS
  for i = 1, C.PLAYER_COUNT do
    local pVMName = 'player' .. i
    local pVMProp = mainVM:getViewModel(pVMName)
    if pVMProp and pVMProp.value then
      local pVM = pVMProp.value

      -- Gather properties safely
      local pX, pY = pVM:getNumber('posX'), pVM:getNumber('posY')
      local tX, tY = pVM:getNumber('targetX'), pVM:getNumber('targetY')
      local hX, hY = pVM:getNumber('hitboxX'), pVM:getNumber('hitboxY')
      local spd = pVM:getNumber('speed')
      local drag = pVM:getBoolean('isDragged')
      local active = pVM:getBoolean('isActive')

      if pX and pY and tX and tY and hX and hY and spd and drag and active then
        table.insert(
          self.players,
          {
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
            visualWeight = 0.0, -- Init for Heatmap
          } :: PlayerState
        )
      end
    end
  end

  -- 4. Setup Shape UI
  local sVMProp = mainVM:getViewModel('selectionShape')
  if sVMProp and sVMProp.value then
    local sVM = sVMProp.value
    self.shape = {
      vm = sVM,
      v1x = sVM:getNumber('v1x'),
      v1y = sVM:getNumber('v1y'),
      v2x = sVM:getNumber('v2x'),
      v2y = sVM:getNumber('v2y'),
      v3x = sVM:getNumber('v3x'),
      v3y = sVM:getNumber('v3y'),
      v4x = sVM:getNumber('v4x'),
      v4y = sVM:getNumber('v4y'),
      centerX = sVM:getNumber('centerX'),
      centerY = sVM:getNumber('centerY'),
      btnVis = sVM:getNumber('btnVis'),
      shapeVis = sVM:getNumber('shapeVis'),
      isCommitted = sVM:getBoolean('isCommitted'),
      confirmTrigger = sVM:getTrigger('confirmTrigger'),
    } :: ShapeState

    if self.shape and self.shape.confirmTrigger then
      self.shape.confirmTrigger:addListener(self, function()
        if self.shape then
          self.shape.isCommitted.value = true
        end
      end)
    end
  end

  -- 5. Setup Radar
  local rVMProp = mainVM:getViewModel('radarChart')
  if rVMProp and rVMProp.value then
    self.radarVM = rVMProp.value
  end

  -- 6. Setup Formation Selector
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
    local initialName = formationMapping[math.floor(selector.value)]
      or '4-4-2 (Box)'
    applyFormation(self, initialName, true)

    selector:addListener(self, function(engine)
      local name = formationMapping[math.floor(selector.value)] or '4-4-2 (Box)'
      applyFormation(engine, name, false)
    end)
  end

  return #self.players > 0
end

function advance(self: GameEngine, seconds: number): boolean
  -- 1. Global Clear Handling
  if self.clearAll then
    for _, tool in pairs(self.tools) do
      tool:reset()
    end
    self.clearAll = false
    self.justCleared = true
    return true
  end

  if self.justCleared then
    self.justCleared = false
    return true
  end

  if not self.isInitialized then
    applyFormation(self, '4-4-2 (Box)', false)
    self.isInitialized = true
  end

  local C = Utils.CONSTANTS

  -- 2. Player Physics & State Updates
  for _, player in ipairs(self.players) do
    -- Reset drag target to hitbox (Engine Logic)
    player.targetX.value, player.targetY.value =
      player.hitboxX.value, player.hitboxY.value

    local curX, curY = player.posX.value, player.posY.value
    local tarX, tarY = player.targetX.value, player.targetY.value
    local moveSpeed = player.speed.value > 0 and player.speed.value or 5
    local dx, dy = tarX - curX, tarY - curY

    if
      math.abs(dx) > C.ARRIVAL_THRESHOLD or math.abs(dy) > C.ARRIVAL_THRESHOLD
    then
      player.isDragged.value = true
      local lerp = 1 - math.exp(-moveSpeed * seconds)
      player.posX.value = curX + (dx * lerp)
      player.posY.value = curY + (dy * lerp)
    else
      player.posX.value, player.posY.value = tarX, tarY
      player.isDragged.value = false
    end

    -- Update Heatmap Visual Weight (Lerp towards 1.0 if active, 0.0 if not)
    local targetWeight = player.isActive.value and 1.0 or 0.0
    if math.abs(player.visualWeight - targetWeight) > 0.01 then
      local weightLerp = 1 - math.exp(-C.HEAT_LERP_SPEED * seconds)
      player.visualWeight = player.visualWeight
        + (targetWeight - player.visualWeight) * weightLerp
    else
      player.visualWeight = targetWeight
    end
  end

  -- 3. Shape Logic
  if self.shape then
    Utils.updateShape(self.shape, self.players)
  end

  -- 4. Radar Animation
  if self.radarVM then
    local stats = Radar.calculateMetrics(self.players)
    local off = self.radarVM:getNumber('offence')
    local def = self.radarVM:getNumber('defence')
    local wid = self.radarVM:getNumber('width')
    local dep = self.radarVM:getNumber('depth')
    local com = self.radarVM:getNumber('compactness')
    local sym = self.radarVM:getNumber('symmetry')

    if off and def and wid and dep and com and sym then
      local l = 1 - math.exp(-10 * seconds)
      off.value = off.value + (stats.offence - off.value) * l
      def.value = def.value + (stats.defence - def.value) * l
      wid.value = wid.value + (stats.width - wid.value) * l
      dep.value = dep.value + (stats.depth - dep.value) * l
      com.value = com.value + (stats.compactness - com.value) * l
      sym.value = sym.value + (stats.symmetry - sym.value) * l
    end
  end

  return true
end

-- ======================================================================================
-- INPUT DELEGATION
-- ======================================================================================

function pointerDown(self: GameEngine, event: PointerEvent)
  -- FIX: Pass event.position FIRST, and the bounds table SECOND
  local bounds = {
    minX = self.minX,
    minY = self.minY,
    maxX = self.maxX,
    maxY = self.maxY,
  }

  if not Utils.isPointInBounds(event.position, bounds) then
    return
  end

  local tool = self.tools[self.activeToolIndex]
  if tool then
    tool:onDown(self, event.position)
  end
end

function pointerMove(self: GameEngine, event: PointerEvent)
  local tool = self.tools[self.activeToolIndex]
  if tool then
    tool:onMove(self, event.position)
  end
end

function pointerUp(self: GameEngine, event: PointerEvent)
  local tool = self.tools[self.activeToolIndex]
  if tool then
    tool:onUp(self, event.position)
  end
end

function draw(self: GameEngine, renderer: Renderer)
  -- Delegate drawing to active tool
  local tool = self.tools[self.activeToolIndex]
  if tool then
    tool:draw(self, renderer)
  end

  -- Note: The shape tool (Tool 4 in old code, now handled by UI)
  -- actually renders via ViewModels, not the Canvas,
  -- so we only calculate its logic in advance().
end

return function(): Node<GameEngine>
  return {
    players = {},
    shape = nil,
    context = nil,
    isInitialized = false,
    formationIndex = nil,
    radarVM = nil,
    hasBounds = false,
    minX = 0,
    minY = 0,
    maxX = 0,
    maxY = 0,
    activeToolIndex = 1,
    tools = {},
    clearAll = false,
    justCleared = false,
    init = init,
    advance = advance,
    draw = draw,
    pointerDown = pointerDown,
    pointerMove = pointerMove,
    pointerUp = pointerUp,
  }
end
