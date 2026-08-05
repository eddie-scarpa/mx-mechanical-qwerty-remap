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
; Letters that need character-based text injection because a clean
; native scan-code swap target isn't confirmed yet (M's AZERTY position
; hasn't been verified live). Every other letter needs no entry at all -
; J, K, L, and the rest sit in the identical physical position on both
; layouts, so a native passthrough already produces the right character
; AND a real keydown event (fixing app/game keyboard shortcuts like
; YouTube's J/K/L, which don't respond to text-injected characters).
textLetterMap := Map(50,"m")

; Punctuation still handled via text injection (not native yet) - lower
; priority since these aren't used for PIN entry or common shortcuts.
symbolMap := Map(
    12,["-","_"], 13,["=","+"],
    26,["[","{"], 27,["]","}"], 43,["\","|"],
    39,[";",":"], 40,["'",Chr(34)],
    41,["``","~"],
    51,[",","<"], 52,[".",">"], 53,["/","?"]
)

; Digit row: Belgian AZERTY needs Shift HELD to get a digit at all
; (unshifted gives a symbol instead) - there's no alternate key to swap
; to like with letters, so plain digits (no real Shift held) are sent
; natively by momentarily holding Shift ourselves for just that keystroke.
; Sent entirely through AHI's native path so it works everywhere,
; including the lock screen / PIN entry (which text-injection cannot
; reach - that's what broke PIN entry before this fix).
;
; Shift+digit (symbols) is a separate case: simply flipping Shift off
; lands on Belgian AZERTY's OWN symbol set at that position, not the US
; one - so that case still uses text injection with the correct US
; symbol. Not needed for PIN entry, so no lock-screen requirement here.
digitRowMap := Map(2,1,3,1,4,1,5,1,6,1,7,1,8,1,9,1,10,1,11,1)
digitSymbolMap := Map(2,"!",3,"@",4,"#",5,"$",6,"%",7,"^",8,"&",9,"*",10,"(",11,")")

; The four letter positions that differ between AZERTY and QWERTY.
; Applied unconditionally (typing AND shortcuts) via a genuine native
; scan-code swap - Windows' own layout translation still produces the
; correct character, and it's a real keydown/keyup event, so app/game
; shortcuts bound to Q/W/A/Z work correctly too, not just plain typing.
scanSwapMap := Map(16,30, 30,16, 17,44, 44,17)

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

    if (scanSwapMap.Has(code)) {
        ; Send the swapped scan code through Interception's own native
        ; path, for both down and up, so Windows sees a proper full
        ; press of the correct physical key identity - this now applies
        ; always, whether you're typing or holding a modifier for a
        ; shortcut.
        AHI.SendKeyEvent(kbId, scanSwapMap[code], state)
        return
    }

    if (textLetterMap.Has(code) && !isCombo) {
        if (state = 1) {
            base := textLetterMap[code]
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

    if (digitRowMap.Has(code) && !isCombo) {
        realShift := GetKeyState("Shift")
        if (realShift) {
            ; Shift+digit = symbol. Belgian AZERTY's own unshifted
            ; symbol set at this position isn't the US one, so this
            ; case stays on text injection with the correct US symbol
            ; rather than the native Shift-invert trick used below.
            if (state = 1)
                SendText(digitSymbolMap[code])
            return
        }
        ; No real Shift held - user wants the DIGIT. Belgian AZERTY
        ; gives the digit only when Shift is ON at this position, so
        ; momentarily hold Shift natively just for this key, entirely
        ; through Interception's own path (works at the lock screen).
        if (state = 1) {
            AHI.SendKeyEvent(kbId, 42, 1)
            AHI.SendKeyEvent(kbId, code, 1)
            AHI.SendKeyEvent(kbId, code, 0)
            AHI.SendKeyEvent(kbId, 42, 0)
        }
        return
    }

    ; Everything else (Shift, Ctrl, Alt, Win, CapsLock, Tab, Enter,
    ; Backspace, Space, Esc, arrows, F-keys, Insert, Delete, numpad,
    ; etc.) gets replayed through AHI's OWN native SendKeyEvent - injecting the
    ; identical scan code through the Interception driver itself, exactly
    ; as if it came from real hardware. This is deliberately NOT AHK's
    ; own Send/SendEvent stack: running AHK's hook-based Send alongside
    ; Interception's own low-level blocking on the same device was the
    ; actual cause of the stuck-Shift / one-way-CapsLock / cross-talk
    ; bugs - two separate injection systems were fighting each other.
    AHI.SendKeyEvent(kbId, code, state)
}

^Esc::ExitApp
