-- Formation Engine: Physics Follower
-- Logic: Hitbox (Input Driver) -> Target (Memory) -> Visual (Chase)

-- Restoration of Type Definitions for robustness
type Coordinate = { number }
type FormationData = { Coordinate }

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
}

type FormationEngine = {
    players: { PlayerState },
    context: Context?,
    isInitialized: boolean,
}

local FORMATIONS: { [string]: FormationData } = {
    ['4-4-2'] = {
        { 13, 511.96 }, { 95, 361.96 }, { -68, 361.96 }, { -231, 298.96 },
        { 258, 298.96 }, { -105.5, 56.96 }, { 115.5, 56.96 }, { 192, -162.29 },
        { -186, -162.29 }, { 75.5, -490.54 }, { -73.5, -424.04 },
    },
    ['4-3-3'] = {
        { 13, 511.96 }, { 95, 361.96 }, { -68, 361.96 }, { -231, 298.96 },
        { 258, 298.96 }, { 13, 160 }, { -120, 25 }, { 146, 25 },
        { -240, -320 }, { 266, -320 }, { 13, -485 },
    },
}

local ARRIVAL_THRESHOLD = 0.1
local DEFAULT_SPEED = 5

local function applyFormation(self: FormationEngine, name: string, snapImmediately: boolean)
    local data = FORMATIONS[name]
    if not data then return end

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
    self.context = context
    self.players = {}
    self.isInitialized = false

    local mainVM = context:viewModel()
    if not mainVM then return false end

    -- Corrected Syntax: getList returns a PropertyList object
    local playersListProp = mainVM:getList('playersList')
    
    if playersListProp then
        -- Use .length property as required by Rive PropertyList class
        for i = 1, playersListProp.length do
            -- Access item by direct index
            local pVM = playersListProp[i] 

            if pVM then
                local pX = pVM:getNumber('posX')
                local pY = pVM:getNumber('posY')
                local tX = pVM:getNumber('targetX')
                local tY = pVM:getNumber('targetY')
                local hX = pVM:getNumber('hitboxX')
                local hY = pVM:getNumber('hitboxY')
                local spd = pVM:getNumber('speed')
                local drag = pVM:getBoolean('isDragged')

                if pX and pY and tX and tY and hX and hY and spd and drag then
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
                    })
                end
            end
        end
    end

    applyFormation(self, '4-4-2', true)

    local selector = mainVM:getNumber('formationIndex')
    if selector then
        selector:addListener(self, function(engine)
            local val = selector.value
            if val == 0 then
                applyFormation(engine, '4-4-2', false)
            elseif val == 1 then
                applyFormation(engine, '4-3-3', false)
            end
        end)
    end

    return #self.players > 0
end

function advance(self: FormationEngine, seconds: number): boolean
    if not self.isInitialized then
        applyFormation(self, '4-4-2', true)
        self.isInitialized = true
    end

    for _, player in ipairs(self.players) do
        player.targetX.value = player.hitboxX.value
        player.targetY.value = player.hitboxY.value

        local curX, curY = player.posX.value, player.posY.value
        local tarX, tarY = player.targetX.value, player.targetY.value
        
        local moveSpeed = player.speed.value
        if moveSpeed <= 0 then moveSpeed = DEFAULT_SPEED end

        local dx = tarX - curX
        local dy = tarY - curY

        if math.abs(dx) > ARRIVAL_THRESHOLD or math.abs(dy) > ARRIVAL_THRESHOLD then
            player.isDragged.value = true
            local lerpFactor = 1 - math.exp(-moveSpeed * seconds)
            player.posX.value = curX + (dx * lerpFactor)
            player.posY.value = curY + (dy * lerpFactor)
        else
            player.posX.value = tarX
            player.posY.value = tarY
            player.isDragged.value = false
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