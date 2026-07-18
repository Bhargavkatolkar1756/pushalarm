# Ringtone Audio Files

Place your ringtone `.caf` files here. The filenames must **exactly** match the `RingtoneType.fileName` values:

| Expected filename       | Display name       |
|-------------------------|--------------------|
| `Siren.caf`             | Siren              |
| `AirHorn.caf`           | Air Horn           |
| `DrillSergeant.caf`     | Drill Sergeant     |
| `Foghorn.caf`           | Foghorn            |
| `EmergencyBeacon.caf`   | Emergency Beacon   |

## How to Convert Audio to .caf

```bash
# On macOS, use afconvert (built-in)
afconvert -f caff -d LEI16@44100 input.mp3 Siren.caf
```

## Royalty-Free Sources

- **Freesound.org** (Creative Commons) — search "alarm siren", "air horn", etc.
- **Zapsplat.com** — free with free account, attribution required for some packs.
- **Apple's built-in system sounds** — located at `/System/Library/Audio/UISounds/` on a Mac or iOS device (not redistributable, for reference only).

## Fallback Behaviour

If a `.caf` file is not found in the bundle, `AudioService.play()` falls back to a system sound (AudioServicesPlaySystemSound 1005) so the app never crashes silently.
