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
}

-- State
net.connected = false
net.modemSide = nil
net.listeners = {}  -- Registered pocket computers

-- Find and open modem
function net.init()
    -- Find wireless modem
    local sides = {"left", "right", "top", "bottom", "front", "back"}
    for _, side in ipairs(sides) do
        if peripheral.getType(side) == "modem" then
            local modem = peripheral.wrap(side)
            if modem.isWireless() then
                net.modemSide = side
                rednet.open(side)
                net.connected = true
                print("[NET] Wireless modem found on " .. side)
                return true
            end
        end
    end

    print("[NET] No wireless modem found!")
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
    if not net.connected then return false end

    local message = {
        type = "status",
        turtle_id = net.config.turtle_id,
        turtle_name = net.config.turtle_name,
        timestamp = os.epoch("utc"),
        data = data,
    }

    rednet.broadcast(message, net.config.protocol)
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
        if message.type == "command" then
            return message
        elseif message.type == "register" then
            -- Pocket computer registering
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
    if not net.connected then return false end

    local message = {
        type = "presence",
        turtle_id = net.config.turtle_id,
        turtle_name = net.config.turtle_name,
        timestamp = os.epoch("utc"),
    }

    rednet.broadcast(message, net.config.protocol)
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
