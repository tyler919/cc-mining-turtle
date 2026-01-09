-- Mining Patterns Module for Mining Turtle
-- Implements various mining strategies

local mine = {}

-- Dependencies (set externally)
mine.nav = nil
mine.inv = nil
mine.fuel = nil
mine.safety = nil
mine.net = nil

-- Mining statistics
mine.stats = {
    blocks_mined = 0,
    ores_found = 0,
    layers_completed = 0,
    start_time = 0,
}

-- Configuration
mine.config = {
    width = 16,
    length = 16,
    depth = 64,
    torch_interval = 8,
    place_torches = true,
    trash_junk = true,
    vein_mine = true,  -- Follow ore veins
}

-- Home position
mine.home = {x = 0, y = 0, z = 0}

-- Ore blocks to follow when vein mining
local oreBlocks = {
    ["minecraft:coal_ore"] = true,
    ["minecraft:deepslate_coal_ore"] = true,
    ["minecraft:iron_ore"] = true,
    ["minecraft:deepslate_iron_ore"] = true,
    ["minecraft:copper_ore"] = true,
    ["minecraft:deepslate_copper_ore"] = true,
    ["minecraft:gold_ore"] = true,
    ["minecraft:deepslate_gold_ore"] = true,
    ["minecraft:redstone_ore"] = true,
    ["minecraft:deepslate_redstone_ore"] = true,
    ["minecraft:emerald_ore"] = true,
    ["minecraft:deepslate_emerald_ore"] = true,
    ["minecraft:lapis_ore"] = true,
    ["minecraft:deepslate_lapis_ore"] = true,
    ["minecraft:diamond_ore"] = true,
    ["minecraft:deepslate_diamond_ore"] = true,
    ["minecraft:nether_gold_ore"] = true,
    ["minecraft:nether_quartz_ore"] = true,
    ["minecraft:ancient_debris"] = true,
}

-- Initialize mining module
function mine.init(nav, inv, fuel, safety, net, config)
    mine.nav = nav
    mine.inv = inv
    mine.fuel = fuel
    mine.safety = safety
    mine.net = net

    if config then
        for k, v in pairs(config) do
            mine.config[k] = v
        end
    end

    mine.home = {x = nav.pos.x, y = nav.pos.y, z = nav.pos.z}
    mine.stats.start_time = os.epoch("utc")
end

-- Check if block is ore
function mine.isOre(blockData)
    if not blockData then return false end
    return oreBlocks[blockData.name] or false
end

-- Dig with safety checks
function mine.safeDig()
    if mine.safety then
        mine.safety.checkFront()
    end
    if turtle.dig() then
        mine.stats.blocks_mined = mine.stats.blocks_mined + 1
        return true
    end
    return false
end

function mine.safeDigUp()
    if mine.safety then
        mine.safety.checkUp()
    end
    if turtle.digUp() then
        mine.stats.blocks_mined = mine.stats.blocks_mined + 1
        return true
    end
    return false
end

function mine.safeDigDown()
    if mine.safety then
        mine.safety.checkDown()
    end
    if turtle.digDown() then
        mine.stats.blocks_mined = mine.stats.blocks_mined + 1
        return true
    end
    return false
end

-- Check block and follow ore vein if enabled
function mine.checkOre(direction)
    if not mine.config.vein_mine then return end

    local hasBlock, blockData

    if direction == "front" then
        hasBlock, blockData = turtle.inspect()
    elseif direction == "up" then
        hasBlock, blockData = turtle.inspectUp()
    elseif direction == "down" then
        hasBlock, blockData = turtle.inspectDown()
    end

    if hasBlock and mine.isOre(blockData) then
        mine.stats.ores_found = mine.stats.ores_found + 1
        return true
    end
    return false
end

-- Vein mine - recursively dig connected ore
function mine.veinMine(maxDepth)
    maxDepth = maxDepth or 20
    if maxDepth <= 0 then return end

    local directions = {
        {check = turtle.inspect, dig = mine.safeDig, move = mine.nav.forward, back = mine.nav.back},
        {check = turtle.inspectUp, dig = mine.safeDigUp, move = mine.nav.up, back = mine.nav.down},
        {check = turtle.inspectDown, dig = mine.safeDigDown, move = mine.nav.down, back = mine.nav.up},
    }

    -- Check all 6 directions (including turning)
    for turnCount = 0, 3 do
        local hasBlock, blockData = turtle.inspect()
        if hasBlock and mine.isOre(blockData) then
            mine.safeDig()
            if mine.nav.forward() then
                mine.stats.ores_found = mine.stats.ores_found + 1
                mine.veinMine(maxDepth - 1)
                mine.nav.back()
            end
        end
        if turnCount < 3 then mine.nav.turnRight() end
    end

    -- Check up
    local hasBlockUp, blockDataUp = turtle.inspectUp()
    if hasBlockUp and mine.isOre(blockDataUp) then
        mine.safeDigUp()
        if mine.nav.up() then
            mine.stats.ores_found = mine.stats.ores_found + 1
            mine.veinMine(maxDepth - 1)
            mine.nav.down()
        end
    end

    -- Check down
    local hasBlockDown, blockDataDown = turtle.inspectDown()
    if hasBlockDown and mine.isOre(blockDataDown) then
        mine.safeDigDown()
        if mine.nav.down() then
            mine.stats.ores_found = mine.stats.ores_found + 1
            mine.veinMine(maxDepth - 1)
            mine.nav.up()
        end
    end
end

-- Check for ores in all directions and vein mine them
function mine.checkAndVeinMine()
    if not mine.config.vein_mine then return end

    -- Check front
    local hasBlock, blockData = turtle.inspect()
    if hasBlock and mine.isOre(blockData) then
        mine.safeDig()
        if mine.nav.forward() then
            mine.veinMine()
            mine.nav.back()
        end
    end

    -- Check up
    hasBlock, blockData = turtle.inspectUp()
    if hasBlock and mine.isOre(blockData) then
        mine.safeDigUp()
        if mine.nav.up() then
            mine.veinMine()
            mine.nav.down()
        end
    end

    -- Check down
    hasBlock, blockData = turtle.inspectDown()
    if hasBlock and mine.isOre(blockData) then
        mine.safeDigDown()
        if mine.nav.down() then
            mine.veinMine()
            mine.nav.up()
        end
    end
end

-- Dig forward, checking for ores
function mine.digForward()
    mine.checkAndVeinMine()
    mine.safeDig()
    return mine.nav.forward()
end

-- Check inventory and return home if full
function mine.checkInventory()
    if mine.inv.isFull() then
        if mine.config.trash_junk then
            mine.inv.trashJunk()
        end

        if mine.inv.isFull() then
            return true  -- Need to return home
        end
    end
    return false
end

-- Check fuel and return home if low
function mine.checkFuel()
    mine.fuel.updateConsumption()

    if mine.fuel.isCritical() then
        return true  -- Need to return home NOW
    end

    if mine.fuel.needsRefuel() then
        mine.fuel.refuelFromInventory()
        if mine.fuel.needsRefuel() then
            return true  -- Need to return home for fuel
        end
    end

    return false
end

-- Return to home position
function mine.returnHome()
    local homeX, homeY, homeZ = mine.home.x, mine.home.y, mine.home.z
    return mine.nav.goTo(homeX, homeY, homeZ)
end

-- Place torch if needed
function mine.placeTorch(distance)
    if not mine.config.place_torches then return false end
    if distance % mine.config.torch_interval ~= 0 then return false end

    -- Find torch in inventory
    for i = 1, 16 do
        local item = turtle.getItemDetail(i)
        if item and item.name == "minecraft:torch" then
            turtle.select(i)
            turtle.placeDown()
            turtle.select(1)
            return true
        end
    end
    return false
end

-- Report status
function mine.reportStatus(message)
    if mine.net then
        mine.net.sendStatus({
            message = message,
            pos = mine.nav.pos,
            fuel = mine.fuel.getStats(),
            inv = {
                full = mine.inv.isFull(),
                empty_slots = mine.inv.emptySlots(),
            },
            stats = mine.stats,
        })
    end
    print(message)
end

--[[
    QUARRY MINING
    Digs a rectangular area down to bedrock or specified depth
]]
function mine.quarry(width, length, depth)
    width = width or mine.config.width
    length = length or mine.config.length
    depth = depth or mine.config.depth

    mine.reportStatus("Starting quarry: " .. width .. "x" .. length .. "x" .. depth)

    local startX, startY, startZ = mine.nav.getPos()
    local startFacing = mine.nav.facing

    local layer = 0
    local currentDepth = 0

    while currentDepth < depth do
        layer = layer + 1
        mine.reportStatus("Layer " .. layer .. " at Y=" .. (startY - currentDepth))

        -- Dig down to next layer
        mine.safeDigDown()
        if not mine.nav.down() then
            mine.reportStatus("Hit bedrock at layer " .. layer)
            break
        end
        currentDepth = currentDepth + 1

        -- Mine the layer in a serpentine pattern
        for row = 1, length do
            for col = 1, width - 1 do
                -- Check if we need to return home
                if mine.checkInventory() or mine.checkFuel() then
                    local returnX, returnY, returnZ = mine.nav.getPos()
                    local returnFacing = mine.nav.facing

                    mine.reportStatus("Returning home...")
                    mine.returnHome()
                    mine.nav.face(0)  -- Face chest

                    -- Dump items
                    mine.inv.dumpToChest()

                    -- Refuel
                    mine.nav.turnAround()
                    mine.fuel.refuelFromChest()
                    mine.nav.turnAround()

                    -- Return to mining position
                    mine.reportStatus("Returning to mine...")
                    mine.nav.goTo(returnX, returnY, returnZ)
                    mine.nav.face(returnFacing)
                end

                mine.digForward()
            end

            -- Move to next row (if not last row)
            if row < length then
                if row % 2 == 1 then
                    mine.nav.turnRight()
                    mine.digForward()
                    mine.nav.turnRight()
                else
                    mine.nav.turnLeft()
                    mine.digForward()
                    mine.nav.turnLeft()
                end
            end
        end

        -- Return to start of layer
        mine.nav.goTo(startX, mine.nav.pos.y, startZ)
        mine.nav.face(startFacing)

        mine.stats.layers_completed = mine.stats.layers_completed + 1
    end

    mine.reportStatus("Quarry complete! Returning home...")
    mine.returnHome()
    mine.nav.face(0)
    mine.inv.dumpToChest()

    return mine.stats
end

--[[
    STRIP MINING
    Digs a horizontal tunnel at the current Y level
]]
function mine.stripMine(length, tunnelCount, spacing)
    length = length or 50
    tunnelCount = tunnelCount or 1
    spacing = spacing or 3

    mine.reportStatus("Starting strip mine: " .. tunnelCount .. " tunnels, " .. length .. " blocks each")

    for tunnel = 1, tunnelCount do
        mine.reportStatus("Tunnel " .. tunnel .. "/" .. tunnelCount)

        -- Dig main tunnel
        for i = 1, length do
            -- Check status
            if mine.checkInventory() or mine.checkFuel() then
                mine.reportStatus("Returning home mid-tunnel...")
                mine.returnHome()
                mine.nav.face(0)
                mine.inv.dumpToChest()
                mine.nav.turnAround()
                mine.fuel.refuelFromChest()
                mine.reportStatus("TODO: Return to tunnel position")
                return mine.stats  -- For now, end mining
            end

            -- Dig forward and up (2 tall tunnel)
            mine.digForward()
            mine.safeDigUp()

            -- Check for ores on sides
            mine.nav.turnLeft()
            mine.checkAndVeinMine()
            mine.nav.turnAround()
            mine.checkAndVeinMine()
            mine.nav.turnLeft()

            -- Place torch
            mine.placeTorch(i)
        end

        -- Move to next tunnel position
        if tunnel < tunnelCount then
            mine.nav.turnRight()
            for i = 1, spacing do
                mine.digForward()
            end
            mine.nav.turnRight()
        end
    end

    mine.reportStatus("Strip mining complete!")
    mine.returnHome()
    mine.inv.dumpToChest()

    return mine.stats
end

--[[
    BRANCH MINING
    Creates a main tunnel with branches at intervals
]]
function mine.branchMine(mainLength, branchLength, branchSpacing)
    mainLength = mainLength or 100
    branchLength = branchLength or 10
    branchSpacing = branchSpacing or 3

    mine.reportStatus("Starting branch mine")

    local startFacing = mine.nav.facing

    for i = 1, mainLength do
        -- Dig main tunnel
        mine.digForward()
        mine.safeDigUp()

        -- Place torch in main tunnel
        mine.placeTorch(i)

        -- Create branch every branchSpacing blocks
        if i % branchSpacing == 0 then
            -- Left branch
            mine.nav.turnLeft()
            for b = 1, branchLength do
                mine.digForward()
                mine.safeDigUp()
                mine.checkAndVeinMine()
            end
            -- Return to main tunnel
            mine.nav.turnAround()
            for b = 1, branchLength do
                mine.nav.forward()
            end

            -- Right branch
            for b = 1, branchLength do
                mine.digForward()
                mine.safeDigUp()
                mine.checkAndVeinMine()
            end
            -- Return to main tunnel
            mine.nav.turnAround()
            for b = 1, branchLength do
                mine.nav.forward()
            end
            mine.nav.turnLeft()
        end

        -- Check if need to return home
        if mine.checkInventory() or mine.checkFuel() then
            local savedPos = {x = mine.nav.pos.x, y = mine.nav.pos.y, z = mine.nav.pos.z}
            mine.returnHome()
            mine.nav.face(0)
            mine.inv.dumpToChest()
            mine.nav.turnAround()
            mine.fuel.refuelFromChest()
            mine.nav.goTo(savedPos.x, savedPos.y, savedPos.z)
            mine.nav.face(startFacing)
        end
    end

    mine.reportStatus("Branch mining complete!")
    mine.returnHome()
    mine.inv.dumpToChest()

    return mine.stats
end

--[[
    VEIN MINING (Standalone)
    Searches for and mines ore veins in the area
]]
function mine.veinMineArea(radius, depth)
    radius = radius or 16
    depth = depth or 32

    mine.reportStatus("Starting vein mining in radius " .. radius)

    local startY = mine.nav.pos.y

    -- Spiral outward looking for ores
    for layer = 0, depth do
        if mine.nav.pos.y > startY - layer then
            mine.safeDigDown()
            mine.nav.down()
        end

        -- Check all directions for ores
        for turn = 1, 4 do
            local hasBlock, blockData = turtle.inspect()
            if hasBlock and mine.isOre(blockData) then
                mine.safeDig()
                mine.nav.forward()
                mine.veinMine(50)
                mine.nav.back()
            end
            mine.nav.turnRight()
        end

        -- Move in expanding squares
        -- (simplified - just move forward and check)
        for side = 1, 4 do
            for step = 1, layer + 1 do
                if mine.nav.forward() then
                    mine.checkAndVeinMine()
                end

                if mine.checkInventory() or mine.checkFuel() then
                    mine.returnHome()
                    mine.nav.face(0)
                    mine.inv.dumpToChest()
                    mine.nav.turnAround()
                    mine.fuel.refuelFromChest()
                end
            end
            mine.nav.turnRight()
        end
    end

    mine.returnHome()
    mine.inv.dumpToChest()

    return mine.stats
end

-- Get mining stats
function mine.getStats()
    local elapsed = os.epoch("utc") - mine.stats.start_time
    return {
        blocks_mined = mine.stats.blocks_mined,
        ores_found = mine.stats.ores_found,
        layers_completed = mine.stats.layers_completed,
        elapsed_time = elapsed,
        blocks_per_minute = mine.stats.blocks_mined / (elapsed / 60000),
    }
end

return mine
