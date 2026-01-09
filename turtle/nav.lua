-- Navigation Module for Mining Turtle
-- Handles GPS, dead reckoning, movement, and collision avoidance

local nav = {}

-- Position and facing
nav.pos = {x = 0, y = 0, z = 0}
nav.facing = 0  -- 0=north(-z), 1=east(+x), 2=south(+z), 3=west(-x)

-- Direction vectors
local directions = {
    [0] = {x = 0, z = -1},  -- North
    [1] = {x = 1, z = 0},   -- East
    [2] = {x = 0, z = 1},   -- South
    [3] = {x = -1, z = 0}   -- West
}

local facingNames = {"North", "East", "South", "West"}

-- Statistics
nav.stats = {
    blocks_moved = 0,
    turns = 0,
    collision_waits = 0
}

-- Network module reference (set by main)
nav.net = nil

-- Set network module for collision avoidance
function nav.setNet(netModule)
    nav.net = netModule
end

-- Broadcast position after moving
local function broadcastPosition()
    if nav.net and nav.net.broadcastMyPosition then
        nav.net.broadcastMyPosition(nav.pos, nav.facing)
    end
end

-- Check collision before moving
local function checkCollision(direction)
    if not nav.net or not nav.net.checkMoveCollision then
        return true, nil  -- No net module, assume safe
    end
    return nav.net.checkMoveCollision(nav.pos, nav.facing, direction)
end

-- Wait for collision to clear
local function waitForCollisionClear(direction)
    if not nav.net then return true end

    local targetX, targetY, targetZ = nav.pos.x, nav.pos.y, nav.pos.z
    local dir = directions[nav.facing]

    if direction == "forward" then
        targetX = targetX + dir.x
        targetZ = targetZ + dir.z
    elseif direction == "back" then
        targetX = targetX - dir.x
        targetZ = targetZ - dir.z
    elseif direction == "up" then
        targetY = targetY + 1
    elseif direction == "down" then
        targetY = targetY - 1
    end

    return nav.net.waitForClear(targetX, targetY, targetZ, 10)
end

-- Initialize position (try GPS first, fallback to manual)
function nav.init(manualPos, manualFacing)
    if nav.tryGPS() then
        print("[NAV] GPS position acquired")
    elseif manualPos then
        nav.pos = manualPos
        nav.facing = manualFacing or 0
        print("[NAV] Using manual position")
    else
        nav.pos = {x = 0, y = 0, z = 0}
        nav.facing = 0
        print("[NAV] Using origin (0,0,0)")
    end
    return nav.pos
end

-- Try to get GPS coordinates
function nav.tryGPS()
    local x, y, z = gps.locate(2)
    if x then
        nav.pos = {x = x, y = y, z = z}
        -- Try to determine facing by moving
        nav.determineFacing()
        return true
    end
    return false
end

-- Determine facing direction using GPS
function nav.determineFacing()
    local startX, startY, startZ = gps.locate(2)
    if not startX then return false end

    -- Try to move forward
    if turtle.forward() then
        local newX, newY, newZ = gps.locate(2)
        if newX then
            local dx = newX - startX
            local dz = newZ - startZ

            if dz == -1 then nav.facing = 0      -- North
            elseif dx == 1 then nav.facing = 1   -- East
            elseif dz == 1 then nav.facing = 2   -- South
            elseif dx == -1 then nav.facing = 3  -- West
            end
        end
        turtle.back()
    end
    return true
end

-- Movement functions with position tracking and collision avoidance
function nav.forward()
    -- Check for turtle collision first
    local safe, blockerId = checkCollision("forward")
    if not safe then
        nav.stats.collision_waits = nav.stats.collision_waits + 1
        if not waitForCollisionClear("forward") then
            return false  -- Timeout waiting for other turtle
        end
    end

    local tries = 0
    while not turtle.forward() do
        if turtle.detect() then
            turtle.dig()
        elseif turtle.attack() then
            -- Attacked a mob
        else
            sleep(0.5)
        end
        tries = tries + 1
        if tries > 30 then return false end
    end

    -- Update position
    local dir = directions[nav.facing]
    nav.pos.x = nav.pos.x + dir.x
    nav.pos.z = nav.pos.z + dir.z
    nav.stats.blocks_moved = nav.stats.blocks_moved + 1

    -- Broadcast new position to other turtles
    broadcastPosition()
    return true
end

function nav.back()
    -- Check for turtle collision first
    local safe, blockerId = checkCollision("back")
    if not safe then
        nav.stats.collision_waits = nav.stats.collision_waits + 1
        if not waitForCollisionClear("back") then
            return false
        end
    end

    if turtle.back() then
        local dir = directions[nav.facing]
        nav.pos.x = nav.pos.x - dir.x
        nav.pos.z = nav.pos.z - dir.z
        nav.stats.blocks_moved = nav.stats.blocks_moved + 1
        broadcastPosition()
        return true
    end
    return false
end

function nav.up()
    -- Check for turtle collision first
    local safe, blockerId = checkCollision("up")
    if not safe then
        nav.stats.collision_waits = nav.stats.collision_waits + 1
        if not waitForCollisionClear("up") then
            return false
        end
    end

    local tries = 0
    while not turtle.up() do
        if turtle.detectUp() then
            turtle.digUp()
        elseif turtle.attackUp() then
            -- Attacked mob above
        else
            sleep(0.5)
        end
        tries = tries + 1
        if tries > 30 then return false end
    end

    nav.pos.y = nav.pos.y + 1
    nav.stats.blocks_moved = nav.stats.blocks_moved + 1
    broadcastPosition()
    return true
end

function nav.down()
    -- Check for turtle collision first
    local safe, blockerId = checkCollision("down")
    if not safe then
        nav.stats.collision_waits = nav.stats.collision_waits + 1
        if not waitForCollisionClear("down") then
            return false
        end
    end

    local tries = 0
    while not turtle.down() do
        if turtle.detectDown() then
            turtle.digDown()
        elseif turtle.attackDown() then
            -- Attacked mob below
        else
            sleep(0.5)
        end
        tries = tries + 1
        if tries > 30 then return false end
    end

    nav.pos.y = nav.pos.y - 1
    nav.stats.blocks_moved = nav.stats.blocks_moved + 1
    broadcastPosition()
    return true
end

function nav.turnLeft()
    turtle.turnLeft()
    nav.facing = (nav.facing - 1) % 4
    nav.stats.turns = nav.stats.turns + 1
end

function nav.turnRight()
    turtle.turnRight()
    nav.facing = (nav.facing + 1) % 4
    nav.stats.turns = nav.stats.turns + 1
end

function nav.turnAround()
    nav.turnRight()
    nav.turnRight()
end

-- Face a specific direction (0-3)
function nav.face(dir)
    dir = dir % 4
    while nav.facing ~= dir do
        nav.turnRight()
    end
end

-- Face towards a coordinate
function nav.faceTowards(x, z)
    local dx = x - nav.pos.x
    local dz = z - nav.pos.z

    if math.abs(dx) > math.abs(dz) then
        if dx > 0 then nav.face(1)  -- East
        else nav.face(3) end        -- West
    else
        if dz > 0 then nav.face(2)  -- South
        else nav.face(0) end        -- North
    end
end

-- Go to specific coordinates
function nav.goTo(targetX, targetY, targetZ)
    -- Move Y first (up/down)
    while nav.pos.y < targetY do
        if not nav.up() then return false end
    end
    while nav.pos.y > targetY do
        if not nav.down() then return false end
    end

    -- Move X
    if nav.pos.x < targetX then
        nav.face(1)  -- East
        while nav.pos.x < targetX do
            if not nav.forward() then return false end
        end
    elseif nav.pos.x > targetX then
        nav.face(3)  -- West
        while nav.pos.x > targetX do
            if not nav.forward() then return false end
        end
    end

    -- Move Z
    if nav.pos.z < targetZ then
        nav.face(2)  -- South
        while nav.pos.z < targetZ do
            if not nav.forward() then return false end
        end
    elseif nav.pos.z > targetZ then
        nav.face(0)  -- North
        while nav.pos.z > targetZ do
            if not nav.forward() then return false end
        end
    end

    return true
end

-- Calculate distance to a point
function nav.distanceTo(x, y, z)
    return math.abs(x - nav.pos.x) + math.abs(y - nav.pos.y) + math.abs(z - nav.pos.z)
end

-- Get current position
function nav.getPos()
    return nav.pos.x, nav.pos.y, nav.pos.z
end

-- Get facing name
function nav.getFacingName()
    return facingNames[nav.facing + 1]
end

-- Save position to file
function nav.save()
    local f = fs.open("nav_state.dat", "w")
    f.write(textutils.serialize({
        pos = nav.pos,
        facing = nav.facing,
        stats = nav.stats
    }))
    f.close()
end

-- Load position from file
function nav.load()
    if fs.exists("nav_state.dat") then
        local f = fs.open("nav_state.dat", "r")
        local data = textutils.unserialize(f.readAll())
        f.close()
        if data then
            nav.pos = data.pos or nav.pos
            nav.facing = data.facing or nav.facing
            nav.stats = data.stats or nav.stats
            return true
        end
    end
    return false
end

return nav
