-- Mining Turtle - Main Controller
-- Full-featured mining system with remote monitoring

local VERSION = "1.0.0"

-- Load modules
local nav = require("nav")
local inv = require("inv")
local fuel = require("fuel")
local safety = require("safety")
local mine = require("mine")
local net = require("net")

-- Configuration
local config = {
    -- Mining settings
    mode = "quarry",        -- quarry, strip, branch, vein
    width = 16,
    length = 16,
    depth = 64,

    -- Features
    torch_interval = 8,
    place_torches = true,
    trash_junk = true,
    vein_mine = true,

    -- Fuel
    fuel_reserve = 500,
    fuel_critical = 100,

    -- Network
    use_network = true,
    broadcast_interval = 5,
}

-- State
local running = true
local paused = false
local miningTask = nil

-- Load config from file
local function loadConfig()
    if fs.exists("mining_config.lua") then
        local f = fs.open("mining_config.lua", "r")
        local data = textutils.unserialize(f.readAll())
        f.close()
        if data then
            for k, v in pairs(data) do
                config[k] = v
            end
        end
        print("[CONFIG] Loaded from file")
    end
end

-- Save config to file
local function saveConfig()
    local f = fs.open("mining_config.lua", "w")
    f.write(textutils.serialize(config))
    f.close()
end

-- Display menu
local function showMenu()
    term.clear()
    term.setCursorPos(1, 1)

    print("=== Mining Turtle v" .. VERSION .. " ===")
    print("")
    print("Select mining mode:")
    print("")
    print("1. Quarry (" .. config.width .. "x" .. config.length .. "x" .. config.depth .. ")")
    print("2. Strip Mine")
    print("3. Branch Mine")
    print("4. Vein Mine")
    print("")
    print("5. Configure")
    print("6. Test Systems")
    print("7. Exit")
    print("")
    print("Fuel: " .. turtle.getFuelLevel() .. "/" .. turtle.getFuelLimit())
    print("")
    write("Choice: ")
end

-- Configuration menu
local function configMenu()
    while true do
        term.clear()
        term.setCursorPos(1, 1)

        print("=== Configuration ===")
        print("")
        print("1. Width: " .. config.width)
        print("2. Length: " .. config.length)
        print("3. Depth: " .. config.depth)
        print("4. Torch interval: " .. config.torch_interval)
        print("5. Place torches: " .. tostring(config.place_torches))
        print("6. Trash junk: " .. tostring(config.trash_junk))
        print("7. Vein mine: " .. tostring(config.vein_mine))
        print("8. Network: " .. tostring(config.use_network))
        print("")
        print("9. Save & Back")
        print("")
        write("Choice: ")

        local choice = read()

        if choice == "1" then
            write("New width: ")
            config.width = tonumber(read()) or config.width
        elseif choice == "2" then
            write("New length: ")
            config.length = tonumber(read()) or config.length
        elseif choice == "3" then
            write("New depth: ")
            config.depth = tonumber(read()) or config.depth
        elseif choice == "4" then
            write("New torch interval: ")
            config.torch_interval = tonumber(read()) or config.torch_interval
        elseif choice == "5" then
            config.place_torches = not config.place_torches
        elseif choice == "6" then
            config.trash_junk = not config.trash_junk
        elseif choice == "7" then
            config.vein_mine = not config.vein_mine
        elseif choice == "8" then
            config.use_network = not config.use_network
        elseif choice == "9" then
            saveConfig()
            break
        end
    end
end

-- Test systems
local function testSystems()
    term.clear()
    term.setCursorPos(1, 1)
    print("=== System Test ===")
    print("")

    -- Test fuel
    print("Fuel Level: " .. turtle.getFuelLevel())
    print("Fuel Limit: " .. turtle.getFuelLimit())

    -- Test inventory
    print("Empty Slots: " .. inv.emptySlots())
    print("Total Items: " .. inv.totalItems())

    -- Test navigation
    print("Position: " .. nav.pos.x .. ", " .. nav.pos.y .. ", " .. nav.pos.z)
    print("Facing: " .. nav.getFacingName())

    -- Test network
    if config.use_network then
        if net.init() then
            print("Network: Connected")
            net.broadcastPresence()
        else
            print("Network: No modem")
        end
    else
        print("Network: Disabled")
    end

    -- Test GPS
    local x, y, z = gps.locate(2)
    if x then
        print("GPS: " .. x .. ", " .. y .. ", " .. z)
    else
        print("GPS: Not available")
    end

    print("")
    print("Press any key...")
    os.pullEvent("key")
end

-- Initialize all systems
local function initialize()
    print("Initializing systems...")

    -- Load config
    loadConfig()

    -- Initialize navigation
    nav.init()
    print("Navigation: OK")

    -- Initialize fuel tracking
    fuel.init()
    fuel.setReserve(config.fuel_reserve)
    fuel.setCritical(config.fuel_critical)
    print("Fuel: " .. turtle.getFuelLevel())

    -- Initialize network
    if config.use_network then
        if net.init() then
            print("Network: Connected")
            net.broadcastPresence()
        else
            print("Network: No modem found")
        end
    end

    -- Initialize mining module
    mine.init(nav, inv, fuel, safety, net, config)
    print("Mining: Ready")

    print("")
    sleep(1)
end

-- Network command handler (runs in parallel)
local function networkHandler()
    if not config.use_network or not net.connected then
        return
    end

    while running do
        local command = net.checkCommands()
        if command then
            local action = net.processCommand(command)

            if action == "stop" then
                running = false
                print("[CMD] Stop received")
            elseif action == "pause" then
                paused = true
                print("[CMD] Paused")
            elseif action == "resume" then
                paused = false
                print("[CMD] Resumed")
            elseif action == "return_home" then
                mine.returnHome()
                print("[CMD] Returning home")
            elseif action == "send_status" then
                net.sendStats(mine.getStats())
            end
        end

        -- Broadcast status periodically
        if not paused then
            net.sendStatus({
                pos = nav.pos,
                fuel = fuel.getStats(),
                inv = {
                    full = inv.isFull(),
                    empty_slots = inv.emptySlots(),
                },
                stats = mine.getStats(),
            })
        end

        sleep(config.broadcast_interval)
    end
end

-- Main mining task
local function miningHandler()
    while running do
        if paused then
            sleep(1)
        else
            -- Mining already started by menu selection
            if miningTask then
                -- Wait for mining to complete
                sleep(1)
            else
                sleep(1)
            end
        end
    end
end

-- Start mining with selected mode
local function startMining(mode)
    term.clear()
    term.setCursorPos(1, 1)

    print("Starting " .. mode .. " mining...")
    print("Press Ctrl+T to stop")
    print("")

    mine.init(nav, inv, fuel, safety, net, config)

    if mode == "quarry" then
        mine.quarry(config.width, config.length, config.depth)
    elseif mode == "strip" then
        mine.stripMine(50, 3, 3)
    elseif mode == "branch" then
        mine.branchMine(100, 10, 3)
    elseif mode == "vein" then
        mine.veinMineArea(16, 32)
    end

    print("")
    print("Mining complete!")
    print("")
    print("Stats:")
    local stats = mine.getStats()
    print("  Blocks mined: " .. stats.blocks_mined)
    print("  Ores found: " .. stats.ores_found)
    print("  Layers: " .. stats.layers_completed)
    print("")
    print("Press any key...")
    os.pullEvent("key")
end

-- Main program
local function main()
    initialize()

    -- Start network handler in parallel if enabled
    if config.use_network and net.connected then
        parallel.waitForAny(
            function()
                -- Main menu loop
                while running do
                    showMenu()
                    local choice = read()

                    if choice == "1" then
                        startMining("quarry")
                    elseif choice == "2" then
                        startMining("strip")
                    elseif choice == "3" then
                        startMining("branch")
                    elseif choice == "4" then
                        startMining("vein")
                    elseif choice == "5" then
                        configMenu()
                    elseif choice == "6" then
                        testSystems()
                    elseif choice == "7" then
                        running = false
                    end
                end
            end,
            networkHandler
        )
    else
        -- No network, just run menu
        while running do
            showMenu()
            local choice = read()

            if choice == "1" then
                startMining("quarry")
            elseif choice == "2" then
                startMining("strip")
            elseif choice == "3" then
                startMining("branch")
            elseif choice == "4" then
                startMining("vein")
            elseif choice == "5" then
                configMenu()
            elseif choice == "6" then
                testSystems()
            elseif choice == "7" then
                running = false
            end
        end
    end

    -- Cleanup
    net.close()
    nav.save()
    term.clear()
    term.setCursorPos(1, 1)
    print("Mining turtle shut down.")
end

-- Run
main()
