-- Mining Turtle Startup Script
-- Automatically runs the mining program

print("Mining Turtle System")
print("Loading...")

-- Check if all modules exist
local modules = {"nav", "inv", "fuel", "safety", "mine", "net", "main"}
local missing = {}

for _, mod in ipairs(modules) do
    if not fs.exists(mod .. ".lua") then
        table.insert(missing, mod)
    end
end

if #missing > 0 then
    print("Missing modules: " .. table.concat(missing, ", "))
    print("")
    print("Run 'installer' to reinstall")
    return
end

-- Run main program
shell.run("main")
