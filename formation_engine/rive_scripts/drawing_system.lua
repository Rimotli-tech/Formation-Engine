local Utils = require('formation_utils')
local DrawingSystem = {}

-- Constants shortcut
local C = Utils.CONSTANTS
local BEZIER_K = 0.552284749831

-- Define the return type explicitly to resolve the nil/table conflict
export type HeatmapPaths = {
  low: Path,
  med: Path,
  high: Path,
  hot: Path,
}

-- ==========================================
-- GEOMETRY HELPERS
-- ==========================================

local UNIT_CIRCLE_POINTS: { Vector } = {
  Vector.xy(1, 0),
  Vector.xy(1, BEZIER_K),
  Vector.xy(BEZIER_K, 1),
  Vector.xy(0, 1),
  Vector.xy(-BEZIER_K, 1),
  Vector.xy(-1, BEZIER_K),
  Vector.xy(-1, 0),
  Vector.xy(-1, -BEZIER_K),
  Vector.xy(-BEZIER_K, -1),
  Vector.xy(0, -1),
  Vector.xy(BEZIER_K, -1),
  Vector.xy(1, -BEZIER_K),
  Vector.xy(1, 0),
}

function DrawingSystem.addCircleToPath(
  path: Path,
  center: Vector,
  radius: number
)
  local function mapPoint(p: Vector): Vector
    return Vector.xy(p.x * radius + center.x, p.y * radius + center.y)
  end

  path:moveTo(mapPoint(UNIT_CIRCLE_POINTS[1]))
  for i = 1, 12, 3 do
    path:cubicTo(
      mapPoint(UNIT_CIRCLE_POINTS[i + 1]),
      mapPoint(UNIT_CIRCLE_POINTS[i + 2]),
      mapPoint(UNIT_CIRCLE_POINTS[i + 3])
    )
  end
  path:close()
end

function DrawingSystem.drawArrow(path: Path, startPos: Vector, endPos: Vector)
  path:moveTo(startPos)
  path:lineTo(endPos)

  local dx = endPos.x - startPos.x
  local dy = endPos.y - startPos.y
  local angle = math.atan2(dy, dx)

  local headAngle1 = angle + math.pi - C.ARROW_HEAD_ANGLE
  local headAngle2 = angle + math.pi + C.ARROW_HEAD_ANGLE

  local head1 = Vector.xy(
    endPos.x + C.ARROW_HEAD_LENGTH * math.cos(headAngle1),
    endPos.y + C.ARROW_HEAD_LENGTH * math.sin(headAngle1)
  )
  local head2 = Vector.xy(
    endPos.x + C.ARROW_HEAD_LENGTH * math.cos(headAngle2),
    endPos.y + C.ARROW_HEAD_LENGTH * math.sin(headAngle2)
  )

  path:moveTo(endPos)
  path:lineTo(head1)
  path:moveTo(endPos)
  path:lineTo(head2)
end

-- ==========================================
-- HEATMAP ALGORITHM
-- ==========================================

type HeatmapPlayer = {
  x: number,
  y: number,
  weight: number,
  isWide: boolean,
}

-- ADDED EXPLICIT RETURN TYPE ": HeatmapPaths?" HERE
function DrawingSystem.generateHeatmap(
  players: { Utils.PlayerState },
  bounds: any
): HeatmapPaths?
  if not bounds.hasBounds then
    return nil
  end

  local paths: HeatmapPaths = {
    low = Path.new(),
    med = Path.new(),
    high = Path.new(),
    hot = Path.new(),
  }

  local step = C.HEAT_GRID_STEP
  local bMinX, bMinY = bounds.minX, bounds.minY
  local width = bounds.maxX - bMinX
  local height = bounds.maxY - bMinY

  local activePlayers: { HeatmapPlayer } = {}
  for i, p in ipairs(players) do
    if p.visualWeight > 0.05 then
      local data: HeatmapPlayer = {
        x = p.posX.value,
        y = p.posY.value,
        weight = p.visualWeight,
        isWide = (i == 2 or i == 5 or i == 7 or i == 11),
      }
      table.insert(activePlayers :: { HeatmapPlayer }, data)
    end
  end

  if #activePlayers == 0 then
    return paths
  end

  for x = bMinX, bMinX + width, step do
    for y = bMinY, bMinY + height, step do
      local noiseX = math.sin(y * 0.05) * 15
      local noiseY = math.cos(x * 0.05) * 15
      local cellCenter = Vector.xy(x + step / 2 + noiseX, y + step / 2 + noiseY)
      local totalDensity = 0

      for _, p: HeatmapPlayer in ipairs(activePlayers :: { HeatmapPlayer }) do
        local dy = (p.y - cellCenter.y)
        if p.isWide then
          dy = dy * C.HEAT_STRETCH_FACTOR
        end

        local dx = p.x - cellCenter.x
        local sqDist = (dx * dx) + (dy * dy)
        local maxSq = C.HEAT_INFLUENCE_RADIUS * C.HEAT_INFLUENCE_RADIUS

        if sqDist < maxSq then
          local influence = (1 - (sqDist / maxSq))
          totalDensity = totalDensity + (influence * influence * p.weight)
        end
      end

      if totalDensity > 0.1 then
        local targetPath = paths.low
        if totalDensity > 0.85 then
          targetPath = paths.hot
        elseif totalDensity > 0.60 then
          targetPath = paths.high
        elseif totalDensity > 0.35 then
          targetPath = paths.med
        end

        targetPath:moveTo(Vector.xy(x, y))
        targetPath:lineTo(Vector.xy(x + step, y))
        targetPath:lineTo(Vector.xy(x + step, y + step))
        targetPath:lineTo(Vector.xy(x, y + step))
        targetPath:close()
      end
    end
  end

  return paths
end

return DrawingSystem
