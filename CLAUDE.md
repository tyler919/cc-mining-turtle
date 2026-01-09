# CC:Tweaked Mining Turtle System - Development Guide

## Project Overview

A full-featured mining turtle system for CC:Tweaked (Minecraft) with remote pocket computer monitoring.

**Repository:** https://github.com/tyler919/cc-mining-turtle
**Current Version:** 1.3.2

## File Structure

```
cc-mining-turtle/
├── turtle/
│   ├── nav.lua          # Navigation & GPS/dead-reckoning positioning
│   ├── inv.lua          # Inventory management, junk filtering
│   ├── fuel.lua         # Fuel management, auto-refuel
│   ├── safety.lua       # Hazard handling (lava, water, gravel)
│   ├── mine.lua         # Mining patterns (quarry, strip, branch, vein)
│   ├── net.lua          # Network communication (rednet)
│   ├── main.lua         # Main controller with menu
│   ├── startup.lua      # Auto-start script
│   └── exportlog.lua    # Debug log export tool
├── pocket/
│   ├── monitor.lua      # Remote monitoring app
│   └── exportlog.lua    # Debug log export tool
├── installer.lua        # URL-based installer
├── turtle_installer.lua # Self-contained installer (embedded code)
├── update.lua           # Auto-updater for both devices
├── version.json         # Version info for update checking
└── README.md            # User documentation
```

## Versioning Rules

Format: `MAJOR.FEATURES.FIXES`

- **MAJOR**: Increments when FEATURES reaches 10 (1.10.x → 2.0.x)
- **FEATURES** (middle): +1 for each new feature added
- **FIXES** (last): +1 for each bug fix, **NEVER resets to zero**

Examples:
- `1.2.0` = 2 new features added since 1.0.0
- `1.0.2` = 2 bug fixes
- `1.3.10` = 3 features, 10 total bug fixes
- `1.10.5` → next feature release = `2.0.5` (fixes carry over)

## Network Protocol

Protocol name: `MINING_NET`

### Message Types
- `status` - Turtle broadcasts status (pos, fuel, inventory, stats)
- `presence` - Turtle announces itself
- `command` - Pocket sends command to turtle
- `register` - Pocket registers with turtles
- `registered` - Turtle acknowledges registration
- `alert` - High priority alerts
- `stats` - Mining statistics
- `position` - Position updates

### Current Issue
Messages sent to pocket also print on turtle screen, blocking user interaction.

## Known Bugs to Fix

### BUG-001: Network messages print on turtle screen
**Severity:** High
**Description:** When turtle sends status to pocket, debug messages print on turtle's screen. User cannot see menu or know which button to press.
**Location:** `turtle/net.lua` - debugLog function prints to screen
**Fix:** Remove or disable print() in debugLog, only write to file

### BUG-002: Multi-turtle not working on pocket monitor
**Severity:** Medium
**Description:** Multiple turtles don't appear correctly on pocket computer
**Location:** `pocket/monitor.lua`
**Debug:** Need log output from both devices to diagnose

## Planned Features

### FEATURE: Turtle-to-Turtle Collision Avoidance (v1.2.x)
**Description:** Turtles communicate their positions to each other. If two turtles detect they're on a collision course, they adjust paths to avoid each other.

**Implementation Plan:**
1. Add new message type: `turtle_position` - broadcast current position to other turtles
2. Each turtle maintains a list of known turtle positions
3. Before moving, check if destination conflicts with another turtle's position
4. If conflict detected:
   - Wait a random short delay (0.5-2 seconds)
   - Re-check position
   - If still blocked, find alternate path
5. Broadcast position after each move

**Files to modify:**
- `turtle/net.lua` - Add turtle-to-turtle messaging
- `turtle/nav.lua` - Add collision checking before moves
- `turtle/mine.lua` - Integrate collision avoidance into mining patterns

**New message format:**
```lua
{
    type = "turtle_position",
    turtle_id = <id>,
    pos = {x, y, z},
    facing = <0-3>,
    timestamp = <epoch>
}
```

### FEATURE: 3x3 Strip Mine Mode (v1.3.x)
**Description:** New mining mode that creates a 3-block wide by 3-block tall tunnel, more efficient for finding ores.

**Implementation Plan:**
1. Add new function `mine.stripMine3x3(length)`
2. Dig pattern:
   - Dig forward (center)
   - Dig up (top center)
   - Dig down (bottom center)
   - Turn left, dig (left column - 3 blocks)
   - Turn around, dig (right column - 3 blocks)
   - Return to center, move forward
3. Check for ores on all exposed surfaces
4. Place torches every N blocks on floor

**Files to modify:**
- `turtle/mine.lua` - Add stripMine3x3 function
- `turtle/main.lua` - Add menu option for 3x3 strip mine

## Development Commands

### Testing on devices
```
-- Turtle: Check debug log
edit net_debug.log

-- Pocket: Check debug log
edit monitor_debug.log

-- Either device: Export logs for sharing
exportlog
```

### Updating version
1. Update `version.json` with new version number and changelog
2. Update VERSION constant in `turtle/main.lua`
3. Update VERSION constant in `pocket/monitor.lua`
4. Commit with version in message

### Quick install commands
```
-- Fresh install (turtle or pocket)
wget run https://raw.githubusercontent.com/tyler919/cc-mining-turtle/main/update.lua

-- Check for updates (on device)
update
```

## Next Steps (Priority Order)

1. **Fix BUG-001**: Stop debug messages printing on turtle screen
2. **Fix BUG-002**: Debug and fix multi-turtle display on pocket
3. **Add FEATURE**: Turtle-to-turtle collision avoidance
4. **Add FEATURE**: 3x3 strip mine mode

## Code Style

- Use `local` for all variables
- Functions should be short and focused
- Add debug logging for network operations (to file only, not screen)
- Compact UI text for pocket computer (26 chars wide)
- Test on both turtle and pocket before pushing
