# PushAlarm — Privacy Policy

**Effective date:** 2025-01-01

---

## 1. Who we are

PushAlarm ("the app") is a solo-developer iOS application. For privacy inquiries, contact us at **support@pushalarm.app**.

---

## 2. Information we collect — and don't collect

### 2.1 Camera

PushAlarm requests access to your device's **front-facing camera** for one purpose only: to count push-up repetitions in real time.

- Camera frames are passed to Apple's **Vision framework** (`VNDetectHumanBodyPoseRequest`) running entirely on your device.
- **Frames are never written to disk.**
- **Frames are never transmitted over any network.**
- **Frames are never shared with any third party.**
- The only output that leaves the camera pipeline is a **numeric rep count** (e.g. "7").

You can revoke camera access at any time in **iOS Settings → Privacy & Security → Camera → PushAlarm**.

### 2.2 Local notifications

PushAlarm uses iOS local notifications (`UNUserNotificationCenter`) to fire alarms at scheduled times.

- Notifications are scheduled **entirely on your device**.
- No notification content, alarm times, or user data are ever sent to a server.

### 2.3 Alarm & settings data

Your alarms, settings, and push-up challenge history are stored locally in the app's sandboxed directory on your device (`Application Support/PushAlarm/`).

- This data is included in standard **iCloud Backup** if you have that feature enabled in iOS Settings. It is not accessible to us.
- You can delete all data by deleting the app.

### 2.4 Analytics & crash reporting

PushAlarm contains **no analytics SDK, no advertising SDK, and no crash-reporting SDK** that transmits data off-device. The app makes **zero outbound network connections** during normal operation.

### 2.5 Identifiers

PushAlarm does not read or use your Advertising Identifier (IDFA), Apple ID, email address, name, phone number, or any other personal identifier.

---

## 3. Third-party libraries

PushAlarm uses **no third-party libraries or frameworks**. All functionality is implemented using Apple's first-party SDKs:

- SwiftUI
- AVFoundation (AVAudioSession, AVCaptureSession)
- Vision (VNDetectHumanBodyPoseRequest)
- UserNotifications (UNUserNotificationCenter)
- AudioToolbox

---

## 4. Children

PushAlarm does not knowingly collect personal information from anyone, including children under 13. Because all data remains on-device and nothing is transmitted, there is no personal data for us to collect.

---

## 5. Data retention & deletion

All data is stored locally on your device. To permanently delete all PushAlarm data:

1. Go to **iOS Settings → General → iPhone Storage → PushAlarm → Delete App**.

This removes the app, all alarms, settings, and challenge history from your device.

---

## 6. Your rights

Depending on your jurisdiction, you may have rights to access, correct, or delete personal data held about you. Because PushAlarm holds no personal data on any server, all data is already under your direct control on your own device.

---

## 7. Changes to this policy

If this privacy policy changes materially, we will update this document and the **Effective date** above. Continued use of the app after such a change constitutes acceptance of the revised policy.

---

## 8. Contact

**Email:** support@pushalarm.app  
**Web:** https://pushalarm.app/#privacy
