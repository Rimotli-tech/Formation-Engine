local Utils = {}

type SortablePoint = {
    x: number,
    y: number,
    angle: number
}

-- Calculates the centroid and sorts active players by polar angle
-- Directly updates the shape properties to keep the Engine clean
function Utils.updateShape(shapeState, players)
    if not shapeState then return end

    local activePoints = {}
    local avgX, avgY = 0, 0
    local count = 0
    local isMoving = false

    -- 1. Gather Active Points
    for _, player in ipairs(players) do
        if player.isActive and player.isActive.value == true then
            local px = player.posX.value
            local py = player.posY.value

            table.insert(activePoints, {
                x = px,
                y = py,
                angle = 0
            })

            avgX = avgX + px
            avgY = avgY + py
            count = count + 1

            if player.isDragged.value then
                isMoving = true
            end
        end
    end

    -- 2. Handle Drag State
    if isMoving then
        shapeState.isCommitted.value = false
    end

    -- 3. Visibility Check (Need at least 2 points)
    if count < 2 then
        shapeState.btnVis.value = 0
        shapeState.shapeVis.value = 0
        shapeState.isCommitted.value = false
        return
    end

    -- 4. Calculate Center
    local centerX = avgX / count
    local centerY = avgY / count
    shapeState.centerX.value = centerX
    shapeState.centerY.value = centerY
    shapeState.btnVis.value = 100
    shapeState.shapeVis.value = 100

    -- 5. Polar Sort
    for _, pt in ipairs(activePoints) do
        pt.angle = math.atan2(pt.y - centerY, pt.x - centerX)
    end

    table.sort(activePoints, function(a, b)
        return a.angle < b.angle
    end)

    -- 6. Assign Vertices (Fallback to previous point if not enough points)
    local p1 = activePoints[1] or {x = centerX, y = centerY}
    local p2 = activePoints[2] or p1
    local p3 = activePoints[3] or p2
    local p4 = activePoints[4] or p3

    shapeState.v1x.value = p1.x
    shapeState.v1y.value = p1.y
    shapeState.v2x.value = p2.x
    shapeState.v2y.value = p2.y
    shapeState.v3x.value = p3.x
    shapeState.v3y.value = p3.y
    shapeState.v4x.value = p4.x
    shapeState.v4y.value = p4.y
end

return Utils