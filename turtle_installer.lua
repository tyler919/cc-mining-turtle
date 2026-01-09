-- Mining Turtle System - Self-Contained Installer
-- Paste this ONE file and run it to install everything

local VERSION = "1.0.0"

print("=================================")
print("  Mining Turtle System Installer")
print("  Version " .. VERSION)
print("=================================")
print("")

if not turtle then
    print("ERROR: Run this on a Mining Turtle!")
    return
end

print("Installing Mining Turtle System...")
print("")

-- ============================================
-- NAV.LUA
-- ============================================
local nav_code = [[
local nav = {}
nav.pos = {x = 0, y = 0, z = 0}
nav.facing = 0
local directions = {
    [0] = {x = 0, z = -1}, [1] = {x = 1, z = 0},
    [2] = {x = 0, z = 1}, [3] = {x = -1, z = 0}
}
local facingNames = {"North", "East", "South", "West"}
nav.stats = {blocks_moved = 0, turns = 0}

function nav.init(manualPos, manualFacing)
    if nav.tryGPS() then
        print("[NAV] GPS acquired")
    elseif manualPos then
        nav.pos = manualPos
        nav.facing = manualFacing or 0
    else
        nav.pos = {x = 0, y = 0, z = 0}
        nav.facing = 0
    end
    return nav.pos
end

function nav.tryGPS()
    local x, y, z = gps.locate(2)
    if x then
        nav.pos = {x = x, y = y, z = z}
        return true
    end
    return false
end

function nav.forward()
    local tries = 0
    while not turtle.forward() do
        if turtle.detect() then turtle.dig()
        elseif turtle.attack() then
        else sleep(0.5) end
        tries = tries + 1
        if tries > 30 then return false end
    end
    local dir = directions[nav.facing]
    nav.pos.x = nav.pos.x + dir.x
    nav.pos.z = nav.pos.z + dir.z
    nav.stats.blocks_moved = nav.stats.blocks_moved + 1
    return true
end

function nav.back()
    if turtle.back() then
        local dir = directions[nav.facing]
        nav.pos.x = nav.pos.x - dir.x
        nav.pos.z = nav.pos.z - dir.z
        nav.stats.blocks_moved = nav.stats.blocks_moved + 1
        return true
    end
    return false
end

function nav.up()
    local tries = 0
    while not turtle.up() do
        if turtle.detectUp() then turtle.digUp()
        elseif turtle.attackUp() then
        else sleep(0.5) end
        tries = tries + 1
        if tries > 30 then return false end
    end
    nav.pos.y = nav.pos.y + 1
    nav.stats.blocks_moved = nav.stats.blocks_moved + 1
    return true
end

function nav.down()
    local tries = 0
    while not turtle.down() do
        if turtle.detectDown() then turtle.digDown()
        elseif turtle.attackDown() then
        else sleep(0.5) end
        tries = tries + 1
        if tries > 30 then return false end
    end
    nav.pos.y = nav.pos.y - 1
    nav.stats.blocks_moved = nav.stats.blocks_moved + 1
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

function nav.face(dir)
    dir = dir % 4
    while nav.facing ~= dir do nav.turnRight() end
end

function nav.goTo(targetX, targetY, targetZ)
    while nav.pos.y < targetY do if not nav.up() then return false end end
    while nav.pos.y > targetY do if not nav.down() then return false end end
    if nav.pos.x < targetX then
        nav.face(1)
        while nav.pos.x < targetX do if not nav.forward() then return false end end
    elseif nav.pos.x > targetX then
        nav.face(3)
        while nav.pos.x > targetX do if not nav.forward() then return false end end
    end
    if nav.pos.z < targetZ then
        nav.face(2)
        while nav.pos.z < targetZ do if not nav.forward() then return false end end
    elseif nav.pos.z > targetZ then
        nav.face(0)
        while nav.pos.z > targetZ do if not nav.forward() then return false end end
    end
    return true
end

function nav.getPos() return nav.pos.x, nav.pos.y, nav.pos.z end
function nav.getFacingName() return facingNames[nav.facing + 1] end
function nav.distanceTo(x, y, z)
    return math.abs(x - nav.pos.x) + math.abs(y - nav.pos.y) + math.abs(z - nav.pos.z)
end

function nav.save()
    local f = fs.open("nav_state.dat", "w")
    f.write(textutils.serialize({pos = nav.pos, facing = nav.facing, stats = nav.stats}))
    f.close()
end

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
]]

-- ============================================
-- INV.LUA
-- ============================================
local inv_code = [[
local inv = {}
inv.junkItems = {
    ["minecraft:cobblestone"] = true, ["minecraft:dirt"] = true,
    ["minecraft:gravel"] = true, ["minecraft:sand"] = true,
    ["minecraft:netherrack"] = true, ["minecraft:cobbled_deepslate"] = true,
    ["minecraft:tuff"] = true, ["minecraft:granite"] = true,
    ["minecraft:diorite"] = true, ["minecraft:andesite"] = true,
    ["minecraft:stone"] = true, ["minecraft:deepslate"] = true,
}
inv.fuelItems = {
    ["minecraft:coal"] = 80, ["minecraft:charcoal"] = 80,
    ["minecraft:coal_block"] = 800, ["minecraft:lava_bucket"] = 1000,
}
inv.stats = {items_collected = 0, items_dumped = 0, junk_trashed = 0}

function inv.isFull()
    for i = 1, 16 do if turtle.getItemCount(i) == 0 then return false end end
    return true
end

function inv.emptySlots()
    local count = 0
    for i = 1, 16 do if turtle.getItemCount(i) == 0 then count = count + 1 end end
    return count
end

function inv.totalItems()
    local count = 0
    for i = 1, 16 do count = count + turtle.getItemCount(i) end
    return count
end

function inv.isJunk(itemName) return inv.junkItems[itemName] or false end
function inv.isFuel(itemName) return inv.fuelItems[itemName] ~= nil end

function inv.trashJunk()
    local trashed = 0
    for i = 1, 16 do
        local item = turtle.getItemDetail(i)
        if item and inv.isJunk(item.name) then
            turtle.select(i)
            trashed = trashed + turtle.getItemCount(i)
            turtle.drop()
        end
    end
    inv.stats.junk_trashed = inv.stats.junk_trashed + trashed
    turtle.select(1)
    return trashed
end

function inv.findFuel()
    for i = 1, 16 do
        local item = turtle.getItemDetail(i)
        if item and inv.isFuel(item.name) then return i, inv.fuelItems[item.name] or 0 end
    end
    return nil, 0
end

function inv.dumpToChest(keepFuel)
    keepFuel = keepFuel ~= false
    local dumped = 0
    for i = 1, 16 do
        local item = turtle.getItemDetail(i)
        if item then
            local shouldKeep = keepFuel and inv.isFuel(item.name)
            if not shouldKeep then
                turtle.select(i)
                local count = turtle.getItemCount(i)
                if turtle.drop() then dumped = dumped + count end
            end
        end
    end
    inv.stats.items_dumped = inv.stats.items_dumped + dumped
    turtle.select(1)
    return dumped
end

function inv.getSummary()
    local summary = {}
    for i = 1, 16 do
        local item = turtle.getItemDetail(i)
        if item then
            summary[item.name] = (summary[item.name] or 0) + item.count
        end
    end
    return summary
end

return inv
]]

-- ============================================
-- FUEL.LUA
-- ============================================
local fuel_code = [[
local fuel = {}
fuel.config = {reserve = 500, critical = 100, refuelTarget = 5000}
fuel.stats = {fuel_consumed = 0, refuel_count = 0}
local lastFuelLevel = 0

function fuel.init()
    lastFuelLevel = turtle.getFuelLevel()
    return lastFuelLevel
end

function fuel.getLevel() return turtle.getFuelLevel() end
function fuel.getLimit() return turtle.getFuelLimit() end

function fuel.getPercent()
    local limit = turtle.getFuelLimit()
    if limit == "unlimited" then return 100 end
    return math.floor((turtle.getFuelLevel() / limit) * 100)
end

function fuel.isLow() return turtle.getFuelLevel() < fuel.config.reserve end
function fuel.isCritical() return turtle.getFuelLevel() < fuel.config.critical end
function fuel.needsRefuel() return turtle.getFuelLevel() < fuel.config.reserve end

function fuel.refuelFromInventory(targetLevel)
    targetLevel = targetLevel or fuel.config.refuelTarget
    local startLevel = turtle.getFuelLevel()
    for i = 1, 16 do
        if turtle.getFuelLevel() >= targetLevel then break end
        local item = turtle.getItemDetail(i)
        if item then
            turtle.select(i)
            if turtle.refuel(0) then
                while turtle.getFuelLevel() < targetLevel and turtle.getItemCount(i) > 0 do
                    turtle.refuel(1)
                end
            end
        end
    end
    local refueled = turtle.getFuelLevel() - startLevel
    if refueled > 0 then fuel.stats.refuel_count = fuel.stats.refuel_count + 1 end
    turtle.select(1)
    return refueled
end

function fuel.refuelFromChest(targetLevel)
    targetLevel = targetLevel or fuel.config.refuelTarget
    local startLevel = turtle.getFuelLevel()
    for i = 1, 16 do
        if turtle.getFuelLevel() >= targetLevel then break end
        turtle.select(i)
        if turtle.suck() then
            if turtle.refuel(0) then turtle.refuel()
            else turtle.drop() end
        end
    end
    turtle.select(1)
    return turtle.getFuelLevel() - startLevel
end

function fuel.countFuelItems()
    local count = 0
    for i = 1, 16 do
        local item = turtle.getItemDetail(i)
        if item then
            turtle.select(i)
            if turtle.refuel(0) then count = count + turtle.getItemCount(i) end
        end
    end
    turtle.select(1)
    return count
end

function fuel.getStats()
    return {
        current = turtle.getFuelLevel(), limit = turtle.getFuelLimit(),
        percent = fuel.getPercent(), is_low = fuel.isLow(), is_critical = fuel.isCritical(),
        fuel_items = fuel.countFuelItems()
    }
end

function fuel.setReserve(amount) fuel.config.reserve = amount end
function fuel.setCritical(amount) fuel.config.critical = amount end

return fuel
]]

-- ============================================
-- SAFETY.LUA
-- ============================================
local safety_code = [[
local safety = {}
local hazards = {
    lava = {["minecraft:lava"] = true, ["minecraft:flowing_lava"] = true},
    water = {["minecraft:water"] = true, ["minecraft:flowing_water"] = true},
    falling = {["minecraft:gravel"] = true, ["minecraft:sand"] = true},
    bedrock = {["minecraft:bedrock"] = true},
}
safety.stats = {lava_encounters = 0, water_encounters = 0, gravel_cleared = 0, mobs_attacked = 0}
safety.config = {block_lava = true, block_water = true, attack_mobs = true}

function safety.isLava(b) return b and hazards.lava[b.name] or false end
function safety.isWater(b) return b and hazards.water[b.name] or false end
function safety.isFalling(b) return b and hazards.falling[b.name] or false end
function safety.isBedrock(b) return b and hazards.bedrock[b.name] or false end

function safety.findFillerBlock()
    local fillers = {"minecraft:cobblestone", "minecraft:dirt", "minecraft:netherrack"}
    for i = 1, 16 do
        local item = turtle.getItemDetail(i)
        if item then
            for _, f in ipairs(fillers) do if item.name == f then return i end end
        end
    end
    return nil
end

function safety.handleFalling(direction)
    local digFunc = direction == "up" and turtle.digUp or (direction == "down" and turtle.digDown or turtle.dig)
    local detectFunc = direction == "up" and turtle.detectUp or (direction == "down" and turtle.detectDown or turtle.detect)
    local count = 0
    while detectFunc() do
        digFunc()
        count = count + 1
        sleep(0.4)
        if count > 64 then break end
    end
    if count > 1 then safety.stats.gravel_cleared = safety.stats.gravel_cleared + count end
    return count
end

function safety.checkFront()
    local hasBlock, blockData = turtle.inspect()
    if not hasBlock then
        if safety.config.attack_mobs and turtle.attack() then
            safety.stats.mobs_attacked = safety.stats.mobs_attacked + 1
        end
        return "clear"
    end
    if safety.isBedrock(blockData) then return "bedrock" end
    if safety.isLava(blockData) then
        safety.stats.lava_encounters = safety.stats.lava_encounters + 1
        if safety.config.block_lava then
            local slot = safety.findFillerBlock()
            if slot then turtle.select(slot) turtle.place() turtle.select(1) end
        end
        return "lava"
    end
    if safety.isFalling(blockData) then safety.handleFalling("front") return "falling" end
    return "solid"
end

function safety.checkUp()
    local hasBlock, blockData = turtle.inspectUp()
    if not hasBlock then
        if safety.config.attack_mobs and turtle.attackUp() then
            safety.stats.mobs_attacked = safety.stats.mobs_attacked + 1
        end
        return "clear"
    end
    if safety.isBedrock(blockData) then return "bedrock" end
    if safety.isLava(blockData) then safety.stats.lava_encounters = safety.stats.lava_encounters + 1 return "lava" end
    if safety.isFalling(blockData) then safety.handleFalling("up") return "falling" end
    return "solid"
end

function safety.checkDown()
    local hasBlock, blockData = turtle.inspectDown()
    if not hasBlock then return "clear" end
    if safety.isBedrock(blockData) then return "bedrock" end
    if safety.isLava(blockData) then safety.stats.lava_encounters = safety.stats.lava_encounters + 1 return "lava" end
    return "solid"
end

function safety.getStats() return safety.stats end

return safety
]]

-- ============================================
-- NET.LUA
-- ============================================
local net_code = [[
local net = {}
net.config = {protocol = "MINING_NET", turtle_id = os.getComputerID(), turtle_name = os.getComputerLabel() or ("Turtle_" .. os.getComputerID())}
net.connected = false
net.modemSide = nil

function net.init()
    local sides = {"left", "right", "top", "bottom", "front", "back"}
    for _, side in ipairs(sides) do
        if peripheral.getType(side) == "modem" then
            local modem = peripheral.wrap(side)
            if modem.isWireless() then
                net.modemSide = side
                rednet.open(side)
                net.connected = true
                return true
            end
        end
    end
    return false
end

function net.close()
    if net.modemSide then rednet.close(net.modemSide) net.connected = false end
end

function net.sendStatus(data)
    if not net.connected then return false end
    rednet.broadcast({
        type = "status", turtle_id = net.config.turtle_id,
        turtle_name = net.config.turtle_name, timestamp = os.epoch("utc"), data = data
    }, net.config.protocol)
    return true
end

function net.sendAlert(alertType, message, data)
    if not net.connected then return false end
    rednet.broadcast({
        type = "alert", alert_type = alertType, message = message,
        turtle_id = net.config.turtle_id, turtle_name = net.config.turtle_name,
        timestamp = os.epoch("utc"), data = data or {}
    }, net.config.protocol)
    return true
end

function net.checkCommands()
    if not net.connected then return nil end
    local senderId, message, protocol = rednet.receive(net.config.protocol, 0)
    if message and type(message) == "table" and message.type == "command" then
        return message
    end
    return nil
end

function net.processCommand(command)
    if not command then return nil end
    local actions = {stop = "stop", pause = "pause", resume = "resume", return_home = "return_home", status = "send_status"}
    return actions[command.action]
end

function net.broadcastPresence()
    if not net.connected then return false end
    rednet.broadcast({type = "presence", turtle_id = net.config.turtle_id, turtle_name = net.config.turtle_name, timestamp = os.epoch("utc")}, net.config.protocol)
    return true
end

function net.setName(name) net.config.turtle_name = name os.setComputerLabel(name) end
function net.getStats() return {connected = net.connected, modem_side = net.modemSide, turtle_id = net.config.turtle_id, turtle_name = net.config.turtle_name} end

return net
]]

-- ============================================
-- Write files
-- ============================================
local files = {
    {name = "nav.lua", code = nav_code},
    {name = "inv.lua", code = inv_code},
    {name = "fuel.lua", code = fuel_code},
    {name = "safety.lua", code = safety_code},
    {name = "net.lua", code = net_code},
}

for _, file in ipairs(files) do
    write("  " .. file.name .. "... ")
    local f = fs.open(file.name, "w")
    f.write(file.code)
    f.close()
    print("OK")
end

-- Create mine.lua (simplified version for installer size)
write("  mine.lua... ")
local mine_file = fs.open("mine.lua", "w")
mine_file.write([[
local mine = {}
mine.nav = nil
mine.inv = nil
mine.fuel = nil
mine.safety = nil
mine.net = nil
mine.stats = {blocks_mined = 0, ores_found = 0, layers_completed = 0, start_time = 0}
mine.config = {width = 16, length = 16, depth = 64, torch_interval = 8, place_torches = true, trash_junk = true, vein_mine = true}
mine.home = {x = 0, y = 0, z = 0}

local oreBlocks = {
    ["minecraft:coal_ore"] = true, ["minecraft:iron_ore"] = true, ["minecraft:gold_ore"] = true,
    ["minecraft:diamond_ore"] = true, ["minecraft:emerald_ore"] = true, ["minecraft:redstone_ore"] = true,
    ["minecraft:lapis_ore"] = true, ["minecraft:copper_ore"] = true,
    ["minecraft:deepslate_coal_ore"] = true, ["minecraft:deepslate_iron_ore"] = true,
    ["minecraft:deepslate_gold_ore"] = true, ["minecraft:deepslate_diamond_ore"] = true,
}

function mine.init(nav, inv, fuel, safety, net, config)
    mine.nav = nav
    mine.inv = inv
    mine.fuel = fuel
    mine.safety = safety
    mine.net = net
    if config then for k, v in pairs(config) do mine.config[k] = v end end
    mine.home = {x = nav.pos.x, y = nav.pos.y, z = nav.pos.z}
    mine.stats.start_time = os.epoch("utc")
end

function mine.isOre(blockData)
    if not blockData then return false end
    return oreBlocks[blockData.name] or false
end

function mine.safeDig()
    if mine.safety then mine.safety.checkFront() end
    if turtle.dig() then mine.stats.blocks_mined = mine.stats.blocks_mined + 1 return true end
    return false
end

function mine.safeDigUp()
    if mine.safety then mine.safety.checkUp() end
    if turtle.digUp() then mine.stats.blocks_mined = mine.stats.blocks_mined + 1 return true end
    return false
end

function mine.safeDigDown()
    if mine.safety then mine.safety.checkDown() end
    if turtle.digDown() then mine.stats.blocks_mined = mine.stats.blocks_mined + 1 return true end
    return false
end

function mine.checkInventory()
    if mine.inv.isFull() then
        if mine.config.trash_junk then mine.inv.trashJunk() end
        if mine.inv.isFull() then return true end
    end
    return false
end

function mine.checkFuel()
    if mine.fuel.isCritical() then return true end
    if mine.fuel.needsRefuel() then
        mine.fuel.refuelFromInventory()
        if mine.fuel.needsRefuel() then return true end
    end
    return false
end

function mine.returnHome()
    return mine.nav.goTo(mine.home.x, mine.home.y, mine.home.z)
end

function mine.reportStatus(message)
    if mine.net then
        mine.net.sendStatus({message = message, pos = mine.nav.pos, fuel = mine.fuel.getStats(), stats = mine.stats})
    end
    print(message)
end

function mine.quarry(width, length, depth)
    width = width or mine.config.width
    length = length or mine.config.length
    depth = depth or mine.config.depth
    mine.reportStatus("Starting quarry: " .. width .. "x" .. length .. "x" .. depth)
    local startX, startY, startZ = mine.nav.getPos()
    local startFacing = mine.nav.facing
    local currentDepth = 0

    while currentDepth < depth do
        mine.reportStatus("Layer " .. (currentDepth + 1) .. " at Y=" .. (startY - currentDepth))
        mine.safeDigDown()
        if not mine.nav.down() then
            mine.reportStatus("Hit bedrock!")
            break
        end
        currentDepth = currentDepth + 1

        for row = 1, length do
            for col = 1, width - 1 do
                if mine.checkInventory() or mine.checkFuel() then
                    local rx, ry, rz = mine.nav.getPos()
                    local rf = mine.nav.facing
                    mine.reportStatus("Returning home...")
                    mine.returnHome()
                    mine.nav.face(0)
                    mine.inv.dumpToChest()
                    mine.nav.turnAround()
                    mine.fuel.refuelFromChest()
                    mine.nav.turnAround()
                    mine.reportStatus("Returning to mine...")
                    mine.nav.goTo(rx, ry, rz)
                    mine.nav.face(rf)
                end
                mine.safeDig()
                mine.nav.forward()
            end
            if row < length then
                if row % 2 == 1 then
                    mine.nav.turnRight()
                    mine.safeDig()
                    mine.nav.forward()
                    mine.nav.turnRight()
                else
                    mine.nav.turnLeft()
                    mine.safeDig()
                    mine.nav.forward()
                    mine.nav.turnLeft()
                end
            end
        end
        mine.nav.goTo(startX, mine.nav.pos.y, startZ)
        mine.nav.face(startFacing)
        mine.stats.layers_completed = mine.stats.layers_completed + 1
    end

    mine.reportStatus("Quarry complete!")
    mine.returnHome()
    mine.nav.face(0)
    mine.inv.dumpToChest()
    return mine.stats
end

function mine.stripMine(length)
    length = length or 50
    mine.reportStatus("Starting strip mine: " .. length .. " blocks")
    for i = 1, length do
        if mine.checkInventory() or mine.checkFuel() then
            mine.returnHome()
            mine.nav.face(0)
            mine.inv.dumpToChest()
            return mine.stats
        end
        mine.safeDig()
        mine.nav.forward()
        mine.safeDigUp()
    end
    mine.reportStatus("Strip mine complete!")
    mine.returnHome()
    mine.inv.dumpToChest()
    return mine.stats
end

function mine.getStats()
    local elapsed = os.epoch("utc") - mine.stats.start_time
    return {
        blocks_mined = mine.stats.blocks_mined,
        ores_found = mine.stats.ores_found,
        layers_completed = mine.stats.layers_completed,
        elapsed_time = elapsed
    }
end

return mine
]])
mine_file.close()
print("OK")

-- Create main.lua
write("  main.lua... ")
local main_file = fs.open("main.lua", "w")
main_file.write([[
local VERSION = "1.0.0"
local nav = require("nav")
local inv = require("inv")
local fuel = require("fuel")
local safety = require("safety")
local mine = require("mine")
local net = require("net")

local config = {mode = "quarry", width = 16, length = 16, depth = 64, use_network = true}
local running = true

local function showMenu()
    term.clear()
    term.setCursorPos(1, 1)
    print("=== Mining Turtle v" .. VERSION .. " ===")
    print("")
    print("1. Quarry (" .. config.width .. "x" .. config.length .. "x" .. config.depth .. ")")
    print("2. Strip Mine (50 blocks)")
    print("3. Configure")
    print("4. Test Systems")
    print("5. Exit")
    print("")
    print("Fuel: " .. turtle.getFuelLevel() .. "/" .. turtle.getFuelLimit())
    print("")
    write("Choice: ")
end

local function configMenu()
    while true do
        term.clear()
        term.setCursorPos(1, 1)
        print("=== Configuration ===")
        print("1. Width: " .. config.width)
        print("2. Length: " .. config.length)
        print("3. Depth: " .. config.depth)
        print("4. Network: " .. tostring(config.use_network))
        print("5. Back")
        write("Choice: ")
        local c = read()
        if c == "1" then write("Width: ") config.width = tonumber(read()) or config.width
        elseif c == "2" then write("Length: ") config.length = tonumber(read()) or config.length
        elseif c == "3" then write("Depth: ") config.depth = tonumber(read()) or config.depth
        elseif c == "4" then config.use_network = not config.use_network
        elseif c == "5" then break end
    end
end

local function testSystems()
    term.clear()
    term.setCursorPos(1, 1)
    print("=== System Test ===")
    local fuelLevel = turtle.getFuelLevel()
    print("Fuel: " .. fuelLevel .. "/" .. turtle.getFuelLimit())
    local fuelItems = fuel.countFuelItems and fuel.countFuelItems() or 0
    print("Fuel Items: " .. fuelItems .. " (coal/etc)")
    if fuelLevel == 0 then print("!! NO FUEL - Use 'refuel' !!") end
    print("Empty Slots: " .. inv.emptySlots())
    print("Position: " .. nav.pos.x .. ", " .. nav.pos.y .. ", " .. nav.pos.z)
    if config.use_network and net.init() then print("Network: Connected") else print("Network: Off") end
    local x, y, z = gps.locate(2)
    if x then print("GPS: " .. x .. ", " .. y .. ", " .. z)
    else print("GPS: Not available (using dead-reckoning)") end
    print("")
    print("Press any key...")
    os.pullEvent("key")
end

local function startMining(mode)
    term.clear()
    term.setCursorPos(1, 1)

    local fuelLevel = turtle.getFuelLevel()
    if fuelLevel == 0 then
        print("ERROR: No fuel!")
        print("")
        print("Put coal in inventory and run:")
        print("  refuel all")
        print("")
        print("Press any key...")
        os.pullEvent("key")
        return
    elseif fuelLevel < 100 then
        print("WARNING: Low fuel (" .. fuelLevel .. ")")
        print("Continue anyway? (y/n)")
        if read():lower() ~= "y" then return end
    end

    print("Starting " .. mode .. " mining...")
    print("Press Ctrl+T to stop")
    nav.init()
    fuel.init()
    if config.use_network then net.init() end
    mine.init(nav, inv, fuel, safety, net, config)

    if mode == "quarry" then mine.quarry(config.width, config.length, config.depth)
    elseif mode == "strip" then mine.stripMine(50) end

    print("")
    print("Mining complete!")
    local stats = mine.getStats()
    print("Blocks: " .. stats.blocks_mined)
    print("Layers: " .. stats.layers_completed)
    print("")
    print("Press any key...")
    os.pullEvent("key")
end

nav.init()
fuel.init()
if config.use_network then net.init() net.broadcastPresence() end

while running do
    showMenu()
    local choice = read()
    if choice == "1" then startMining("quarry")
    elseif choice == "2" then startMining("strip")
    elseif choice == "3" then configMenu()
    elseif choice == "4" then testSystems()
    elseif choice == "5" then running = false end
end

net.close()
term.clear()
term.setCursorPos(1, 1)
print("Goodbye!")
]])
main_file.close()
print("OK")

-- Create startup.lua
write("  startup.lua... ")
local startup_file = fs.open("startup.lua", "w")
startup_file.write([[
print("Mining Turtle System")
print("Loading...")
shell.run("main")
]])
startup_file.close()
print("OK")

print("")
print("=================================")
print("  Installation Complete!")
print("=================================")
print("")
print("Reboot to start: reboot")
print("")
print("Setup tip:")
print("  [Fuel Chest] - [TURTLE] - [Storage]")
print("")
