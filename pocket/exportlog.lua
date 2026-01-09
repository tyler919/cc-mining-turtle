-- Log Export Tool for Mining Turtle System
-- Run this to export debug logs for troubleshooting

local function exportLog(filename)
    if not fs.exists(filename) then
        print("No log file found: " .. filename)
        return nil
    end

    local f = fs.open(filename, "r")
    local content = f.readAll()
    f.close()
    return content
end

local function main()
    term.clear()
    term.setCursorPos(1, 1)

    print("=== Log Export Tool ===")
    print("")
    print("Device ID: " .. os.getComputerID())
    print("Label: " .. (os.getComputerLabel() or "none"))
    print("")

    -- Check what logs exist
    local logs = {}
    if fs.exists("net_debug.log") then
        table.insert(logs, "net_debug.log")
    end
    if fs.exists("monitor_debug.log") then
        table.insert(logs, "monitor_debug.log")
    end

    if #logs == 0 then
        print("No debug logs found!")
        print("")
        print("Run the mining program or monitor")
        print("first to generate logs.")
        return
    end

    print("Found logs:")
    for i, log in ipairs(logs) do
        local size = fs.getSize(log)
        print("  " .. i .. ". " .. log .. " (" .. size .. " bytes)")
    end

    print("")
    print("Options:")
    print("1. Print last 50 lines to screen")
    print("2. Print ALL to screen (for copy)")
    print("3. Clear logs")
    print("4. Exit")
    print("")
    write("Choice: ")

    local choice = read()

    if choice == "1" then
        -- Print last 50 lines
        for _, logfile in ipairs(logs) do
            print("")
            print("=== " .. logfile .. " (last 50 lines) ===")
            local content = exportLog(logfile)
            if content then
                local lines = {}
                for line in content:gmatch("[^\n]+") do
                    table.insert(lines, line)
                end
                local start = math.max(1, #lines - 49)
                for i = start, #lines do
                    print(lines[i])
                end
            end
        end

    elseif choice == "2" then
        -- Print everything (for copy/paste)
        print("")
        print("======= COPY BELOW THIS LINE =======")
        print("")
        print("```")
        print("Device: " .. (os.getComputerLabel() or "Turtle") .. " (ID: " .. os.getComputerID() .. ")")
        print("Time: " .. os.epoch("utc"))
        print("")

        for _, logfile in ipairs(logs) do
            print("--- " .. logfile .. " ---")
            local content = exportLog(logfile)
            if content then
                print(content)
            end
            print("")
        end

        print("```")
        print("")
        print("======= COPY ABOVE THIS LINE =======")

    elseif choice == "3" then
        -- Clear logs
        for _, logfile in ipairs(logs) do
            fs.delete(logfile)
            print("Deleted: " .. logfile)
        end
        print("Logs cleared!")

    elseif choice == "4" then
        print("Bye!")
    end
end

main()
