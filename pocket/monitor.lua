-- Mining Turtle Monitor for Pocket Computer
-- Displays real-time stats and allows remote control

local PROTOCOL = "MINING_NET"
local VERSION = "1.3.2"

-- Debug configuration
local DEBUG = true
local debugLines = {}

-- State
local turtles = {}  -- Connected turtles
local turtleOrder = {}  -- Ordered list of turtle IDs for consistent selection
local selectedTurtle = nil
local running = true
local lastUpdate = 0
local messagesReceived = 0

-- Screen dimensions
local width, height = term.getSize()

-- Debug logging (file only - viewable with L key)
local function debugLog(message)
    if not DEBUG then return end
    local timestamp = os.epoch("utc")
    local logLine = string.format("[%d] %s", timestamp, message)
    table.insert(debugLines, logLine)
    -- Keep only last 100 lines in memory
    while #debugLines > 100 do
        table.remove(debugLines, 1)
    end
    -- Write to file (no screen output)
    local f = fs.open("monitor_debug.log", "a")
    if f then
        f.writeLine(logLine)
        f.close()
    end
end

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
    debugLog("Initializing modem...")
    local sides = {"left", "right", "top", "bottom", "front", "back"}
    for _, side in ipairs(sides) do
        local pType = peripheral.getType(side)
        debugLog("Checking side " .. side .. ": " .. tostring(pType))
        if pType == "modem" then
            rednet.open(side)
            debugLog("SUCCESS: Modem opened on " .. side)
            debugLog("My ID: " .. os.getComputerID())
            debugLog("Protocol: " .. PROTOCOL)
            return true
        end
    end
    debugLog("FAILED: No modem found")
    return false
end

-- Register with turtles
local function registerWithTurtles()
    debugLog("Broadcasting registration request...")
    rednet.broadcast({
        type = "register",
        name = os.getComputerLabel() or ("Pocket_" .. os.getComputerID()),
    }, PROTOCOL)
end

-- Add turtle to ordered list if not present
local function ensureTurtleOrder(id)
    for _, existingId in ipairs(turtleOrder) do
        if existingId == id then return end
    end
    table.insert(turtleOrder, id)
    debugLog("Added turtle ID " .. id .. " to order list (total: " .. #turtleOrder .. ")")
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
    term.write(" Monitor")

    -- Draw turtle count from ordered list
    local countStr = "[" .. #turtleOrder .. "]"
    term.setCursorPos(width - #countStr + 1, 1)
    term.write(countStr)
end

-- Draw turtle list (when no turtle selected)
local function drawTurtleList()
    setColor(colors.white, colors.black)
    term.setCursorPos(1, 2)
    term.write("Turtles:")

    local y = 3
    -- Use ordered list for consistent numbering
    for index, id in ipairs(turtleOrder) do
        if y > height - 1 then break end
        local turtle = turtles[id]
        if turtle then
            -- Status indicator first
            local age = os.epoch("utc") - (turtle.last_seen or 0)
            if age < 10000 then
                setColor(colors.lime, colors.black)
            elseif age < 30000 then
                setColor(colors.orange, colors.black)
            else
                setColor(colors.red, colors.black)
            end
            term.setCursorPos(1, y)
            term.write(tostring(index))

            setColor(colors.white, colors.black)
            term.write(".")

            local displayName = turtle.name or ("T" .. id)
            -- Truncate aggressively for small screen
            if #displayName > width - 3 then
                displayName = displayName:sub(1, width - 5) .. ".."
            end
            term.write(displayName)

            y = y + 1
        end
    end

    if #turtleOrder == 0 then
        setColor(colors.gray, colors.black)
        term.setCursorPos(1, 3)
        term.write("No turtles...")
        term.setCursorPos(1, 4)
        term.write("Waiting...")
        term.setCursorPos(1, 6)
        term.write("Msgs:" .. messagesReceived)
    end

    -- Compact instructions
    setColor(colors.gray, colors.black)
    term.setCursorPos(1, height)
    term.write("1-9:Sel R:Ref U:Upd")
end

-- Draw turtle details
local function drawTurtleDetails()
    local t = turtles[selectedTurtle.id]
    if not t then
        selectedTurtle = nil
        return
    end

    -- Compact name display
    setColor(colors.yellow, colors.black)
    term.setCursorPos(1, 2)
    local name = t.name or ("T" .. t.id)
    if #name > width - 4 then
        name = name:sub(1, width - 6) .. ".."
    end
    term.write(name)
    setColor(colors.gray, colors.black)
    term.write(" #" .. t.id)

    local y = 3

    -- Position (compact)
    if t.position then
        setColor(colors.lightBlue, colors.black)
        term.setCursorPos(1, y)
        term.write(string.format("X%d Y%d Z%d",
            t.position.x or 0,
            t.position.y or 0,
            t.position.z or 0))
        y = y + 1
    end

    -- Fuel (compact)
    if t.fuel then
        term.setCursorPos(1, y)
        local fuelPercent = t.fuel.percent or 0
        if fuelPercent < 20 then
            setColor(colors.red, colors.black)
        elseif fuelPercent < 50 then
            setColor(colors.yellow, colors.black)
        else
            setColor(colors.lime, colors.black)
        end
        term.write("F:" .. tostring(t.fuel.current or 0))
        setColor(colors.gray, colors.black)
        term.write("(" .. fuelPercent .. "%)")

        -- Coal count on same line if space
        if t.fuel.fuel_items and t.fuel.fuel_items > 0 then
            term.write(" C:" .. t.fuel.fuel_items)
        end
        y = y + 1
    end

    -- Inventory (compact)
    if t.inventory then
        term.setCursorPos(1, y)
        setColor(colors.purple, colors.black)
        local slots = 16 - (t.inventory.empty_slots or 16)
        term.write("Inv:" .. slots .. "/16")
        if t.inventory.full then
            setColor(colors.red, colors.black)
            term.write(" FULL")
        end
        y = y + 1
    end

    -- Mining stats (compact)
    if t.stats then
        setColor(colors.white, colors.black)
        term.setCursorPos(1, y)
        term.write("Mined:" .. formatNumber(t.stats.blocks_mined or 0))
        y = y + 1

        term.setCursorPos(1, y)
        term.write("Ores:" .. formatNumber(t.stats.ores_found or 0))
        if t.stats.layers_completed and t.stats.layers_completed > 0 then
            term.write(" L:" .. t.stats.layers_completed)
        end
        y = y + 1

        if t.stats.elapsed_time then
            term.setCursorPos(1, y)
            setColor(colors.gray, colors.black)
            term.write("Time:" .. formatTime(t.stats.elapsed_time))
            y = y + 1
        end
    end

    -- Status message (truncated)
    if t.message then
        setColor(colors.lightGray, colors.black)
        term.setCursorPos(1, y)
        local msg = t.message
        if #msg > width then
            msg = msg:sub(1, width - 2) .. ".."
        end
        term.write(msg)
        y = y + 1
    end

    -- Compact commands footer
    setColor(colors.gray, colors.black)
    term.setCursorPos(1, height - 1)
    term.write("S:Stop P:Pause H:Home")
    term.setCursorPos(1, height)
    term.write("B:Back R:Refresh")
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
    if type(message) ~= "table" then
        debugLog("Received non-table message from " .. tostring(senderId))
        return
    end

    messagesReceived = messagesReceived + 1
    local msgType = message.type
    debugLog("MSG #" .. messagesReceived .. " from ID:" .. tostring(senderId) .. " type:" .. tostring(msgType) .. " name:" .. tostring(message.turtle_name))

    if msgType == "status" or msgType == "presence" then
        -- Update turtle info
        local isNew = not turtles[senderId]
        if isNew then
            turtles[senderId] = {id = senderId}
            debugLog("NEW TURTLE DISCOVERED: ID " .. senderId)
        end
        ensureTurtleOrder(senderId)

        local t = turtles[senderId]
        t.name = message.turtle_name or t.name
        t.last_seen = os.epoch("utc")

        if message.data then
            t.position = message.data.pos
            t.fuel = message.data.fuel
            t.inventory = message.data.inv
            t.stats = message.data.stats
            t.message = message.data.message
            debugLog("Updated turtle " .. senderId .. " with status data")
        end

    elseif msgType == "stats" then
        if turtles[senderId] then
            turtles[senderId].stats = message.stats
            turtles[senderId].last_seen = os.epoch("utc")
            debugLog("Updated stats for turtle " .. senderId)
        else
            debugLog("Received stats from unknown turtle " .. senderId)
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
        if not turtles[senderId] then
            turtles[senderId] = {id = senderId}
            ensureTurtleOrder(senderId)
        end
        turtles[senderId].last_alert = message
        turtles[senderId].last_seen = os.epoch("utc")
        debugLog("ALERT from turtle " .. senderId .. ": " .. tostring(message.message))
        -- Flash alert on screen
        drawAlert(message)
        sleep(2)

    elseif msgType == "registered" then
        debugLog("Registration acknowledged by turtle " .. senderId .. " (" .. tostring(message.turtle_name) .. ")")
        if not turtles[senderId] then
            turtles[senderId] = {id = senderId, name = message.turtle_name}
            ensureTurtleOrder(senderId)
        end
    else
        debugLog("Unknown message type: " .. tostring(msgType))
    end
end

-- Handle key input
local function handleKey(key)
    if selectedTurtle then
        -- Commands for selected turtle
        if key == keys.b or key == keys.backspace then
            debugLog("Deselecting turtle")
            selectedTurtle = nil
        elseif key == keys.s then
            debugLog("Sending STOP command")
            sendCommand("stop")
        elseif key == keys.p then
            debugLog("Sending PAUSE command")
            sendCommand("pause")
        elseif key == keys.r then
            debugLog("Requesting status update")
            sendCommand("status")
        elseif key == keys.h then
            debugLog("Sending RETURN HOME command")
            sendCommand("return_home")
        elseif key == keys.d then
            debugLog("Sending DUMP command")
            sendCommand("dump")
        elseif key == keys.f then
            debugLog("Sending REFUEL command")
            sendCommand("refuel")
        end
    else
        -- Turtle selection using ordered list
        if key >= keys.one and key <= keys.nine then
            local index = key - keys.one + 1
            if index <= #turtleOrder then
                local id = turtleOrder[index]
                selectedTurtle = {id = id}
                debugLog("Selected turtle #" .. index .. " (ID: " .. id .. ")")
            else
                debugLog("No turtle at index " .. index .. " (have " .. #turtleOrder .. " turtles)")
            end
        elseif key == keys.r then
            debugLog("Manual refresh requested")
            registerWithTurtles()
        elseif key == keys.q then
            debugLog("Quit requested")
            running = false
        elseif key == keys.l then
            -- Debug: show log
            term.clear()
            term.setCursorPos(1, 1)
            print("=== DEBUG LOG ===")
            local startLine = math.max(1, #debugLines - height + 3)
            for i = startLine, #debugLines do
                print(debugLines[i]:sub(1, width))
            end
            print("Press any key...")
            os.pullEvent("key")
        elseif key == keys.u then
            -- Run updater
            debugLog("Running updater...")
            shell.run("update")
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
        local timer = os.startTimer(0.5)  -- Faster refresh for multi-turtle
        local shouldRedraw = false

        while true do
            local event, p1, p2, p3 = os.pullEvent()

            if event == "rednet_message" then
                local senderId, message, protocol = p1, p2, p3
                if protocol == PROTOCOL then
                    handleMessage(senderId, message)
                    shouldRedraw = true
                end
                -- Don't break - keep processing messages

            elseif event == "key" then
                handleKey(p1)
                break

            elseif event == "timer" and p1 == timer then
                break

            elseif event == "terminate" then
                running = false
                break
            end

            -- Redraw if we got new data
            if shouldRedraw then
                draw()
                shouldRedraw = false
            end
        end

        -- Periodic refresh request - more frequent
        if os.epoch("utc") - lastUpdate > 3000 then
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
