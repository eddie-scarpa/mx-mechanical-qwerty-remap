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
; M has no reciprocal swap partner (unlike Q/W/A/Z) - the position
; labeled ";" on the US board is where Belgian AZERTY natively produces
; "m"/"M" (confirmed correct via the working ; text-injection below), so
; M just borrows that scan code one-way. ";" itself keeps its own
; separate handling further down - this does NOT touch that.
mNativeCode := 39

; Punctuation still handled via text injection (not native yet) - lower
; priority since these aren't used for PIN entry or common shortcuts.
; ("-" and "=" removed - see punctSwapMap below, verified native instead)
symbolMap := Map(
    26,["[","{"], 27,["]","}"], 43,["\","|"],
    39,[";",":"], 40,["'",Chr(34)],
    41,["``","~"],
    51,[",","<"], 52,[".",">"], 53,["/","?"]
)

; "-" and "=" verified live: the "=" key natively produces exactly what
; "-" needs (base "-", shift "_"), and the "/" key natively produces
; exactly what "=" needs (base "=", shift "+") - a clean one-way native
; redirect, same low-risk technique as the Q/W/A/Z swap, no shift
; trickery needed since the target's own natural behavior already
; matches. The remaining punctuation keys had no such match when tested
; live (likely only reachable via AltGr), so they stay on text injection.
punctSwapMap := Map(12,13, 13,53)

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

    if (punctSwapMap.Has(code)) {
        ; "-" and "=" - same native redirect technique, verified live.
        AHI.SendKeyEvent(kbId, punctSwapMap[code], state)
        return
    }

    if (code = 50) {
        ; M - send the native scan code for the AZERTY position that
        ; produces "m"/"M", exactly like the Q/W/A/Z swap, so it works
        ; as a genuine keydown event for shortcuts too (e.g. YouTube mute).
        AHI.SendKeyEvent(kbId, mNativeCode, state)
        return
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
