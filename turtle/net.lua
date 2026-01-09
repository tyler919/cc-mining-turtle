-- Network Communication Module for Mining Turtle
-- Handles rednet communication with pocket computers and base stations

local net = {}

-- Configuration
net.config = {
    protocol = "MINING_NET",
    channel = 100,
    turtle_id = os.getComputerID(),
    turtle_name = os.getComputerLabel() or ("Turtle_" .. os.getComputerID()),
    broadcast_interval = 5,  -- Seconds between status broadcasts
    debug = true,  -- Enable debug logging
}

-- State
net.connected = false
net.modemSide = nil
net.listeners = {}  -- Registered pocket computers
net.messagesSent = 0
net.messagesReceived = 0

-- Other turtles (for collision avoidance)
net.otherTurtles = {}  -- {[id] = {pos={x,y,z}, facing=0, timestamp=0}}
net.collisionEnabled = true

-- Debug logging (file only - no screen output)
local function debugLog(message)
    if not net.config.debug then return end
    local timestamp = os.epoch("utc")
    local logLine = string.format("[%d] [NET] %s", timestamp, message)

    -- Write to file only (not screen)
    local f = fs.open("net_debug.log", "a")
    if f then
        f.writeLine(logLine)
        f.close()
    end
end

-- Find and open modem
function net.init()
    debugLog("Initializing network...")
    -- Find wireless modem
    local sides = {"left", "right", "top", "bottom", "front", "back"}
    for _, side in ipairs(sides) do
        local pType = peripheral.getType(side)
        debugLog("Checking side " .. side .. ": " .. tostring(pType))
        if pType == "modem" then
            local modem = peripheral.wrap(side)
            if modem.isWireless() then
                net.modemSide = side
                rednet.open(side)
                net.connected = true
                debugLog("SUCCESS: Wireless modem found on " .. side)
                debugLog("Turtle ID: " .. net.config.turtle_id)
                debugLog("Turtle Name: " .. net.config.turtle_name)
                debugLog("Protocol: " .. net.config.protocol)
                return true
            else
                debugLog("Modem on " .. side .. " is NOT wireless")
            end
        end
    end

    debugLog("FAILED: No wireless modem found!")
    return false
end

-- Close modem
function net.close()
    if net.modemSide then
        rednet.close(net.modemSide)
        net.connected = false
    end
end

-- Send status update to all listeners
function net.sendStatus(data)
    if not net.connected then
        debugLog("sendStatus: NOT CONNECTED, skipping")
        return false
    end

    local message = {
        type = "status",
        turtle_id = net.config.turtle_id,
        turtle_name = net.config.turtle_name,
        timestamp = os.epoch("utc"),
        data = data,
    }

    rednet.broadcast(message, net.config.protocol)
    net.messagesSent = net.messagesSent + 1
    debugLog("sendStatus: Broadcast #" .. net.messagesSent .. " sent (type=status)")
    return true
end

-- Send alert (high priority message)
function net.sendAlert(alertType, message, data)
    if not net.connected then return false end

    local alert = {
        type = "alert",
        alert_type = alertType,
        message = message,
        turtle_id = net.config.turtle_id,
        turtle_name = net.config.turtle_name,
        timestamp = os.epoch("utc"),
        data = data or {},
    }

    rednet.broadcast(alert, net.config.protocol)
    return true
end

-- Send mining stats
function net.sendStats(stats)
    if not net.connected then return false end

    local message = {
        type = "stats",
        turtle_id = net.config.turtle_id,
        turtle_name = net.config.turtle_name,
        timestamp = os.epoch("utc"),
        stats = stats,
    }

    rednet.broadcast(message, net.config.protocol)
    return true
end

-- Send position update
function net.sendPosition(pos, facing)
    if not net.connected then return false end

    local message = {
        type = "position",
        turtle_id = net.config.turtle_id,
        turtle_name = net.config.turtle_name,
        timestamp = os.epoch("utc"),
        position = pos,
        facing = facing,
    }

    rednet.broadcast(message, net.config.protocol)
    return true
end

-- Send inventory summary
function net.sendInventory(inventory)
    if not net.connected then return false end

    local message = {
        type = "inventory",
        turtle_id = net.config.turtle_id,
        turtle_name = net.config.turtle_name,
        timestamp = os.epoch("utc"),
        inventory = inventory,
    }

    rednet.broadcast(message, net.config.protocol)
    return true
end

-- Listen for commands (non-blocking check)
function net.checkCommands()
    if not net.connected then return nil end

    local senderId, message, protocol = rednet.receive(net.config.protocol, 0)

    if message and type(message) == "table" then
        net.messagesReceived = net.messagesReceived + 1
        debugLog("checkCommands: Received msg #" .. net.messagesReceived .. " from ID " .. tostring(senderId) .. " type=" .. tostring(message.type))

        if message.type == "command" then
            debugLog("checkCommands: Command received: " .. tostring(message.action))
            return message

        elseif message.type == "register" then
            -- Pocket computer registering
            debugLog("checkCommands: Pocket computer registering: " .. tostring(message.name))
            net.listeners[senderId] = {
                id = senderId,
                name = message.name or ("Pocket_" .. senderId),
                registered = os.epoch("utc"),
            }
            -- Send acknowledgment
            rednet.send(senderId, {
                type = "registered",
                turtle_id = net.config.turtle_id,
                turtle_name = net.config.turtle_name,
            }, net.config.protocol)
            debugLog("checkCommands: Sent registration ack to " .. tostring(senderId))

        elseif message.type == "turtle_position" then
            -- Another turtle broadcasting its position
            net.handleTurtlePosition(senderId, message)
        end
    end

    return nil
end

-- Process received command
function net.processCommand(command)
    if not command then return nil end

    local action = command.action

    if action == "stop" then
        return "stop"
    elseif action == "pause" then
        return "pause"
    elseif action == "resume" then
        return "resume"
    elseif action == "return_home" then
        return "return_home"
    elseif action == "refuel" then
        return "refuel"
    elseif action == "dump" then
        return "dump"
    elseif action == "status" then
        return "send_status"
    end

    return nil
end

-- Send response to a specific computer
function net.sendResponse(targetId, responseType, data)
    if not net.connected then return false end

    local response = {
        type = responseType,
        turtle_id = net.config.turtle_id,
        turtle_name = net.config.turtle_name,
        timestamp = os.epoch("utc"),
        data = data,
    }

    rednet.send(targetId, response, net.config.protocol)
    return true
end

-- Broadcast discovery message
function net.broadcastPresence()
    if not net.connected then
        debugLog("broadcastPresence: NOT CONNECTED, skipping")
        return false
    end

    local message = {
        type = "presence",
        turtle_id = net.config.turtle_id,
        turtle_name = net.config.turtle_name,
        timestamp = os.epoch("utc"),
    }

    rednet.broadcast(message, net.config.protocol)
    net.messagesSent = net.messagesSent + 1
    debugLog("broadcastPresence: Broadcast #" .. net.messagesSent .. " sent (I am " .. net.config.turtle_name .. " ID:" .. net.config.turtle_id .. ")")
    return true
end

-- Set turtle name
function net.setName(name)
    net.config.turtle_name = name
    os.setComputerLabel(name)
end

-- Get network stats
function net.getStats()
    return {
        connected = net.connected,
        modem_side = net.modemSide,
        turtle_id = net.config.turtle_id,
        turtle_name = net.config.turtle_name,
        listeners = net.listeners,
        other_turtles = net.otherTurtles,
    }
end

-- ============================================
-- TURTLE-TO-TURTLE COLLISION AVOIDANCE
-- ============================================

-- Broadcast my position to other turtles
function net.broadcastMyPosition(pos, facing)
    if not net.connected then return false end

    local message = {
        type = "turtle_position",
        turtle_id = net.config.turtle_id,
        turtle_name = net.config.turtle_name,
        pos = pos,
        facing = facing,
        timestamp = os.epoch("utc"),
    }

    rednet.broadcast(message, net.config.protocol)
    debugLog("Broadcast position: " .. pos.x .. "," .. pos.y .. "," .. pos.z)
    return true
end

-- Process incoming turtle position (called from checkCommands)
function net.handleTurtlePosition(senderId, message)
    if senderId == net.config.turtle_id then return end  -- Ignore self

    net.otherTurtles[senderId] = {
        id = senderId,
        name = message.turtle_name,
        pos = message.pos,
        facing = message.facing,
        timestamp = message.timestamp,
    }
    debugLog("Received position from turtle " .. senderId .. ": " ..
        message.pos.x .. "," .. message.pos.y .. "," .. message.pos.z)
end

-- Clean up old turtle positions (not heard from in 30 seconds)
function net.cleanupOldPositions()
    local now = os.epoch("utc")
    local timeout = 30000  -- 30 seconds

    for id, data in pairs(net.otherTurtles) do
        if now - data.timestamp > timeout then
            debugLog("Removing stale turtle " .. id)
            net.otherTurtles[id] = nil
        end
    end
end

-- Check if a position is occupied by another turtle
function net.isPositionOccupied(x, y, z)
    if not net.collisionEnabled then return false end

    net.cleanupOldPositions()

    for id, data in pairs(net.otherTurtles) do
        if data.pos and
           data.pos.x == x and
           data.pos.y == y and
           data.pos.z == z then
            debugLog("Position " .. x .. "," .. y .. "," .. z .. " occupied by turtle " .. id)
            return true, id
        end
    end
    return false, nil
end

-- Check if moving to a position would cause collision
-- Returns: safe (bool), blocking_turtle_id (or nil)
function net.checkMoveCollision(currentPos, facing, direction)
    if not net.collisionEnabled then return true, nil end

    local targetX, targetY, targetZ = currentPos.x, currentPos.y, currentPos.z

    -- Calculate target position based on direction
    if direction == "forward" then
        if facing == 0 then targetZ = targetZ - 1      -- North
        elseif facing == 1 then targetX = targetX + 1  -- East
        elseif facing == 2 then targetZ = targetZ + 1  -- South
        elseif facing == 3 then targetX = targetX - 1  -- West
        end
    elseif direction == "back" then
        if facing == 0 then targetZ = targetZ + 1
        elseif facing == 1 then targetX = targetX - 1
        elseif facing == 2 then targetZ = targetZ - 1
        elseif facing == 3 then targetX = targetX + 1
        end
    elseif direction == "up" then
        targetY = targetY + 1
    elseif direction == "down" then
        targetY = targetY - 1
    end

    local occupied, blockerId = net.isPositionOccupied(targetX, targetY, targetZ)
    return not occupied, blockerId
end

-- Wait for position to clear (with timeout)
function net.waitForClear(x, y, z, maxWait)
    maxWait = maxWait or 10  -- Default 10 seconds

    local startTime = os.epoch("utc")
    while os.epoch("utc") - startTime < maxWait * 1000 do
        -- Check for new position updates
        net.checkCommands()

        if not net.isPositionOccupied(x, y, z) then
            debugLog("Position " .. x .. "," .. y .. "," .. z .. " is now clear")
            return true
        end

        sleep(0.5 + math.random() * 0.5)  -- Random delay to prevent deadlock
    end

    debugLog("Timeout waiting for position " .. x .. "," .. y .. "," .. z)
    return false
end

return net
