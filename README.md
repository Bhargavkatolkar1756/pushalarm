# PushAlarm

> The alarm you can't snooze — you have to earn it.

PushAlarm is a native iOS alarm app (Swift/SwiftUI, iOS 16+) that uses your iPhone's front camera and Apple's Vision framework to count push-up repetitions. The alarm will not stop until you complete your push-up target.

---

## Project Structure

```
PushAlarm.xcodeproj/          ← Xcode project (open this)
PushAlarm/
  PushAlarmApp.swift          ← @main app entry point
  App/
    ContentView.swift         ← Root router (onboarding / tabs / challenge)
  Models/
    Alarm.swift               ← Alarm data model
    Settings.swift            ← AppSettings + DifficultyPreset
    ChallengeResult.swift     ← Completed-challenge history record
  Services/
    PersistenceService.swift  ← AlarmStore / SettingsStore / HistoryStore
    AlarmScheduler.swift      ← UNUserNotificationCenter wrapper
    AudioService.swift        ← AVAudioPlayer ringtone management
    PoseCounterService.swift  ← AVCaptureSession + Vision pose counting
  ViewModels/
    AlarmListViewModel.swift  ← Bridges store ↔ scheduler for alarm CRUD
    ChallengeViewModel.swift  ← Coordinates camera + audio for challenge
  Views/
    AlarmListView.swift       ← Main alarm list (tab 1)
    AlarmEditorView.swift     ← Create/edit alarm sheet
    ChallengeView.swift       ← Full-screen push-up challenge
    OnboardingView.swift      ← First-launch 3-page flow
    SettingsView.swift        ← Settings + history (tab 2)
    Components/
      CameraPreviewView.swift ← UIViewRepresentable for AVPreviewLayer
      DayToggleView.swift     ← Mon–Sun chip selector
      RepCounterView.swift    ← Circular progress ring + counter
  Info.plist                  ← NSCameraUsageDescription, UIBackgroundModes
  PushAlarm.entitlements      ← Standard (no critical-alerts entitlement)
  Resources/
    Assets.xcassets/          ← AppIcon + AccentColor
    Ringtones/                ← Drop .caf audio files here (see README inside)
PushAlarmTests/
  RepCountingTests.swift      ← Unit tests: angle math + state machine
  AlarmSchedulerTests.swift   ← Unit tests: next-fire-date + time strings
landing-page/
  index.html                  ← Marketing landing page (deploy to any static host)
  style.css
PRIVACY_POLICY.md
README.md                     ← This file
```

---

## Quick Start (macOS + Xcode required)

1. **Open the project:**
   ```
   open PushAlarm.xcodeproj
   ```

2. **Set your Team ID:**
   Select the `PushAlarm` target → Signing & Capabilities → change **Team** to your Apple Developer account.
   The bundle ID `com.pushalarm.app` is pre-filled; change it if needed.

3. **Add ringtone audio files:**
   Drop `.caf` files into `PushAlarm/Resources/Ringtones/` — see [`README_AUDIO.md`](PushAlarm/Resources/Ringtones/README_AUDIO.md) for filenames and conversion instructions. The app falls back to a system sound if files are missing.

4. **Add your App Icon:**
   Replace `PushAlarm/Resources/Assets.xcassets/AppIcon.appiconset/` with your 1024×1024 PNG icon.

5. **Build and run on a real device:**
   Camera-based features require a physical iPhone — the Simulator has no front camera.
   ```
   # Or from the command line:
   xcodebuild -scheme PushAlarm -destination 'platform=iOS,id=<YOUR_DEVICE_UUID>' build
   ```

6. **Run unit tests:**
   ```
   xcodebuild test -scheme PushAlarmTests -destination 'platform=iOS Simulator,name=iPhone 15'
   ```

---

## App Store Connect Submission Checklist

Follow these steps in order after the app builds and runs correctly on a device.

### Phase 1 — Developer Account & App Record

- [ ] Log in to [App Store Connect](https://appstoreconnect.apple.com).
- [ ] **My Apps → + → New App**.
  - Platform: iOS
  - Name: PushAlarm
  - Primary Language: English
  - Bundle ID: `com.pushalarm.app` (must match your provisioning profile)
  - SKU: `pushalarm-001`
- [ ] Set the **Age Rating** to 4+ (no objectionable content).

### Phase 2 — App Information

- [ ] **Category:** Health & Fitness (primary), Lifestyle (secondary).
- [ ] **Privacy Policy URL:** Host the landing page and provide the `#privacy` URL (e.g. `https://pushalarm.app/#privacy`). **This is required since the app uses the camera.**
- [ ] **App Description** (up to 4,000 chars): explain the push-up alarm concept, emphasise on-device processing.
- [ ] **Keywords:** alarm, push-ups, fitness alarm, wake up, morning workout, no snooze
- [ ] **Support URL:** `https://pushalarm.app/#support` (or your support email page).

### Phase 3 — Screenshots

Capture screenshots on:
- iPhone 6.7" (iPhone 15 Pro Max / 14 Pro Max) — **required**
- iPhone 6.1" (iPhone 15 / 14) — recommended
- iPad 12.9" (if you support iPad) — required if `TARGETED_DEVICE_FAMILY` includes iPad

Recommended shots:
1. Alarm list screen
2. Alarm editor (showing day pickers + push-up stepper)
3. Onboarding / welcome screen
4. Challenge screen (camera open, rep counter visible)
5. Settings screen with streak banner

### Phase 4 — Build & Upload

```bash
# Archive in Xcode: Product → Archive
# Then: Organizer → Distribute App → App Store Connect → Upload

# Or via command line:
xcodebuild archive \
  -scheme PushAlarm \
  -archivePath build/PushAlarm.xcarchive \
  -destination generic/platform=iOS

xcodebuild -exportArchive \
  -archivePath build/PushAlarm.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist ExportOptions.plist
```

### Phase 5 — TestFlight (Internal)

- [ ] Select your uploaded build in App Store Connect → TestFlight.
- [ ] Add internal testers (up to 100 users with your team).
- [ ] Test on real devices: alarm fires → notification tapped → challenge opens → push-ups counted → alarm stops.

### Phase 6 — Review Submission Notes

In App Store Connect → App Review → Notes, include:

```
Camera Usage:
PushAlarm uses the front-facing camera exclusively to count push-up 
repetitions using Apple's Vision framework (VNDetectHumanBodyPoseRequest).
Camera frames are processed on-device and are immediately discarded —
no frames are ever stored to disk or transmitted over any network.
The only output that leaves the camera pipeline is a numeric rep count.

To test the push-up detection:
1. Launch the app.
2. Tap + to create an alarm, set it 2 minutes from now, tap Save.
3. When the alarm fires, tap the notification.
4. Place the device 1–2 metres away and perform push-ups.
   The counter increments on each complete down-then-up cycle.
5. On reaching the target, the alarm sound stops automatically.
```

### Phase 7 — Submit for Review

- [ ] Select the build in App Store Connect.
- [ ] Answer the export compliance questionnaire (no encryption → "No").
- [ ] Answer the advertising identifier question (no IDFA → "No").
- [ ] Submit for review. Typical review time: 24–48 hours.

---

## Architecture Notes

- **No backend.** All data is stored on-device. Zero network calls at runtime.
- **Persistence.** `AlarmStore` writes JSON to `<AppSupport>/PushAlarm/alarms.json`. `SettingsStore` uses `UserDefaults`. `HistoryStore` writes JSON to `<AppSupport>/PushAlarm/history.json`.
- **Pose detection.** `PoseCounterService` runs `VNDetectHumanBodyPoseRequest` on a dedicated `DispatchQueue` (`.userInitiated` QoS). UI state is published to the main thread via `DispatchQueue.main.async`.
- **Rep counting state machine.** Requires 4 consecutive frames below 90° to enter "down" state, and 4 consecutive frames above 155° (from "down") to count a rep. This prevents false counts from noisy frames.
- **Audio.** `AVAudioSession` category `.playback` lets the ringtone play even when the mute switch is on. The `audio` background mode (set in Info.plist) lets it continue briefly if the user backgrounds the app momentarily.
- **Notifications.** `UNCalendarNotificationTrigger` schedules alarms. Notification taps post `Notification.Name.didReceiveAlarmNotification` via `NotificationCenter`, which `ContentView` observes to present `ChallengeView` as a `fullScreenCover`.

---

## Stretch Goals (post-MVP)

| Goal | Notes |
|---|---|
| Streak charts | `Charts` framework, iOS 16+. Add a `HistoryChartView` tab. |
| Home Screen Widget | `WidgetKit` — show next alarm + streak count. |
| Apple Watch companion | `WatchConnectivity` — relay rep count to Watch face. |
| Critical Alerts entitlement | Submit request at developer.apple.com/contact/request. Adds sound override for silent mode. |
| Social leaderboard | Requires a server (Vapor, Firebase, Supabase). Update privacy policy if added. |

---

## Privacy

All camera processing is on-device. No analytics. No ads. No third-party SDKs.
Full policy: [`PRIVACY_POLICY.md`](PRIVACY_POLICY.md) / `landing-page/index.html#privacy`.
