# MX Mechanical QWERTY Remap

Makes a **Logitech MX Mechanical** (US ANSI QWERTY) and a laptop's own **built-in Belgian AZERTY keyboard** both type correctly for what's physically printed on their keys — at the same time, permanently, with zero manual layout switching, not even a background one.

## The problem

Windows only supports one system-wide keyboard layout at a time. Two keyboards with different native layouts means one of them will always be wrong unless something compensates for the mismatch on a per-device basis.

## The fix

The OS default layout is set to **US QWERTY**, system-wide, permanently. The MX Mechanical is genuine US ANSI hardware, so it matches the OS natively and needs no remapping at all — this also fixes position-based bindings (e.g. WASD movement in emulators/games), since the MX now always reports its real physical scan codes with no translation layer involved.

The laptop's own built-in keyboard (genuine Belgian hardware) is the one that needs compensation, since the OS is no longer set to its native layout. An [AutoHotkey v2](https://www.autohotkey.com/) script, using the [AutoHotInterception (AHI)](https://github.com/evilC/AutoHotInterception) library on top of the [Interception](https://github.com/oblitum/Interception) driver, targets it specifically (by its device Handle, since laptop-internal keyboards typically have no real VID/PID) and:

- Reads its raw scan codes directly, before Windows applies any layout translation
- Sends back the correct Belgian character for each key, regardless of the US OS layout — covering letters, digits, punctuation, the AltGr layer, and dead-key composition (´, `, ^, ~ combining with vowels into accented characters)
- Leaves every other keyboard (the MX Mechanical included) completely untouched

### Known limitation

Remapping a physical key changes what scan code it reports — so a key can't simultaneously produce the correct *character* and the correct *physical position* when the two diverge. This only affects the four letter positions that differ between AZERTY and QWERTY (Q/W/A/Z), and only when typing directly on the laptop's own keyboard for position-based bindings (e.g. games). Every other key has no such trade-off. The MX Mechanical is unaffected either way, since it carries no remapping at all.

## Reference setup

| Thing | Location |
|---|---|
| Interception driver | `C:\Program Files\Interception\` |
| AHI library | `C:\Program Files\AHI\AHK v2\` |
| This script | `C:\Program Files\AHI\MX_QWERTY_Remap.ahk` |
| AutoHotkey v2 | `C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe` |

Runs automatically at login via a Task Scheduler task, set to run with highest privileges (needed — Interception won't attach without admin rights).

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

### 4. Set the OS layout to US QWERTY
Set as the permanent, system-wide default. The MX Mechanical needs no further setup once this is done.

### 5. Identify the laptop's built-in keyboard
Run `Monitor.ahk`. Laptop-internal keyboards typically show as VID/PID `0x0000, 0x0000` with no usable ID that way — use the device's **Handle** string instead (visible in the same tool), and target it via `GetKeyboardIdFromHandle()`. This value is hardware-specific and must be confirmed per machine, not assumed.

### 6. Drop in the script
Copy `MX_QWERTY_Remap.ahk` from this repo to `C:\Program Files\AHI\`. Update the Handle value and the `#include` path at the top if anything moved.

### 7. Task Scheduler
- Create Task → General: check **"Run with highest privileges"**
- Triggers: **At log on**
- Actions → Start a program:
  - Program: `C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe`
  - Arguments: `"C:\Program Files\AHI\MX_QWERTY_Remap.ahk"`
  - Start in: `C:\Program Files\AHI`
