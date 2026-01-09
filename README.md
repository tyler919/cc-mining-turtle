# CC:Tweaked Mining Turtle System

A full-featured mining turtle system with remote pocket computer monitoring.

## Features

### Mining Modes
- **Quarry** - Digs a rectangular pit down to bedrock
- **Strip Mine** - Horizontal tunnels at diamond level
- **Branch Mine** - Main tunnel with side branches
- **Vein Mine** - Finds and follows ore veins

### Smart Features
- GPS or dead-reckoning position tracking
- Automatic ore vein detection and mining
- Lava/water hazard handling
- Gravel/sand falling block handling
- Automatic inventory management
- Junk item filtering (drops cobblestone, dirt, etc.)
- Auto-refuel from inventory or chest
- Return home when full or low fuel
- Torch placement

### Remote Monitoring (Pocket Computer)
- Real-time turtle status
- Position tracking
- Fuel level
- Inventory status
- Mining statistics
- Remote commands (stop, pause, return home)

## Installation

### Turtle Setup

1. Place a **Mining Turtle** with a **Wireless Modem** (for networking)
2. Copy these files to the turtle:
   - `nav.lua`
   - `inv.lua`
   - `fuel.lua`
   - `safety.lua`
   - `mine.lua`
   - `net.lua`
   - `main.lua`
   - `startup.lua`

3. Reboot the turtle

### Pocket Computer Setup

1. Create a **Pocket Computer** with a **Wireless Modem**
2. Copy `monitor.lua` to it
3. Run: `monitor`

## Usage

### Turtle
```
1. Quarry (16x16x64)
2. Strip Mine
3. Branch Mine
4. Vein Mine
5. Configure
6. Test Systems
7. Exit
```

### Configuration Options
- Width/Length/Depth for quarry
- Torch placement interval
- Enable/disable vein mining
- Enable/disable junk trashing
- Network broadcasting

### Pocket Computer Controls
- **1-9**: Select turtle
- **S**: Stop mining
- **P**: Pause
- **H**: Return home
- **R**: Refresh
- **B**: Back to list

## Setup Tips

### Chest Layout
Place the turtle with:
- **Storage chest** in front (for dumping items)
- **Fuel chest** behind (for refueling)

```
[Fuel Chest]
    |
[TURTLE] --> [Storage Chest]
    |
  (Mining direction)
```

### GPS (Optional)
Set up GPS satellites for accurate position tracking:
- 4 computers at different heights with wireless modems
- Run `gps host <x> <y> <z>` on each

### Fuel
The turtle needs fuel! Good sources:
- Coal (80 fuel each)
- Charcoal (80 fuel each)
- Coal blocks (800 fuel each)
- Lava buckets (1000 fuel each)

## File Structure
```
turtle/
├── nav.lua      - Navigation & positioning
├── inv.lua      - Inventory management
├── fuel.lua     - Fuel management
├── safety.lua   - Hazard handling
├── mine.lua     - Mining patterns
├── net.lua      - Network communication
├── main.lua     - Main controller
└── startup.lua  - Auto-start script

pocket/
└── monitor.lua  - Remote monitoring app
```

## Network Protocol

The system uses rednet with protocol `MINING_NET`.

### Message Types
- `status` - Turtle status broadcast
- `stats` - Mining statistics
- `position` - Position update
- `inventory` - Inventory summary
- `alert` - High priority alerts
- `command` - Remote commands
- `presence` - Discovery broadcast

## Troubleshooting

### Turtle won't move
- Check fuel level
- Make sure nothing is blocking

### No network connection
- Ensure wireless modem is attached
- Check that modem is on correct side

### Position drift
- Use GPS for accurate tracking
- Or manually reset position at home

### Missing modules
- Run installer again
- Check all files are present

## Version
1.0.0
