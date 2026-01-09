-- Mining Turtle System Updater
-- Works on both Turtle and Pocket Computer
-- Run: wget run https://raw.githubusercontent.com/tyler919/cc-mining-turtle/main/update.lua

local REPO = "https://raw.githubusercontent.com/tyler919/cc-mining-turtle/main/"
local VERSION_FILE = "version.json"
local LOCAL_VERSION_FILE = ".version"

-- Detect device type
local function getDeviceType()
    if turtle then return "turtle"
    elseif pocket then return "pocket"
    else return "computer" end
end

-- Get local version
local function getLocalVersion()
    if fs.exists(LOCAL_VERSION_FILE) then
        local f = fs.open(LOCAL_VERSION_FILE, "r")
        local ver = f.readAll()
        f.close()
        return ver:gsub("%s+", "")  -- trim whitespace
    end
    return "0.0.0"
end

-- Save local version
local function saveLocalVersion(version)
    local f = fs.open(LOCAL_VERSION_FILE, "w")
    f.write(version)
    f.close()
end

-- Download file
local function download(url)
    local response = http.get(url)
    if response then
        local content = response.readAll()
        response.close()
        return content
    end
    return nil
end

-- Download and save file
local function downloadFile(remotePath, localPath)
    local url = REPO .. remotePath
    local content = download(url)
    if content then
        local f = fs.open(localPath, "w")
        f.write(content)
        f.close()
        return true
    end
    return false
end

-- Compare versions (returns true if remote is newer)
local function isNewer(local_ver, remote_ver)
    local function parseVersion(v)
        local major, minor, patch = v:match("(%d+)%.(%d+)%.(%d+)")
        return tonumber(major) or 0, tonumber(minor) or 0, tonumber(patch) or 0
    end

    local lmaj, lmin, lpat = parseVersion(local_ver)
    local rmaj, rmin, rpat = parseVersion(remote_ver)

    if rmaj > lmaj then return true end
    if rmaj == lmaj and rmin > lmin then return true end
    if rmaj == lmaj and rmin == lmin and rpat > lpat then return true end
    return false
end

-- Main updater
local function main()
    term.clear()
    term.setCursorPos(1, 1)

    print("=== Mining System Updater ===")
    print("")

    local deviceType = getDeviceType()
    print("Device: " .. deviceType)

    local localVersion = getLocalVersion()
    print("Installed: v" .. localVersion)
    print("")

    -- Check for HTTP
    if not http then
        print("ERROR: HTTP not enabled!")
        print("Enable it in ComputerCraft config")
        return
    end

    -- Fetch remote version info
    print("Checking for updates...")
    local versionData = download(REPO .. VERSION_FILE)

    if not versionData then
        print("ERROR: Could not connect!")
        print("Check internet connection.")
        return
    end

    local versionInfo = textutils.unserializeJSON(versionData)
    if not versionInfo then
        print("ERROR: Invalid version data")
        return
    end

    local remoteVersion = versionInfo.version
    print("Latest: v" .. remoteVersion)
    print("")

    -- Check if update needed
    if not isNewer(localVersion, remoteVersion) then
        print("Already up to date!")
        print("")
        print("Options:")
        print("1. Force reinstall anyway")
        print("2. Exit")
        print("")
        write("Choice: ")
        local choice = read()
        if choice ~= "1" then
            print("Bye!")
            return
        end
        print("")
    else
        print("Update available!")
        print("Changes: " .. (versionInfo.changelog or "Bug fixes"))
        print("")
        print("Install update? (y/n)")
        write("> ")
        local confirm = read()
        if confirm:lower() ~= "y" then
            print("Cancelled.")
            return
        end
        print("")
    end

    -- Download files based on device type
    local files = {}
    local basePath = ""

    if deviceType == "turtle" then
        files = versionInfo.turtle_files or {}
        basePath = "turtle/"
    elseif deviceType == "pocket" then
        files = versionInfo.pocket_files or {}
        basePath = "pocket/"
    else
        print("Unknown device type!")
        return
    end

    print("Downloading " .. #files .. " files...")
    print("")

    local success = 0
    local failed = 0

    for _, filename in ipairs(files) do
        write("  " .. filename .. "... ")
        if downloadFile(basePath .. filename, filename) then
            print("OK")
            success = success + 1
        else
            print("FAILED")
            failed = failed + 1
        end
    end

    -- Also download the updater itself
    write("  update.lua... ")
    if downloadFile("update.lua", "update.lua") then
        print("OK")
        success = success + 1
    else
        print("FAILED")
        failed = failed + 1
    end

    print("")
    print("Downloaded: " .. success .. " files")
    if failed > 0 then
        print("Failed: " .. failed .. " files")
    end

    -- Save new version
    saveLocalVersion(remoteVersion)

    print("")
    print("Update complete! v" .. remoteVersion)
    print("")
    print("Reboot now? (y/n)")
    write("> ")
    local reboot = read()
    if reboot:lower() == "y" then
        os.reboot()
    end
end

main()
