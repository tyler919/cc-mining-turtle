-- Mining Turtle System Installer
-- Downloads and installs all mining turtle modules

local VERSION = "1.0.0"
local BASE_URL = "https://raw.githubusercontent.com/tyler919/cc-mining-turtle/main/"

-- Files to download for turtle
local TURTLE_FILES = {
    "turtle/nav.lua",
    "turtle/inv.lua",
    "turtle/fuel.lua",
    "turtle/safety.lua",
    "turtle/mine.lua",
    "turtle/net.lua",
    "turtle/main.lua",
    "turtle/startup.lua",
}

-- Files for pocket computer
local POCKET_FILES = {
    "pocket/monitor.lua",
}

-- Detect device type
local function getDeviceType()
    if turtle then
        return "turtle"
    elseif pocket then
        return "pocket"
    else
        return "computer"
    end
end

-- Download file
local function downloadFile(url, path)
    local response = http.get(url)
    if response then
        local content = response.readAll()
        response.close()

        local file = fs.open(path, "w")
        file.write(content)
        file.close()
        return true
    end
    return false
end

-- Install for turtle
local function installTurtle()
    print("Installing Mining Turtle System...")
    print("")

    local success = 0
    local failed = 0

    for _, file in ipairs(TURTLE_FILES) do
        local filename = file:match("turtle/(.+)")
        write("  " .. filename .. "... ")

        local url = BASE_URL .. file
        if downloadFile(url, filename) then
            print("OK")
            success = success + 1
        else
            print("FAILED")
            failed = failed + 1
        end
    end

    print("")
    print("Installed: " .. success .. " files")
    if failed > 0 then
        print("Failed: " .. failed .. " files")
    end

    return failed == 0
end

-- Install for pocket computer
local function installPocket()
    print("Installing Pocket Monitor...")
    print("")

    for _, file in ipairs(POCKET_FILES) do
        local filename = file:match("pocket/(.+)")
        write("  " .. filename .. "... ")

        local url = BASE_URL .. file
        if downloadFile(url, filename) then
            print("OK")
        else
            print("FAILED")
        end
    end
end

-- Manual install (paste code directly)
local function manualInstall()
    print("Manual Installation Mode")
    print("")
    print("Copy the code files to this device:")
    print("")

    local deviceType = getDeviceType()

    if deviceType == "turtle" then
        print("Required files:")
        print("  nav.lua")
        print("  inv.lua")
        print("  fuel.lua")
        print("  safety.lua")
        print("  mine.lua")
        print("  net.lua")
        print("  main.lua")
        print("  startup.lua")
    elseif deviceType == "pocket" then
        print("Required files:")
        print("  monitor.lua")
    end

    print("")
    print("Use 'edit <filename>' to create each file")
    print("and paste the code from the source.")
end

-- Main installer
local function main()
    term.clear()
    term.setCursorPos(1, 1)

    print("=================================")
    print("  Mining Turtle System Installer")
    print("  Version " .. VERSION)
    print("=================================")
    print("")

    local deviceType = getDeviceType()
    print("Detected device: " .. deviceType)
    print("")

    print("Installation options:")
    print("1. Download from URL")
    print("2. Manual install (instructions)")
    print("3. Exit")
    print("")
    write("Choice: ")

    local choice = read()

    if choice == "1" then
        if not http then
            print("")
            print("HTTP API not available!")
            print("Use manual install instead.")
            sleep(2)
            manualInstall()
            return
        end

        print("")
        if deviceType == "turtle" then
            if installTurtle() then
                print("")
                print("Installation complete!")
                print("Reboot to start: reboot")
            end
        elseif deviceType == "pocket" then
            installPocket()
            print("")
            print("Installation complete!")
            print("Run: monitor")
        else
            print("Please run on a turtle or pocket computer")
        end

    elseif choice == "2" then
        term.clear()
        term.setCursorPos(1, 1)
        manualInstall()

    elseif choice == "3" then
        print("Cancelled.")
    end
end

main()
