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

-- Debug logging
local function debugLog(message)
    if not net.config.debug then return end
    local timestamp = os.epoch("utc")
    local logLine = string.format("[%d] [NET] %s", timestamp, message)
    print(logLine)

    -- Also write to file
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
    }
end

return net
