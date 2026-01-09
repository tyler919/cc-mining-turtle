-- Mining Turtle Monitor for Pocket Computer
-- Displays real-time stats and allows remote control

local PROTOCOL = "MINING_NET"
local VERSION = "1.0.0"

-- State
local turtles = {}  -- Connected turtles
local selectedTurtle = nil
local running = true
local lastUpdate = 0

-- Screen dimensions
local width, height = term.getSize()

-- Colors
local colors_available = term.isColor()
local function setColor(fg, bg)
    if colors_available then
        if fg then term.setTextColor(fg) end
        if bg then term.setBackgroundColor(bg) end
    end
end

-- Initialize modem
local function initModem()
    local sides = {"left", "right", "top", "bottom", "front", "back"}
    for _, side in ipairs(sides) do
        if peripheral.getType(side) == "modem" then
            rednet.open(side)
            return true
        end
    end
    return false
end

-- Register with turtles
local function registerWithTurtles()
    rednet.broadcast({
        type = "register",
        name = os.getComputerLabel() or ("Pocket_" .. os.getComputerID()),
    }, PROTOCOL)
end

-- Send command to selected turtle
local function sendCommand(action, data)
    if not selectedTurtle then return false end

    rednet.send(selectedTurtle.id, {
        type = "command",
        action = action,
        data = data or {},
    }, PROTOCOL)
    return true
end

-- Format number with K/M suffix
local function formatNumber(n)
    if n >= 1000000 then
        return string.format("%.1fM", n / 1000000)
    elseif n >= 1000 then
        return string.format("%.1fK", n / 1000)
    else
        return tostring(n)
    end
end

-- Format time duration
local function formatTime(ms)
    local seconds = math.floor(ms / 1000)
    local minutes = math.floor(seconds / 60)
    local hours = math.floor(minutes / 60)

    if hours > 0 then
        return string.format("%dh %dm", hours, minutes % 60)
    elseif minutes > 0 then
        return string.format("%dm %ds", minutes, seconds % 60)
    else
        return string.format("%ds", seconds)
    end
end

-- Draw header
local function drawHeader()
    setColor(colors.white, colors.blue)
    term.setCursorPos(1, 1)
    term.clearLine()
    term.write(" Mining Monitor v" .. VERSION)

    -- Draw turtle count
    local count = 0
    for _ in pairs(turtles) do count = count + 1 end
    local countStr = " [" .. count .. "]"
    term.setCursorPos(width - #countStr + 1, 1)
    term.write(countStr)
end

-- Draw turtle list (when no turtle selected)
local function drawTurtleList()
    setColor(colors.white, colors.black)
    term.setCursorPos(1, 3)
    term.write("Select Turtle:")

    local y = 5
    local index = 1
    for id, turtle in pairs(turtles) do
        if y > height - 2 then break end

        setColor(colors.yellow, colors.black)
        term.setCursorPos(1, y)
        term.write(tostring(index) .. ". ")

        setColor(colors.white, colors.black)
        term.write(turtle.name or ("Turtle " .. id))

        -- Status indicator
        local age = os.epoch("utc") - (turtle.last_seen or 0)
        if age < 10000 then
            setColor(colors.lime, colors.black)
            term.write(" *")
        elseif age < 30000 then
            setColor(colors.orange, colors.black)
            term.write(" ~")
        else
            setColor(colors.red, colors.black)
            term.write(" ?")
        end

        y = y + 1
        index = index + 1
    end

    if index == 1 then
        setColor(colors.gray, colors.black)
        term.setCursorPos(1, 5)
        term.write("No turtles found...")
        term.setCursorPos(1, 7)
        term.write("Waiting for signal...")
    end

    -- Instructions
    setColor(colors.gray, colors.black)
    term.setCursorPos(1, height)
    term.write("[1-9] Select  [R] Refresh")
end

-- Draw turtle details
local function drawTurtleDetails()
    local t = turtles[selectedTurtle.id]
    if not t then
        selectedTurtle = nil
        return
    end

    -- Name and ID
    setColor(colors.yellow, colors.black)
    term.setCursorPos(1, 3)
    term.write(t.name or "Unknown")
    setColor(colors.gray, colors.black)
    term.write(" #" .. t.id)

    local y = 5

    -- Position
    if t.position then
        setColor(colors.lightBlue, colors.black)
        term.setCursorPos(1, y)
        term.write("Pos: ")
        setColor(colors.white, colors.black)
        term.write(string.format("%d, %d, %d",
            t.position.x or 0,
            t.position.y or 0,
            t.position.z or 0))
        y = y + 1
    end

    -- Fuel
    if t.fuel then
        setColor(colors.orange, colors.black)
        term.setCursorPos(1, y)
        term.write("Fuel: ")

        local fuelPercent = t.fuel.percent or 0
        if fuelPercent < 20 then
            setColor(colors.red, colors.black)
        elseif fuelPercent < 50 then
            setColor(colors.yellow, colors.black)
        else
            setColor(colors.lime, colors.black)
        end
        term.write(tostring(t.fuel.current or 0))
        setColor(colors.gray, colors.black)
        term.write(" (" .. fuelPercent .. "%)")
        y = y + 1

        -- Show fuel items in inventory
        if t.fuel.fuel_items and t.fuel.fuel_items > 0 then
            setColor(colors.orange, colors.black)
            term.setCursorPos(1, y)
            term.write("Coal: ")
            setColor(colors.white, colors.black)
            term.write(tostring(t.fuel.fuel_items) .. " items")
            y = y + 1
        end
    end

    -- Inventory
    if t.inventory then
        setColor(colors.purple, colors.black)
        term.setCursorPos(1, y)
        term.write("Inv: ")
        setColor(colors.white, colors.black)

        local slots = 16 - (t.inventory.empty_slots or 16)
        term.write(slots .. "/16 slots")
        if t.inventory.full then
            setColor(colors.red, colors.black)
            term.write(" FULL")
        end
        y = y + 1
    end

    -- Mining stats
    if t.stats then
        y = y + 1
        setColor(colors.cyan, colors.black)
        term.setCursorPos(1, y)
        term.write("--- Stats ---")
        y = y + 1

        setColor(colors.white, colors.black)
        term.setCursorPos(1, y)
        term.write("Mined: " .. formatNumber(t.stats.blocks_mined or 0))
        y = y + 1

        term.setCursorPos(1, y)
        term.write("Ores: " .. formatNumber(t.stats.ores_found or 0))
        y = y + 1

        if t.stats.elapsed_time then
            term.setCursorPos(1, y)
            term.write("Time: " .. formatTime(t.stats.elapsed_time))
            y = y + 1
        end

        if t.stats.layers_completed then
            term.setCursorPos(1, y)
            term.write("Layers: " .. t.stats.layers_completed)
            y = y + 1
        end
    end

    -- Status message
    if t.message then
        y = y + 1
        setColor(colors.lightGray, colors.black)
        term.setCursorPos(1, y)
        local msg = t.message
        if #msg > width then
            msg = msg:sub(1, width - 3) .. "..."
        end
        term.write(msg)
    end

    -- Commands footer
    setColor(colors.gray, colors.black)
    term.setCursorPos(1, height - 1)
    term.write("[S]top [P]ause [H]ome")
    term.setCursorPos(1, height)
    term.write("[B]ack [R]efresh")
end

-- Draw alerts
local function drawAlert(alert)
    setColor(colors.white, colors.red)
    term.setCursorPos(1, 2)
    term.clearLine()
    term.write(" ! " .. (alert.message or "Alert"))
end

-- Main draw function
local function draw()
    setColor(colors.white, colors.black)
    term.clear()
    drawHeader()

    if selectedTurtle then
        drawTurtleDetails()
    else
        drawTurtleList()
    end
end

-- Handle incoming messages
local function handleMessage(senderId, message)
    if type(message) ~= "table" then return end

    local msgType = message.type

    if msgType == "status" or msgType == "presence" then
        -- Update turtle info
        if not turtles[senderId] then
            turtles[senderId] = {id = senderId}
        end

        local t = turtles[senderId]
        t.name = message.turtle_name
        t.last_seen = os.epoch("utc")

        if message.data then
            t.position = message.data.pos
            t.fuel = message.data.fuel
            t.inventory = message.data.inv
            t.stats = message.data.stats
            t.message = message.data.message
        end

    elseif msgType == "stats" then
        if turtles[senderId] then
            turtles[senderId].stats = message.stats
            turtles[senderId].last_seen = os.epoch("utc")
        end

    elseif msgType == "position" then
        if turtles[senderId] then
            turtles[senderId].position = message.position
            turtles[senderId].facing = message.facing
            turtles[senderId].last_seen = os.epoch("utc")
        end

    elseif msgType == "inventory" then
        if turtles[senderId] then
            turtles[senderId].inventory = message.inventory
            turtles[senderId].last_seen = os.epoch("utc")
        end

    elseif msgType == "alert" then
        if turtles[senderId] then
            turtles[senderId].last_alert = message
            turtles[senderId].last_seen = os.epoch("utc")
        end
        -- Flash alert on screen
        drawAlert(message)
        sleep(2)
    end
end

-- Handle key input
local function handleKey(key)
    if selectedTurtle then
        -- Commands for selected turtle
        if key == keys.b or key == keys.backspace then
            selectedTurtle = nil
        elseif key == keys.s then
            sendCommand("stop")
        elseif key == keys.p then
            sendCommand("pause")
        elseif key == keys.r then
            sendCommand("status")
        elseif key == keys.h then
            sendCommand("return_home")
        elseif key == keys.d then
            sendCommand("dump")
        elseif key == keys.f then
            sendCommand("refuel")
        end
    else
        -- Turtle selection
        if key >= keys.one and key <= keys.nine then
            local index = key - keys.one + 1
            local i = 1
            for id, turtle in pairs(turtles) do
                if i == index then
                    selectedTurtle = {id = id}
                    break
                end
                i = i + 1
            end
        elseif key == keys.r then
            registerWithTurtles()
        elseif key == keys.q then
            running = false
        end
    end
end

-- Main loop
local function main()
    -- Initialize
    if not initModem() then
        print("No modem found!")
        print("Attach a wireless modem")
        return
    end

    print("Mining Turtle Monitor")
    print("Searching for turtles...")

    registerWithTurtles()

    -- Main loop
    while running do
        draw()

        -- Wait for event with timeout
        local timer = os.startTimer(1)

        while true do
            local event, p1, p2, p3 = os.pullEvent()

            if event == "rednet_message" then
                local senderId, message, protocol = p1, p2, p3
                if protocol == PROTOCOL then
                    handleMessage(senderId, message)
                end

            elseif event == "key" then
                handleKey(p1)
                break

            elseif event == "timer" and p1 == timer then
                break

            elseif event == "terminate" then
                running = false
                break
            end
        end

        -- Periodic refresh request
        if os.epoch("utc") - lastUpdate > 5000 then
            registerWithTurtles()
            lastUpdate = os.epoch("utc")
        end
    end

    -- Cleanup
    term.clear()
    term.setCursorPos(1, 1)
    print("Monitor closed.")
end

-- Run
main()
