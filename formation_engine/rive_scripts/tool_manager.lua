local Drawing = require('drawing_system')
local Utils = require('formation_utils')
local Manager = {}

local C = Utils.CONSTANTS

-- ==========================================
-- 1. TYPE DEFINITIONS
-- ==========================================

type MinimalEngine = {
  players: { Utils.PlayerState },
  hasBounds: boolean,
  minX: number,
  minY: number,
  maxX: number,
  maxY: number,
}

export type Tool = {
  id: number,
  onDown: (self: any, engine: MinimalEngine, pos: Vector) -> (),
  onMove: (self: any, engine: MinimalEngine, pos: Vector) -> (),
  onUp: (self: any, engine: MinimalEngine, pos: Vector) -> (),
  draw: (self: any, engine: MinimalEngine, renderer: Renderer) -> (),
  reset: (self: any) -> (),
}

type Arrow = Utils.Arrow
type Dot = Utils.Dot

-- ==========================================
-- 2. TOOL FACTORIES
-- ==========================================

-- --- TOOL 1: ARROWS ---
function Manager.createArrowTool(): Tool
  local tool = {
    id = 1,
    arrows = {} :: { Arrow },
    currentStart = nil :: Vector?,
    currentEnd = nil :: Vector?,
    path = Path.new(),
    paint = Paint.with({
      style = 'stroke',
      thickness = 8,
      color = Color.rgb(255, 255, 255),
      cap = 'round',
      join = 'round',
    }),
  }

  function tool:onDown(engine: MinimalEngine, pos: Vector)
    self.currentStart = pos
    self.currentEnd = pos
  end

  function tool:onMove(engine: MinimalEngine, pos: Vector)
    if self.currentStart then
      self.currentEnd = pos
    end
  end

  function tool:onUp(engine: MinimalEngine, pos: Vector)
    local s, e = self.currentStart, self.currentEnd
    if s and e then
      -- Fix: Force the inserted table to match the Arrow type
      table.insert(self.arrows, { startPos = s, endPos = e } :: Arrow)
    end
    self.currentStart = nil
    self.currentEnd = nil
  end
  --WHAT LINE IS THIS
  function tool:draw(engine: MinimalEngine, renderer: Renderer)
    self.path:reset()
    -- Fix [image_24a50f]: Cast self.arrows inside the loop
    for _, arrow: Arrow in ipairs(self.arrows :: { Arrow }) do
      Drawing.drawArrow(self.path, arrow.startPos, arrow.endPos)
    end

    local s, e = self.currentStart, self.currentEnd
    if s and e then
      Drawing.drawArrow(self.path, s, e)
    end
    renderer:drawPath(self.path, self.paint)
  end

  function tool:reset()
    self.arrows = {} :: { Arrow }
    self.path:reset()
  end

  return (tool :: any) :: Tool
end

-- --- TOOL 2: DOT TRAILS ---
function Manager.createDotTool(): Tool
  local tool = {
    id = 2,
    dots = {} :: { Dot },
    paint = Paint.with({ style = 'fill', color = Color.rgb(218, 165, 32) }),
  }
  --WHAT LINE IS THIS
  function tool:onDown(e, p) end
  function tool:onMove(e, p) end
  function tool:onUp(e, p) end

  function tool:draw(engine: MinimalEngine, renderer: Renderer)
    for _, p in ipairs(engine.players) do
      if p.isActive.value and p.isDragged.value then
        local pos = Vector.xy(p.posX.value, p.posY.value)
        local canAdd = true
        if #self.dots > 0 then
          local last = self.dots[#self.dots] :: Dot
          if pos:distance(last.position) < C.DOT_SPACING then
            canAdd = false
          end
        end
        if canAdd then
          if #self.dots >= C.MAX_DOTS then
            table.remove(self.dots :: { Dot }, 1)
          end
          -- Casting the first argument ensures V is inferred as Dot
          table.insert(
            self.dots :: { Dot },
            { position = pos, opacity = 1 } :: Dot
          )
        end
      end
    end

    local count = #self.dots
    for i, d: Dot in ipairs(self.dots :: { Dot }) do
      local t = (i - 1) / math.max(count - 1, 1)
      d.opacity = C.DOT_FADE_START + t * (1 - C.DOT_FADE_START)

      local path = Path.new()
      Drawing.addCircleToPath(path, d.position, C.DOT_RADIUS)
      renderer:drawPath(
        path,
        self.paint:copy({
          color = Color.opacity(self.paint.color, d.opacity),
        })
      )
    end
  end

  function tool:reset()
    self.dots = {} :: { Dot }
  end
  return (tool :: any) :: Tool
end

-- --- TOOL 3: CONNECTED LINES ---
function Manager.createLineTool(): Tool
  local tool = {
    id = 3,
    selectionOrder = {} :: { number },
    path = Path.new(),
    paint = Paint.with({
      style = 'stroke',
      thickness = 8,
      color = Color.rgb(0, 255, 255),
      cap = 'round',
      join = 'round',
    }),
  }

  function tool:onDown(e, p) end
  function tool:onMove(e, p) end
  function tool:onUp(e, p) end

  function tool:draw(engine: MinimalEngine, renderer: Renderer)
    -- Fix [image_2443b5 & 24433e]: Inline cast self.selectionOrder
    for i, p in ipairs(engine.players) do
      if p.isActive.value then
        local known = false
        for _, idx: number in ipairs(self.selectionOrder :: { number }) do
          if idx == i then
            known = true
            break -- Moved to new line to satisfy statement separator rules
          end
        end

        if not known then
          table.insert(self.selectionOrder :: { number }, i)
        end
      else
        for k, idx: number in ipairs(self.selectionOrder :: { number }) do
          if idx == i then
            table.remove(self.selectionOrder, k)
            break
          end
        end
      end
    end

    self.path:reset()
    local points = {} :: { Vector }
    for _, idx: number in ipairs(self.selectionOrder :: { number }) do
      local p = engine.players[idx]
      if p then
        table.insert(points, Vector.xy(p.posX.value, p.posY.value))
      end
    end

    if #points > 0 then
      for _, pt in ipairs(points) do
        Drawing.addCircleToPath(self.path, pt, C.DOT_RADIUS)
      end
      if #points >= 2 then
        self.path:moveTo(points[1])
        for i = 2, #points do
          self.path:lineTo(points[i])
        end
      end
      renderer:drawPath(self.path, self.paint)
    end
  end

  function tool:reset()
    self.selectionOrder = {} :: { number }
    self.path:reset()
  end

  return (tool :: any) :: Tool
end

-- --- TOOL 4: HEATMAP ---
function Manager.createHeatmapTool(): Tool
  local tool = {
    id = 4,
    paint = Paint.with({ style = 'fill' }),
  }

  function tool:onDown(e, p) end
  function tool:onMove(e, p) end
  function tool:onUp(e, p) end

  function tool:draw(engine: MinimalEngine, renderer: Renderer)
    local bounds = {
      hasBounds = engine.hasBounds,
      minX = engine.minX,
      minY = engine.minY,
      maxX = engine.maxX,
      maxY = engine.maxY,
    }
    local paths = Drawing.generateHeatmap(engine.players, bounds)

    -- Fix: Satisfy nil-check for return paths
    if paths ~= nil then
      renderer:drawPath(
        paths.low,
        self.paint:copy({ color = Color.opacity(Color.rgb(50, 255, 50), 0.3) })
      )
      renderer:drawPath(
        paths.med,
        self.paint:copy({ color = Color.opacity(Color.rgb(255, 230, 0), 0.5) })
      )
      renderer:drawPath(
        paths.high,
        self.paint:copy({ color = Color.opacity(Color.rgb(255, 120, 0), 0.7) })
      )
      renderer:drawPath(
        paths.hot,
        self.paint:copy({ color = Color.opacity(Color.rgb(255, 0, 0), 0.85) })
      )
    end
  end

  function tool:reset() end
  return (tool :: any) :: Tool
end

-- ==========================================
-- 3. MANAGER FACTORY
-- ==========================================

function Manager.createTools(): { [number]: Tool }
  return {
    [1] = Manager.createArrowTool(),
    [2] = Manager.createDotTool(),
    [3] = Manager.createLineTool(),
    [4] = Manager.createHeatmapTool(),
  }
end

return Manager
