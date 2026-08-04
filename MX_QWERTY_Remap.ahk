#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent
; Must be run as Administrator - the Interception driver will not attach otherwise.

#include C:\Program Files\AHI\AHK v2\Lib\AutoHotInterception.ahk

; Confirmed via Monitor.ahk: MX Mechanical shows as ID:2, VID_046D, PID_C548
VID := 0x046D
PID := 0xC548

; ------------------------------------------------------------------
; US QWERTY character map, keyed by raw scan code (as reported by
; Monitor.ahk's "Code" column for this same device).
; Letters map to a single lowercase letter (case is derived live from
; Shift/CapsLock state). Symbol/digit keys map to [unshifted, shifted].
; ------------------------------------------------------------------
letterMap := Map(
    16,"q", 17,"w", 18,"e", 19,"r", 20,"t", 21,"y", 22,"u", 23,"i", 24,"o", 25,"p",
    30,"a", 31,"s", 32,"d", 33,"f", 34,"g", 35,"h", 36,"j", 37,"k", 38,"l",
    44,"z", 45,"x", 46,"c", 47,"v", 48,"b", 49,"n", 50,"m"
)

symbolMap := Map(
    2,["1","!"], 3,["2","@"], 4,["3","#"], 5,["4","$"], 6,["5","%"],
    7,["6","^"], 8,["7","&"], 9,["8","*"], 10,["9","("], 11,["0",")"],
    12,["-","_"], 13,["=","+"],
    26,["[","{"], 27,["]","}"], 43,["\","|"],
    39,[";",":"], 40,["'",Chr(34)],
    41,["``","~"],
    51,[",","<"], 52,[".",">"], 53,["/","?"]
)

; The four positions that differ between AZERTY and QWERTY. Even when a
; modifier is held (shortcut mode), these still need translating -
; otherwise Ctrl+A (physically the MX's A key) fires whatever Belgian
; AZERTY thinks that position means (Ctrl+Q), not Ctrl+A. Maps each scan
; code to the scan code it should actually send.
scanSwapMap := Map(16,30, 30,16, 17,44, 44,17)

; Numpad cluster keys share their raw scan code with the navigation
; cluster (Home/End/arrows/PgUp/PgDn) - real hardware disambiguates via
; the NumLock toggle before the OS even sees a scan code, so a plain
; scan-code passthrough can't reliably reproduce that. Instead we check
; NumLock ourselves and send the correct unambiguous named key.
numpadMap := Map(
    71,["Numpad7","Home"], 72,["Numpad8","Up"], 73,["Numpad9","PgUp"],
    75,["Numpad4","Left"], 76,["Numpad5","Clear"], 77,["Numpad6","Right"],
    79,["Numpad1","End"], 80,["Numpad2","Down"], 81,["Numpad3","PgDn"],
    82,["Numpad0","Ins"], 83,["NumpadDot","Delete"]
)

AHI := AutoHotInterception()
kbId := AHI.GetKeyboardId(VID, PID)

; block=true: ALL key events from this specific device are swallowed by
; Interception before Windows ever sees them. We alone decide what (if
; anything) gets sent back, via the KeyEvent callback below.
; This is layout-independent - it does not matter what Windows layout is
; active, and it does not matter what order you switch layouts vs launch
; this script in.
AHI.SubscribeKeyboard(kbId, true, KeyEvent)
return

KeyEvent(code, state) {
    ; state: 1 = key down, 0 = key up

    isCombo := GetKeyState("Ctrl") || GetKeyState("Alt") || GetKeyState("LWin") || GetKeyState("RWin")

    if (isCombo && scanSwapMap.Has(code)) {
        ; Send the swapped scan code through Interception's own native
        ; path, for both down and up, so Windows sees a proper full
        ; press of the correct physical key identity while whatever
        ; modifiers are already held stay held.
        AHI.SendKeyEvent(kbId, scanSwapMap[code], state)
        return
    }

    if (letterMap.Has(code) && !isCombo) {
        if (state = 1) {
            base := letterMap[code]
            useUpper := GetKeyState("Shift") != GetKeyState("CapsLock","T")
            SendText(useUpper ? StrUpper(base) : base)
        }
        return  ; swallow the "up" event too - SendText already handled the full press
    }

    if (symbolMap.Has(code) && !isCombo) {
        if (state = 1) {
            pair := symbolMap[code]
            SendText(GetKeyState("Shift") ? pair[2] : pair[1])
        }
        return
    }

    if numpadMap.Has(code) {
        pair := numpadMap[code]
        keyName := GetKeyState("NumLock","T") ? pair[1] : pair[2]
        SendEvent("{" keyName (state = 1 ? " down" : " up") "}")
        return
    }

    ; Everything else (Shift, Ctrl, Alt, Win, CapsLock, Tab, Enter,
    ; Backspace, Space, Esc, arrows, F-keys, Insert, Delete, etc.) gets
    ; replayed through AHI's OWN native SendKeyEvent - injecting the
    ; identical scan code through the Interception driver itself, exactly
    ; as if it came from real hardware. This is deliberately NOT AHK's
    ; own Send/SendEvent stack: running AHK's hook-based Send alongside
    ; Interception's own low-level blocking on the same device was the
    ; actual cause of the stuck-Shift / one-way-CapsLock / cross-talk
    ; bugs - two separate injection systems were fighting each other.
    AHI.SendKeyEvent(kbId, code, state)
}

^Esc::ExitApp
