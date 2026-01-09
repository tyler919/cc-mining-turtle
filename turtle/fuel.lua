-- Fuel Management Module for Mining Turtle
-- Handles refueling, fuel monitoring, and fuel-based decisions

local fuel = {}

-- Configuration
fuel.config = {
    reserve = 500,        -- Minimum fuel to keep
    critical = 100,       -- Emergency level - must return home
    refuelTarget = 5000,  -- Refuel up to this amount when refueling
}

-- Statistics
fuel.stats = {
    fuel_consumed = 0,
    refuel_count = 0,
    fuel_collected = 0,
}

-- Last known fuel level (for calculating consumption)
local lastFuelLevel = 0

-- Initialize fuel tracking
function fuel.init()
    lastFuelLevel = turtle.getFuelLevel()
    return lastFuelLevel
end

-- Get current fuel level
function fuel.getLevel()
    return turtle.getFuelLevel()
end

-- Get fuel limit
function fuel.getLimit()
    return turtle.getFuelLimit()
end

-- Get fuel percentage
function fuel.getPercent()
    local limit = turtle.getFuelLimit()
    if limit == "unlimited" then return 100 end
    return math.floor((turtle.getFuelLevel() / limit) * 100)
end

-- Check if fuel is low
function fuel.isLow()
    return turtle.getFuelLevel() < fuel.config.reserve
end

-- Check if fuel is critical
function fuel.isCritical()
    return turtle.getFuelLevel() < fuel.config.critical
end

-- Check if we have enough fuel to travel distance and return
function fuel.canTravel(distance)
    return turtle.getFuelLevel() >= (distance * 2) + fuel.config.reserve
end

-- Check if we need to refuel
function fuel.needsRefuel()
    return turtle.getFuelLevel() < fuel.config.reserve
end

-- Refuel from inventory
function fuel.refuelFromInventory(targetLevel)
    targetLevel = targetLevel or fuel.config.refuelTarget

    local startLevel = turtle.getFuelLevel()
    local refueled = 0

    for i = 1, 16 do
        if turtle.getFuelLevel() >= targetLevel then
            break
        end

        local item = turtle.getItemDetail(i)
        if item then
            turtle.select(i)
            if turtle.refuel(0) then  -- Test if item is fuel
                -- Refuel one at a time to not waste fuel
                while turtle.getFuelLevel() < targetLevel and turtle.getItemCount(i) > 0 do
                    turtle.refuel(1)
                end
            end
        end
    end

    refueled = turtle.getFuelLevel() - startLevel
    if refueled > 0 then
        fuel.stats.refuel_count = fuel.stats.refuel_count + 1
        fuel.stats.fuel_collected = fuel.stats.fuel_collected + refueled
    end

    turtle.select(1)
    return refueled
end

-- Refuel from chest in front
function fuel.refuelFromChest(targetLevel)
    targetLevel = targetLevel or fuel.config.refuelTarget

    local startLevel = turtle.getFuelLevel()

    -- Try to pull fuel items from chest
    for i = 1, 16 do
        if turtle.getFuelLevel() >= targetLevel then
            break
        end

        turtle.select(i)
        if turtle.suck() then  -- Pull item from chest
            if turtle.refuel(0) then  -- Check if it's fuel
                turtle.refuel()  -- Use all of it
            else
                turtle.drop()  -- Put non-fuel back
            end
        end
    end

    local refueled = turtle.getFuelLevel() - startLevel
    if refueled > 0 then
        fuel.stats.refuel_count = fuel.stats.refuel_count + 1
        fuel.stats.fuel_collected = fuel.stats.fuel_collected + refueled
    end

    turtle.select(1)
    return refueled
end

-- Estimate fuel needed to reach position
function fuel.estimateFuelNeeded(fromX, fromY, fromZ, toX, toY, toZ)
    local distance = math.abs(toX - fromX) + math.abs(toY - fromY) + math.abs(toZ - fromZ)
    return distance + 10  -- Add buffer for digging
end

-- Update consumption tracking
function fuel.updateConsumption()
    local currentLevel = turtle.getFuelLevel()
    local consumed = lastFuelLevel - currentLevel
    if consumed > 0 then
        fuel.stats.fuel_consumed = fuel.stats.fuel_consumed + consumed
    end
    lastFuelLevel = currentLevel
    return consumed
end

-- Get fuel status string
function fuel.getStatus()
    local level = turtle.getFuelLevel()
    local limit = turtle.getFuelLimit()

    if limit == "unlimited" then
        return "Unlimited"
    end

    local percent = fuel.getPercent()

    if fuel.isCritical() then
        return string.format("CRITICAL: %d/%d (%d%%)", level, limit, percent)
    elseif fuel.isLow() then
        return string.format("LOW: %d/%d (%d%%)", level, limit, percent)
    else
        return string.format("OK: %d/%d (%d%%)", level, limit, percent)
    end
end

-- Count fuel items in inventory (coal, charcoal, etc.)
function fuel.countFuelItems()
    local count = 0
    local fuelItems = {}

    for i = 1, 16 do
        local item = turtle.getItemDetail(i)
        if item then
            turtle.select(i)
            if turtle.refuel(0) then  -- Test if item is fuel
                count = count + turtle.getItemCount(i)
                fuelItems[item.name] = (fuelItems[item.name] or 0) + turtle.getItemCount(i)
            end
        end
    end
    turtle.select(1)

    return count, fuelItems
end

-- Get fuel stats
function fuel.getStats()
    local fuelItemCount, fuelItems = fuel.countFuelItems()

    return {
        current = turtle.getFuelLevel(),
        limit = turtle.getFuelLimit(),
        percent = fuel.getPercent(),
        consumed = fuel.stats.fuel_consumed,
        refuel_count = fuel.stats.refuel_count,
        collected = fuel.stats.fuel_collected,
        is_low = fuel.isLow(),
        is_critical = fuel.isCritical(),
        fuel_items = fuelItemCount,      -- Count of fuel items in inventory
        fuel_item_types = fuelItems,     -- Breakdown by type
    }
end

-- Set fuel reserve level
function fuel.setReserve(amount)
    fuel.config.reserve = amount
end

-- Set critical level
function fuel.setCritical(amount)
    fuel.config.critical = amount
end

return fuel
