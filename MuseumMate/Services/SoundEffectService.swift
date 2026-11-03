//
//  SoundEffectService.swift
//  MuseumMate
//
//  Lightweight transition sound effects using iOS system sounds.
//  All calls are fire-and-forget — no player state to manage.
//
//  System sound IDs used (always available on iOS, no files needed):
//    1519 — "peek"   : subtle tap for tab/navigation changes
//    1520 — "pop"    : heavier tap for confirmations
//    1104 — shutter  : camera capture
//    1001 — chime up : success / scan complete
//    1006 — chime    : error / dismiss
//    1057 — lock     : saving / storing
//

import AudioToolbox

enum SoundEffect {

    // Tab change — very subtle
    static func tabChange() {
        AudioServicesPlaySystemSound(1519)
    }

    // Scan triggered (camera shutter feel)
    static func scanCapture() {
        AudioServicesPlaySystemSound(1519)
    }

    // Scan complete — success chime
    static func scanSuccess() {
        AudioServicesPlaySystemSound(1001)
    }

    // Error / dismiss
    static func error() {
        AudioServicesPlaySystemSound(1006)
    }

    // Item saved / favorited
    static func saved() {
        AudioServicesPlaySystemSound(1057)
    }

    // Sheet opened (gentle)
    static func sheetOpen() {
        AudioServicesPlaySystemSound(1520)
    }

    // Navigation push/pop
    static func navigation() {
        AudioServicesPlaySystemSound(1519)
    }
}
