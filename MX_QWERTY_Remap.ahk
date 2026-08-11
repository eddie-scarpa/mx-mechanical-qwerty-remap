#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent
; STRUCTURAL REWRITE: OS default layout is US QWERTY (system-wide).
; The MX Mechanical is genuine US ANSI hardware, so it needs ZERO
; remapping - it matches the OS natively.
;
; This script remaps the LAPTOP's own built-in Belgian AZERTY keyboard,
; so IT keeps producing correct Belgian characters despite the OS no
; longer being set to Belgian. Every character below was verified
; against real typed output.
;
; THIS VERSION ADDS: AltGr layer (11 of 12 keys fully native, 1 text-
; injection fallback for the accent-acute symbol) and the ISO key near
; Left Shift (code 86, "<>\" on BE hardware) - both previously unbuilt
; gaps. Shift+AltGr is confirmed (live-tested) to produce nothing on
; real BE hardware for every AltGr key, so that combo is suppressed.
;
; STILL A STANDALONE TEST SCRIPT - not yet the Task-Scheduler-launched
; file, not yet pushed to GitHub. Test under a temporarily-switched US
; OS layout before considering permanent deployment.
;
; UNVERIFIED ASSUMPTION TO WATCH FOR: while RAlt is physically held
; down, it is passed through to the OS unmodified (not remapped), and
; the AltGr branch below then ALSO sends a synthetic native key/Shift
; combo on top of that real RAlt-down state. On a plain US layout this
; should be harmless (US has no AltGr-layer definition), but this
; specific interaction has NOT been live-tested yet like everything
; else in this project has been - verify actual Notepad output for
; every AltGr key before trusting it, same discipline as always.
;
; Must be run as Administrator - the Interception driver will not
; attach otherwise.

#include C:\Program Files\AHI\AHK v2\Lib\AutoHotInterception.ahk

AHI := AutoHotInterception()
; ThinkPad's internal keyboard has no real VID/PID - targeted by its
; Handle string instead.
tpId := AHI.GetKeyboardIdFromHandle("ACPI\VEN_LEN&DEV_0071")

; The four letter positions that differ between AZERTY and QWERTY -
; reciprocal swap, symmetric regardless of which OS layout is active.
scanSwapMap := Map(16,30, 30,16, 17,44, 44,17)

; Digit row: physical legend is base=BE symbol, shift=digit (real
; hardware, unchanged). Under a US-active OS:
;  - Shift+key (want the DIGIT): suppress real Shift, replay natively.
;  - Plain key (want the BE symbol): most have no US equivalent at all
;    (accented/non-ASCII) - text injection fallback for those; the few
;    that DO have a native US Shift-combo source get full native
;    treatment, same as everything else.
digitInfo := Map(
    2, {text:"&", nativeCode:8,  nativeShift:true},
    3, {text:"é", nativeCode:0,  nativeShift:false},
    4, {text:Chr(34), nativeCode:40, nativeShift:true},
    5, {text:"'", nativeCode:40, nativeShift:false},
    6, {text:"(", nativeCode:10, nativeShift:true},
    7, {text:"§", nativeCode:0,  nativeShift:false},
    8, {text:"è", nativeCode:0,  nativeShift:false},
    9, {text:"!", nativeCode:2,  nativeShift:true},
    10,{text:"ç", nativeCode:0,  nativeShift:false},
    11,{text:"à", nativeCode:0,  nativeShift:false}
)

; Remaining punctuation - every value verified against real typed
; output on the ThinkPad. Some Belgian characters (°, ¨, µ, £, ², ³)
; don't exist on a US keyboard via any Shift combo - those fall back
; to text injection; everything else is fully native.
; Code 86 (the ISO key near Left Shift, "<>\" on BE hardware) added in
; this version - previously unbuilt.
punctInfo := Map(
    12,{base:{text:")",code:11,shift:true},  shft:{text:"°",code:0, shift:false}},
    13,{base:{text:"-",code:12,shift:false}, shft:{text:"_",code:12,shift:true}},
    26,{base:{text:"^",code:7, shift:true},  shft:{text:"¨",code:0, shift:false}},
    27,{base:{text:"$",code:5, shift:true},  shft:{text:"*",code:9, shift:true}},
    43,{base:{text:"µ",code:0, shift:false}, shft:{text:"£",code:0, shift:false}},
    40,{base:{text:"ù",code:0, shift:false}, shft:{text:"%",code:6, shift:true}},
    41,{base:{text:"²",code:0, shift:false}, shft:{text:"³",code:0, shift:false}},
    50,{base:{text:",",code:51,shift:false}, shft:{text:"?",code:53,shift:true}},
    51,{base:{text:";",code:39,shift:false}, shft:{text:".",code:52,shift:false}},
    52,{base:{text:":",code:39,shift:true},  shft:{text:"/",code:53,shift:false}},
    53,{base:{text:"=",code:13,shift:false}, shft:{text:"+",code:13,shift:true}},
    86,{base:{text:"<",code:51,shift:true},  shft:{text:">",code:52,shift:true}}
)

; AltGr layer - live-verified: 11 of 12 keys map directly onto a plain
; US Shift-combo (no AltGr needed on the US side, since the plain US
; layout already has these symbols natively). Only the accent-acute
; (´, from code 40) has no US equivalent and needs text injection,
; same category as the non-AltGr accented fallbacks above.
; Shift+AltGr is confirmed to produce nothing on real BE hardware for
; every one of these keys - handled as a suppressed (no-op) combo in
; RemapEvent, not guessed at.
altGrInfo := Map(
    2, {text:"", nativeCode:43, nativeShift:true},  ; |
    3, {text:"", nativeCode:3,  nativeShift:true},  ; @
    4, {text:"", nativeCode:4,  nativeShift:true},  ; #
    7, {text:"", nativeCode:7,  nativeShift:true},  ; ^
    10,{text:"", nativeCode:26, nativeShift:true},  ; {
    11,{text:"", nativeCode:27, nativeShift:true},  ; }
    26,{text:"", nativeCode:26, nativeShift:false}, ; [
    27,{text:"", nativeCode:27, nativeShift:false}, ; ]
    40,{text:"´",nativeCode:0,  nativeShift:false}, ; ´ - no US equivalent
    43,{text:"", nativeCode:41, nativeShift:false}, ; `
    53,{text:"", nativeCode:41, nativeShift:true},  ; ~
    86,{text:"", nativeCode:43, nativeShift:false}  ; \
)

raltDown := false

; Dead keys: on real BE hardware, ^ (unshifted, no AltGr) and ´/`/~
; (all AltGr) don't output a character on their own - pressing one
; arms a pending accent that only resolves once the NEXT key is
; pressed: a composable vowel/n produces the accented letter, space
; is absorbed into the bare accent mark, and anything else outputs
; the bare accent mark followed by that key's own normal output.
; Every value below is live-tested against real Notepad output.
pendingDeadKey := ""
suppressReleaseCode := 0
deadKeySymbol := Map(26,"^", 40,"´", 43,"``", 53,"~")
deadKeyCompose := Map(
    "^", Map(18,"ê", 16,"â", 24,"ô", 23,"î", 22,"û"),
    "´", Map(18,"é", 16,"á", 24,"ó", 23,"í", 22,"ú"),
    "``", Map(18,"è", 16,"à", 24,"ò", 23,"ì", 22,"ù"),
    "~", Map(16,"ã", 24,"õ", 49,"ñ")
)

AHI.SubscribeKeyboard(tpId, true, RemapEvent)
return

RemapEvent(code, state) {
    global AHI, tpId, scanSwapMap, digitInfo, punctInfo, altGrInfo, raltDown
    global pendingDeadKey, suppressReleaseCode, deadKeySymbol, deadKeyCompose

    ; Swallow the release of any key whose press was suppressed above
    ; (an armed dead key, or a composed/absorbed output sent via
    ; SendText) so the OS never sees a stray keyup with no matching
    ; keydown.
    if (state = 0 && code = suppressReleaseCode) {
        suppressReleaseCode := 0
        return
    }

    ; Resolve a pending dead key against this keypress, before any
    ; other handling. Space is absorbed into the bare accent mark
    ; (standard dead-key convention, matches live-tested output). A
    ; composable vowel/n produces the accented letter. Anything else
    ; outputs the bare accent mark and then falls through to let this
    ; same key's own normal handling run too (e.g. ^ then b → "^b").
    if (pendingDeadKey != "" && state = 1) {
        pdk := pendingDeadKey
        pendingDeadKey := ""
        if (code = 57) {
            SendText(pdk)
            suppressReleaseCode := code
            return
        }
        if (deadKeyCompose[pdk].Has(code)) {
            SendText(deadKeyCompose[pdk][code])
            suppressReleaseCode := code
            return
        }
        SendText(pdk)
        ; no return - this key's own press still gets handled below
    }

    ; RAlt state is tracked ourselves rather than via GetKeyState("RAlt").
    ; Live-tested: GetKeyState("RAlt") only reads correctly for the very
    ; first key pressed right after RAlt goes down, then reads as
    ; released on every subsequent press while RAlt is still physically
    ; held - confirmed by every AltGr key failing the same way (not just
    ; the SendText-based one), which points at the query itself, not any
    ; one key's handling. Self-tracking via the RAlt press/release events
    ; we already receive here removes that unreliable dependency.
    ; RAlt is suppressed from reaching the OS entirely - it's tracked
    ; internally only (raltDown), used purely to select the AltGr layer
    ; below. Live-tested reason: with a plain US OS layout (no AltGr
    ; defined), letting the real RAlt keydown ride through to Windows
    ; while we then inject a synthetic native key on top of it made
    ; Windows treat that combination as an Alt+key shortcut (menu
    ; access / system shortcut), not as text - so every native-redirect
    ; AltGr key produced nothing. The one exception (SendText-based ´)
    ; worked because SendText doesn't get interpreted as an Alt-chord
    ; the same way. Suppressing RAlt avoids the interference outright.
    ; Code 298 is suppressed - it's not a real key. Live-tested: pressing
    ; Home sends this unusual, non-standard code immediately before the
    ; real Home code (327), and relaying it via AHI.SendKeyEvent is the
    ; suspected cause of the ThinkPad hook silently dying (no crash
    ; dialog, process stays alive, but the device stops responding).
    ; Suppressing it outright is the direct test of that theory - the
    ; real Home key (327) still passes through normally below.
    if (code = 298) {
        return
    }

    if (code = 312) {
        raltDown := (state = 1)
        return
    }

    if (scanSwapMap.Has(code)) {
        AHI.SendKeyEvent(tpId, scanSwapMap[code], state)
        return
    }

    ; M: ThinkPad's physical "M"-labeled key is scan 39, needs to send
    ; native scan 50 (US's own M position) for correct output.
    if (code = 39) {
        AHI.SendKeyEvent(tpId, 50, state)
        return
    }

    ; AltGr layer - only intercept when RAlt is actually held AND this
    ; key has AltGr behavior. Checked before digitInfo/punctInfo since
    ; several codes appear in both tables (their AltGr output differs
    ; from their plain/Shift output).
    if (altGrInfo.Has(code) && raltDown) {
        if (state = 1) {
            if (GetKeyState("Shift")) {
                ; Live-tested on real BE hardware: Shift+AltGr produces
                ; no character for any of these keys - suppress.
                return
            }
            if (code = 40 || code = 43 || code = 53) {
                ; ´, `, ~ under AltGr are dead keys - arm, don't send
                ; yet. Resolved against the next keypress at the top
                ; of this function. (Code 26 is also in deadKeySymbol,
                ; but only its non-AltGr behavior is a dead key - its
                ; AltGr behavior, "[", is not, so it's excluded here.)
                pendingDeadKey := deadKeySymbol[code]
                suppressReleaseCode := code
                return
            }
            info := altGrInfo[code]
            if (info.nativeCode = 0) {
                SendText(info.text)
            } else {
                if (info.nativeShift)
                    AHI.SendKeyEvent(tpId, 42, 1)
                AHI.SendKeyEvent(tpId, info.nativeCode, 1)
                AHI.SendKeyEvent(tpId, info.nativeCode, 0)
                if (info.nativeShift)
                    AHI.SendKeyEvent(tpId, 42, 0)
            }
        }
        return
    }

    if (digitInfo.Has(code)) {
        if (state = 1) {
            realShift := GetKeyState("Shift")
            if (realShift) {
                AHI.SendKeyEvent(tpId, 42, 0)
                AHI.SendKeyEvent(tpId, code, 1)
                AHI.SendKeyEvent(tpId, code, 0)
                AHI.SendKeyEvent(tpId, 42, 1)
            } else {
                info := digitInfo[code]
                if (info.nativeCode = 0) {
                    SendText(info.text)
                } else {
                    if (info.nativeShift)
                        AHI.SendKeyEvent(tpId, 42, 1)
                    AHI.SendKeyEvent(tpId, info.nativeCode, 1)
                    AHI.SendKeyEvent(tpId, info.nativeCode, 0)
                    if (info.nativeShift)
                        AHI.SendKeyEvent(tpId, 42, 0)
                }
            }
        }
        return
    }

    if (punctInfo.Has(code)) {
        if (state = 1) {
            realShift := GetKeyState("Shift")
            if (code = 26 && !realShift) {
                ; ^ (unshifted, no AltGr) is a dead key - arm, don't
                ; send yet. Shifted (¨) is unaffected, still sent
                ; immediately below as before.
                pendingDeadKey := deadKeySymbol[26]
                suppressReleaseCode := code
                return
            }
            entry := punctInfo[code]
            chosen := realShift ? entry.shft : entry.base
            if (chosen.code = 0) {
                SendText(chosen.text)
            } else {
                needShift := chosen.shift
                if (needShift != realShift)
                    AHI.SendKeyEvent(tpId, 42, needShift ? 1 : 0)
                AHI.SendKeyEvent(tpId, chosen.code, 1)
                AHI.SendKeyEvent(tpId, chosen.code, 0)
                if (needShift != realShift)
                    AHI.SendKeyEvent(tpId, 42, realShift ? 1 : 0)
            }
        }
        return
    }

    ; Everything else (Shift, Ctrl, Alt, Win, CapsLock, Tab, Enter,
    ; Backspace, Space, Esc, arrows, F-keys, Insert, Delete, numpad,
    ; etc.) is not layout-dependent - replay the identical physical
    ; key event.
    AHI.SendKeyEvent(tpId, code, state)
}
