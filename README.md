# FOCUS — Personal OS

> **A minimal, local-first Personal Operating System for mobile and desktop.**
> Built with Flutter, 100% offline SQLite persistence, Nothing OS dark monochrome minimalism, and Apple-grade frosted glass squircle aesthetics.

---

## 🚀 Overview

**FOCUS** is an offline productivity system engineered without cloud surveillance, without conversational AI overhead, and without data lock-in.

### 🌟 Key Capabilities

- **Phase 5 Critical Task & Alert Engine**:
  - Deterministic 10-state lifecycle (`PENDING` → `SCHEDULED` → `TRIGGERING` → `TRIGGERED` → `ACKNOWLEDGED` / `SNOOZED` / `DISMISSED` / `COMPLETED` / `FAILED` / `DEAD_LETTER`).
  - Persistent Outbox architecture preventing alert drops across system restarts.
  - Optimistic revision locking for atomic updates.
- **Phase 7 Focus Guard (Digital Wellbeing)**:
  - Non-coercive intervention screen with 4 immediate exit choices (*Accept & Switch*, *Snooze 5m*, *Emergency Bypass*, *Modify Policy*).
  - Safe foreground package observation (`canRetrieveWindowContent="false"` in AccessibilityService configuration).
  - Zero keystroke logging, zero screen scraping, zero network traffic.
  - 30-day auto-purged audit log.
- **Outside-of-App Home Screen Widgets**:
  - Android home screen app widgets for Timer, Tasks, Habits, and Daily Overview.
  - iOS WidgetKit extension support.
- **Stage 6 Offline Backup & Restore**:
  - 1-tap clipboard JSON export and schema-validated atomic restore.
- **Design System**:
  - Nothing OS high-contrast dark monochrome typography & dot-matrix accents.
  - Apple squircle frosted glass containers with backdrop blur.

---

## 📦 Multi-Platform Releases & Variants

Every release on GitHub includes 3 ready-to-run variants:

1. **Android**: `FOCUS-Android-v1.0.0.apk`
   - Direct sideloadable release APK for any Android phone.
2. **Windows Desktop**: `FOCUS-Windows-v1.0.0.zip`
   - Standalone portable Windows desktop app bundle containing `focus_app.exe`.
3. **iOS**: `FOCUS-iOS-v1.0.0.ipa` / `Runner.xcarchive`
   - iOS application archive ready for Xcode or test device deployment.

---

## 🛠️ Development & Testing

### Running Tests
```bash
flutter test
```
*Current test suite: 23/23 unit and integration tests passing.*

### Static Analysis
```bash
flutter analyze
```
*0 issues found.*

### Building Production Binaries

- **Android Release APK**:
  ```bash
  flutter build apk --release
  ```
- **Windows Release Bundle**:
  ```bash
  flutter build windows --release
  ```
- **iOS IPA (on macOS)**:
  ```bash
  flutter build ipa --no-codesign
  ```

---

## 🔒 Privacy & Local-First Architecture

All user tasks, habits, focus logs, and settings are stored strictly on-device in a local SQLite database (`drift`/`sqlite3`). The application requires no external cloud account, communicates with no analytics servers, and operates flawlessly in complete airplane mode.
