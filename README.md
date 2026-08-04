# MX Mechanical QWERTY Remap

Makes a **Logitech MX Mechanical** (US ANSI QWERTY) type correctly while your other keyboard keeps its own native layout (Belgian AZERTY, in this case) — both at the same time, no manual layout switching, ever.

## The problem

Windows only supports one system-wide keyboard layout at a time. Without this fix, using both keyboards meant constantly switching the active Windows layout back and forth (Ctrl+Shift) depending on which one was in use — Belgian AZERTY for the laptop, US QWERTY for the MX Mechanical — since Windows applies whatever layout is currently active to every keyboard equally.

## The fix

An [AutoHotkey v2](https://www.autohotkey.com/) script, using the [AutoHotInterception (AHI)](https://github.com/evilC/AutoHotInterception) library on top of the [Interception](https://github.com/oblitum/Interception) driver, that:

- Identifies the MX Mechanical specifically by its USB VID/PID (reference value: `0x046D` / `0xC548`, found via AHI's `Monitor.ahk`)
- Reads its raw scan codes directly, before Windows applies any layout translation
- Sends back the correct US QWERTY character for each key, regardless of what OS layout is active
- Leaves every other keyboard (the laptop's built-in one included) completely untouched

## Reference setup

| Thing | Location |
|---|---|
| Interception driver | `C:\Program Files\Interception\` |
| AHI library | `C:\Program Files\AHI\AHK v2\` |
| This script | `C:\Program Files\AHI\MX_QWERTY_Remap.ahk` |
| AutoHotkey v2 | `C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe` |

Runs automatically at login via a Task Scheduler task named **"MX Mechanical QWERTY Remap"**, set to run with highest privileges (needed — Interception won't attach without admin rights).

## Rebuilding this from scratch

Steps to redo this on a new machine:

### 1. Install AutoHotkey v2
Via winget/UniGetUI: `AutoHotkey.AutoHotkey`.

### 2. Install the Interception driver
1. Download `Interception.zip` from the [releases page](https://github.com/oblitum/Interception/releases), extract it.
2. Admin Command Prompt → into the `command line installer` folder → `install-interception.exe /install`
3. Reboot. Verify with `sc.exe query keyboard` → should show `STATE: 4 RUNNING`.

### 3. Set up AHI
1. Download `AutoHotInterception.zip` from its [releases page](https://github.com/evilC/AutoHotInterception/releases).
2. Extract the `AHK v2` folder to `C:\Program Files\AHI\`.
3. **Known extraction bug**: `AutoHotInterception.dll` lands at the top level of `AHK v2\` instead of inside `Lib\` — move it into `Lib\` manually, or `Monitor.ahk` will error out looking for it.
4. Unblock everything (right-click → Properties → Unblock, or `Get-ChildItem -Recurse | Unblock-File` in PowerShell) since it's all freshly downloaded.

### 4. Confirm the MX Mechanical's VID/PID
Run `Monitor.ahk`. Reference value: `0x046D` / `0xC548` (via the Logi Bolt receiver) — confirm before use, since it can vary by connection mode (Bluetooth vs receiver).

### 5. Drop in the script
Copy `MX_QWERTY_Remap.ahk` from this repo to `C:\Program Files\AHI\`. Update the `VID`/`PID` values and the `#include` path at the top if anything moved.

### 6. Task Scheduler
- Create Task → General: check **"Run with highest privileges"**
- Triggers: **At log on**
- Actions → Start a program:
  - Program: `C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe`
  - Arguments: `"C:\Program Files\AHI\MX_QWERTY_Remap.ahk"`
  - Start in: `C:\Program Files\AHI`

