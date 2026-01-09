-- Inventory Management Module for Mining Turtle
-- Handles sorting, filtering, dumping, and inventory tracking

local inv = {}

-- Junk items to trash/ignore
inv.junkItems = {
    ["minecraft:cobblestone"] = true,
    ["minecraft:dirt"] = true,
    ["minecraft:gravel"] = true,
    ["minecraft:sand"] = true,
    ["minecraft:netherrack"] = true,
    ["minecraft:cobbled_deepslate"] = true,
    ["minecraft:tuff"] = true,
    ["minecraft:granite"] = true,
    ["minecraft:diorite"] = true,
    ["minecraft:andesite"] = true,
    ["minecraft:stone"] = true,
    ["minecraft:deepslate"] = true,
}

-- Valuable items to prioritize keeping
inv.valuableItems = {
    ["minecraft:diamond"] = 100,
    ["minecraft:emerald"] = 90,
    ["minecraft:ancient_debris"] = 95,
    ["minecraft:diamond_ore"] = 100,
    ["minecraft:deepslate_diamond_ore"] = 100,
    ["minecraft:gold_ore"] = 70,
    ["minecraft:deepslate_gold_ore"] = 70,
    ["minecraft:gold_ingot"] = 70,
    ["minecraft:iron_ore"] = 50,
    ["minecraft:deepslate_iron_ore"] = 50,
    ["minecraft:raw_iron"] = 50,
    ["minecraft:raw_gold"] = 70,
    ["minecraft:raw_copper"] = 30,
    ["minecraft:lapis_lazuli"] = 40,
    ["minecraft:redstone"] = 35,
    ["minecraft:coal"] = 45,  -- Also fuel
    ["minecraft:copper_ore"] = 30,
    ["minecraft:deepslate_copper_ore"] = 30,
}

-- Fuel items (keep for refueling)
inv.fuelItems = {
    ["minecraft:coal"] = 80,
    ["minecraft:charcoal"] = 80,
    ["minecraft:coal_block"] = 800,
    ["minecraft:lava_bucket"] = 1000,
    ["minecraft:blaze_rod"] = 120,
    ["minecraft:stick"] = 5,
    ["minecraft:planks"] = 15,
    ["minecraft:log"] = 15,
}

-- Statistics
inv.stats = {
    items_collected = 0,
    items_dumped = 0,
    junk_trashed = 0,
}

-- Check if inventory is full
function inv.isFull()
    for i = 1, 16 do
        if turtle.getItemCount(i) == 0 then
            return false
        end
    end
    return true
end

-- Count empty slots
function inv.emptySlots()
    local count = 0
    for i = 1, 16 do
        if turtle.getItemCount(i) == 0 then
            count = count + 1
        end
    end
    return count
end

-- Get total item count
function inv.totalItems()
    local count = 0
    for i = 1, 16 do
        count = count + turtle.getItemCount(i)
    end
    return count
end

-- Check if an item is junk
function inv.isJunk(itemName)
    return inv.junkItems[itemName] or false
end

-- Check if an item is valuable
function inv.isValuable(itemName)
    return inv.valuableItems[itemName] ~= nil
end

-- Check if an item is fuel
function inv.isFuel(itemName)
    return inv.fuelItems[itemName] ~= nil
end

-- Get item value (for sorting)
function inv.getItemValue(itemName)
    if inv.valuableItems[itemName] then
        return inv.valuableItems[itemName]
    elseif inv.fuelItems[itemName] then
        return 25  -- Keep fuel but lower priority than valuables
    elseif inv.isJunk(itemName) then
        return 0
    else
        return 10  -- Unknown items have some value
    end
end

-- Trash all junk items
function inv.trashJunk()
    local trashed = 0
    for i = 1, 16 do
        local item = turtle.getItemDetail(i)
        if item and inv.isJunk(item.name) then
            turtle.select(i)
            trashed = trashed + turtle.getItemCount(i)
            turtle.drop()  -- Drop in front (or into lava if positioned)
        end
    end
    inv.stats.junk_trashed = inv.stats.junk_trashed + trashed
    turtle.select(1)
    return trashed
end

-- Find slot with specific item
function inv.findItem(itemName)
    for i = 1, 16 do
        local item = turtle.getItemDetail(i)
        if item and item.name == itemName then
            return i
        end
    end
    return nil
end

-- Find any fuel item
function inv.findFuel()
    for i = 1, 16 do
        local item = turtle.getItemDetail(i)
        if item and inv.isFuel(item.name) then
            return i, inv.fuelItems[item.name] or 0
        end
    end
    return nil, 0
end

-- Compact inventory (stack same items together)
function inv.compact()
    for i = 1, 16 do
        local item = turtle.getItemDetail(i)
        if item then
            turtle.select(i)
            for j = i + 1, 16 do
                local other = turtle.getItemDetail(j)
                if other and other.name == item.name then
                    turtle.select(j)
                    turtle.transferTo(i)
                end
            end
        end
    end
    turtle.select(1)
end

-- Dump inventory to chest in front
function inv.dumpToChest(keepFuel)
    keepFuel = keepFuel ~= false  -- Default true

    local dumped = 0
    for i = 1, 16 do
        local item = turtle.getItemDetail(i)
        if item then
            local shouldKeep = keepFuel and inv.isFuel(item.name)
            if not shouldKeep then
                turtle.select(i)
                local count = turtle.getItemCount(i)
                if turtle.drop() then
                    dumped = dumped + count
                end
            end
        end
    end

    inv.stats.items_dumped = inv.stats.items_dumped + dumped
    turtle.select(1)
    return dumped
end

-- Dump only junk to chest in front
function inv.dumpJunkToChest()
    local dumped = 0
    for i = 1, 16 do
        local item = turtle.getItemDetail(i)
        if item and inv.isJunk(item.name) then
            turtle.select(i)
            local count = turtle.getItemCount(i)
            if turtle.drop() then
                dumped = dumped + count
            end
        end
    end
    turtle.select(1)
    return dumped
end

-- Get inventory summary
function inv.getSummary()
    local summary = {}
    for i = 1, 16 do
        local item = turtle.getItemDetail(i)
        if item then
            if summary[item.name] then
                summary[item.name] = summary[item.name] + item.count
            else
                summary[item.name] = item.count
            end
        end
    end
    return summary
end

-- Get valuable items summary
function inv.getValuables()
    local valuables = {}
    local summary = inv.getSummary()
    for name, count in pairs(summary) do
        if inv.isValuable(name) then
            valuables[name] = count
        end
    end
    return valuables
end

-- Sort inventory by value (valuables first)
function inv.sort()
    -- Simple bubble sort by item value
    for i = 1, 15 do
        for j = i + 1, 16 do
            local itemI = turtle.getItemDetail(i)
            local itemJ = turtle.getItemDetail(j)

            local valueI = itemI and inv.getItemValue(itemI.name) or -1
            local valueJ = itemJ and inv.getItemValue(itemJ.name) or -1

            if valueJ > valueI then
                -- Swap slots
                turtle.select(i)
                local temp = turtle.getItemCount(i)
                if temp > 0 then
                    turtle.transferTo(16)  -- Use slot 16 as temp
                end
                turtle.select(j)
                turtle.transferTo(i)
                if temp > 0 then
                    turtle.select(16)
                    turtle.transferTo(j)
                end
            end
        end
    end
    turtle.select(1)
end

-- Check if can pick up more items
function inv.canPickUp()
    return inv.emptySlots() > 1
end

-- Record item collected
function inv.recordCollected(count)
    inv.stats.items_collected = inv.stats.items_collected + (count or 1)
end

-- Add custom junk item
function inv.addJunk(itemName)
    inv.junkItems[itemName] = true
end

-- Remove custom junk item
function inv.removeJunk(itemName)
    inv.junkItems[itemName] = nil
end

return inv
