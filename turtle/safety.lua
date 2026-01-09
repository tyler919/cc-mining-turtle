-- Safety Module for Mining Turtle
-- Handles hazards: lava, water, gravel, bedrock, mobs

local safety = {}

-- Hazard blocks
local hazards = {
    lava = {
        ["minecraft:lava"] = true,
        ["minecraft:flowing_lava"] = true,
    },
    water = {
        ["minecraft:water"] = true,
        ["minecraft:flowing_water"] = true,
    },
    falling = {
        ["minecraft:gravel"] = true,
        ["minecraft:sand"] = true,
        ["minecraft:red_sand"] = true,
        ["minecraft:suspicious_sand"] = true,
        ["minecraft:suspicious_gravel"] = true,
    },
    bedrock = {
        ["minecraft:bedrock"] = true,
    },
}

-- Statistics
safety.stats = {
    lava_encounters = 0,
    water_encounters = 0,
    gravel_cleared = 0,
    mobs_attacked = 0,
}

-- Configuration
safety.config = {
    block_lava = true,      -- Place blocks to stop lava
    block_water = true,     -- Place blocks to stop water
    attack_mobs = true,     -- Attack hostile mobs
    avoid_bedrock = true,   -- Stop when hitting bedrock
}

-- Find block to place (cobblestone, dirt, etc.)
function safety.findFillerBlock()
    local fillers = {
        "minecraft:cobblestone",
        "minecraft:cobbled_deepslate",
        "minecraft:dirt",
        "minecraft:netherrack",
        "minecraft:stone",
    }

    for i = 1, 16 do
        local item = turtle.getItemDetail(i)
        if item then
            for _, filler in ipairs(fillers) do
                if item.name == filler then
                    return i
                end
            end
        end
    end
    return nil
end

-- Check if block is lava
function safety.isLava(blockData)
    if not blockData then return false end
    return hazards.lava[blockData.name] or false
end

-- Check if block is water
function safety.isWater(blockData)
    if not blockData then return false end
    return hazards.water[blockData.name] or false
end

-- Check if block is falling block
function safety.isFalling(blockData)
    if not blockData then return false end
    return hazards.falling[blockData.name] or false
end

-- Check if block is bedrock
function safety.isBedrock(blockData)
    if not blockData then return false end
    return hazards.bedrock[blockData.name] or false
end

-- Handle falling blocks (gravel/sand)
function safety.handleFalling(direction)
    local digFunc, detectFunc

    if direction == "up" then
        digFunc = turtle.digUp
        detectFunc = turtle.detectUp
    elseif direction == "down" then
        digFunc = turtle.digDown
        detectFunc = turtle.detectDown
    else
        digFunc = turtle.dig
        detectFunc = turtle.detect
    end

    local count = 0
    while detectFunc() do
        digFunc()
        count = count + 1
        sleep(0.4)  -- Wait for next block to fall

        if count > 64 then
            break  -- Safety limit
        end
    end

    if count > 1 then
        safety.stats.gravel_cleared = safety.stats.gravel_cleared + count
    end

    return count
end

-- Block fluid source
function safety.blockFluid(direction)
    local slot = safety.findFillerBlock()
    if not slot then return false end

    turtle.select(slot)

    if direction == "up" then
        turtle.placeUp()
    elseif direction == "down" then
        turtle.placeDown()
    else
        turtle.place()
    end

    turtle.select(1)
    return true
end

-- Check front for hazards
function safety.checkFront()
    local hasBlock, blockData = turtle.inspect()

    if not hasBlock then
        -- Try to attack if mob is there
        if safety.config.attack_mobs and turtle.attack() then
            safety.stats.mobs_attacked = safety.stats.mobs_attacked + 1
        end
        return "clear"
    end

    if safety.isBedrock(blockData) then
        return "bedrock"
    end

    if safety.isLava(blockData) then
        safety.stats.lava_encounters = safety.stats.lava_encounters + 1
        if safety.config.block_lava then
            safety.blockFluid("front")
        end
        return "lava"
    end

    if safety.isWater(blockData) then
        safety.stats.water_encounters = safety.stats.water_encounters + 1
        if safety.config.block_water then
            safety.blockFluid("front")
        end
        return "water"
    end

    if safety.isFalling(blockData) then
        safety.handleFalling("front")
        return "falling"
    end

    return "solid"
end

-- Check up for hazards
function safety.checkUp()
    local hasBlock, blockData = turtle.inspectUp()

    if not hasBlock then
        if safety.config.attack_mobs and turtle.attackUp() then
            safety.stats.mobs_attacked = safety.stats.mobs_attacked + 1
        end
        return "clear"
    end

    if safety.isBedrock(blockData) then
        return "bedrock"
    end

    if safety.isLava(blockData) then
        safety.stats.lava_encounters = safety.stats.lava_encounters + 1
        if safety.config.block_lava then
            safety.blockFluid("up")
        end
        return "lava"
    end

    if safety.isWater(blockData) then
        safety.stats.water_encounters = safety.stats.water_encounters + 1
        return "water"
    end

    if safety.isFalling(blockData) then
        safety.handleFalling("up")
        return "falling"
    end

    return "solid"
end

-- Check down for hazards
function safety.checkDown()
    local hasBlock, blockData = turtle.inspectDown()

    if not hasBlock then
        if safety.config.attack_mobs and turtle.attackDown() then
            safety.stats.mobs_attacked = safety.stats.mobs_attacked + 1
        end
        return "clear"
    end

    if safety.isBedrock(blockData) then
        return "bedrock"
    end

    if safety.isLava(blockData) then
        safety.stats.lava_encounters = safety.stats.lava_encounters + 1
        -- Don't block lava below usually, but record it
        return "lava"
    end

    if safety.isWater(blockData) then
        safety.stats.water_encounters = safety.stats.water_encounters + 1
        return "water"
    end

    return "solid"
end

-- Safe dig front (handles all hazards)
function safety.safeDig()
    local result = safety.checkFront()

    if result == "bedrock" then
        return false, "bedrock"
    end

    if result == "lava" then
        -- Lava blocked, now dig the filler
        turtle.dig()
        return true, "lava_blocked"
    end

    turtle.dig()
    return true, result
end

-- Safe dig up
function safety.safeDigUp()
    local result = safety.checkUp()

    if result == "bedrock" then
        return false, "bedrock"
    end

    if result == "lava" then
        turtle.digUp()
        return true, "lava_blocked"
    end

    if result == "falling" then
        -- Already handled by checkUp
        return true, "falling_cleared"
    end

    turtle.digUp()
    return true, result
end

-- Safe dig down
function safety.safeDigDown()
    local result = safety.checkDown()

    if result == "bedrock" then
        return false, "bedrock"
    end

    turtle.digDown()
    return true, result
end

-- Get safety stats
function safety.getStats()
    return {
        lava = safety.stats.lava_encounters,
        water = safety.stats.water_encounters,
        gravel = safety.stats.gravel_cleared,
        mobs = safety.stats.mobs_attacked,
    }
end

return safety
