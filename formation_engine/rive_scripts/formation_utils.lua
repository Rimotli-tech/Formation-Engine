local Utils = {}

-- ======================================================================================
-- 1. SHARED CONSTANTS (Moved from Engine)
-- ======================================================================================
Utils.CONSTANTS = {
  -- Physics / Formations
  PLAYER_COUNT = 11,
  ARRIVAL_THRESHOLD = 0.1,
  PITCH_WIDTH = 433,
  PITCH_HEIGHT = 757,

  -- Visuals / Drawing
  ARROW_HEAD_LENGTH = 20,
  ARROW_HEAD_ANGLE = math.pi / 6,
  DOT_RADIUS = 4,
  DOT_SPACING = 4,
  MAX_DOTS = 30,
  DOT_FADE_START = 0.2,

  -- Heatmap
  HEAT_GRID_STEP = 4,
  HEAT_INFLUENCE_RADIUS = 150,
  HEAT_STRETCH_FACTOR = 0.45,
  HEAT_LERP_SPEED = 0.4,
}

-- ======================================================================================
-- 2. TYPE DEFINITIONS
-- ======================================================================================

export type Property<T> = { value: T }

-- Player & Shape Data
export type PlayerState = {
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
  visualWeight: number, -- For Heatmap calculation
}

export type ShapeState = {
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

-- Drawing Data (Moved from Engine to be shared)
export type Arrow = {
  startPos: Vector,
  endPos: Vector,
}

export type Dot = {
  position: Vector,
  opacity: number,
}

-- The Tool Contract
-- Every separate tool file we create next must follow this structure
export type ToolInterface = {
  id: number,
  init: (engine: any) -> (),
  onDown: (engine: any, pos: Vector) -> (),
  onMove: (engine: any, pos: Vector) -> (),
  onUp: (engine: any, pos: Vector) -> (),
  draw: (engine: any, renderer: Renderer) -> (),
  reset: (engine: any) -> (),
}

-- Helper for Sorting Shape Points
export type SortablePoint = {
  x: number,
  y: number,
  angle: number,
}

-- Add to formation_utils.lua
function Utils.isPointInBounds(
  pos: Vector,
  bounds: {
    minX: number,
    minY: number,
    maxX: number,
    maxY: number,
  }
): boolean
  return pos.x >= bounds.minX
    and pos.x <= bounds.maxX
    and pos.y >= bounds.minY
    and pos.y <= bounds.maxY
end

-- ======================================================================================
-- 3. LOGIC (Shape Calculation)
-- ======================================================================================

function Utils.updateShape(shapeState: ShapeState, players: { PlayerState })
  if not shapeState then
    return
  end

  local activePoints: { SortablePoint } = {}
  local avgX, avgY = 0, 0
  local count = 0
  local isMoving = false
  local VERTICAL_OFFSET = -30

  for _, player in ipairs(players) do
    if player.isActive and player.isActive.value == true then
      local px = player.posX.value
      local py = player.posY.value
      local correctedY = py + VERTICAL_OFFSET

      table.insert(activePoints, { x = px, y = correctedY, angle = 0 })
      avgX = avgX + px
      avgY = avgY + correctedY
      count = count + 1

      if player.isDragged.value then
        isMoving = true
      end
    end
  end

  if isMoving then
    shapeState.isCommitted.value = false
  end

  if count < 2 then
    shapeState.btnVis.value, shapeState.shapeVis.value = 0, 0
    shapeState.isCommitted.value = false
    return
  end

  local centerX = avgX / count
  local centerY = avgY / count

  for _, pt in ipairs(activePoints) do
    pt.angle = math.atan2(pt.y - centerY, pt.x - centerX)
  end

  table.sort(activePoints, function(a: SortablePoint, b: SortablePoint): boolean
    return (a.angle :: number) < (b.angle :: number)
  end)

  shapeState.centerX.value = centerX
  shapeState.centerY.value = centerY

  local p1 = activePoints[1] or { x = centerX, y = centerY }
  local p2 = activePoints[2] or p1
  local p3 = activePoints[3] or p2
  local p4 = activePoints[4] or p3

  shapeState.v1x.value, shapeState.v1y.value = p1.x, p1.y
  shapeState.v2x.value, shapeState.v2y.value = p2.x, p2.y
  shapeState.v3x.value, shapeState.v3y.value = p3.x, p3.y
  shapeState.v4x.value, shapeState.v4y.value = p4.x, p4.y

  shapeState.btnVis.value, shapeState.shapeVis.value = 100, 100
end

return Utils
