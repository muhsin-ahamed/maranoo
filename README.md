# Maranoo? 🛒 

[![Flutter Web Deployment](https://img.shields.io/badge/Live-Web%20Demo-vibrantgreen)](https://maranoo.vercel.app/)
[![Platform](https://img.shields.io/badge/platform-Android%20|%20iOS%20|%20Web-blue.svg)](https://flutter.dev)
[![Database](https://img.shields.io/badge/Storage-Hive%20CE-orange)](https://pub.dev/packages/hive_ce)

**Maranoo** (from the Malayalam word *"മറന്നോ?"* meaning *"Did you forget?"*) is a premium, lightweight, privacy-first shopping and task list application designed for modern mobile and desktop web browsers. 

Built using Flutter's modern **Material 3** guidelines, Maranoo combines local utility with a high-fidelity user interface to ensure you never miss an item during your local town runs.

---

## ✨ Features

- **Fluid Master-Detail Flow:** Quickly create broad shopping categories on your dashboard, and jump inside them to add or extend items on the fly.
- **Soothing UI Aesthetics:** Features a premium Dark Mode (deep charcoal background `#121212`) and crisp Light Mode. Each master list is decorated with a soft, low-opacity pastel emerald green circular icon badge for quick, comfortable scannability.
- **Intuitive Gestures & CRUD:**
  - **Swipe Right:** Triggers an inline dialog box to quickly edit/rename the item.
  - **Swipe Left:** Brings up a destructive slide animation backed by a modern `delete_outline_rounded` confirmation modal.
  - **Tap Toggle:** Instantly checkboxes an item, dimming its opacity to 50% with a clean text strikethrough.
  - **Manual Fallbacks:** Dedicated icon buttons on the trailing edge of every tile for simple tap controls.
- **Digital Receipt & Bill Management:** Dedicated persistent action bar at the bottom allows you to take a photo of your shop invoice using your camera or upload it from your gallery. View a high-resolution full-screen modal preview of your uploaded receipt anytime.
- **100% Offline & Private:** Powered by the ultra-fast local database engine `hive_ce`. No accounts required, no cloud syncing, and zero tracking. Your lists and bill paths stay inside your device sandbox or browser's `IndexedDB`.

---

## 🛠️ Project Architecture

```text
maranoo/
├── lib/
│   └── main.dart             <── [CRUCIAL] Contains Models, Adapters, UI Screens & Logic
├── assets/
│   └── app_icon.png          <── Your custom emerald green app logo
├── pubspec.yaml              <── Packages Configuration (hive_ce, image_picker, google_fonts)
├── android/
│   └── app/src/main/
│       └── AndroidManifest.xml <── Native Android Permissions (Camera & Media)
└── ios/
    └── Runner/
        └── Info.plist        <── Native iOS Permissions Configuration
        
                                              └──> iOS (File Sandbox)
                                              └──> Android (Secure App Storage)
```
## 🏗️ Core Architecture Diagram
    ┌─────────────────────────────────────────────────────────┐
       │             User Interface Layer (Material 3)           │
       │  [AppBar Branded Text] [List Cards] [Checkboxes] [FAB]  │
       └────────────────────────────┬────────────────────────────┘
                                    │
                       (User Input / Gesture Intercept)
                                    │
                                    ▼
       ┌─────────────────────────────────────────────────────────┐
       │             State & Business Logic Layer                │
       │      [ChangeNotifier / ValueNotifier Listeners]         │
       └───────────────┬─────────────────────────┬───────────────┘
                       │                         │
            (Pick Receipt Attachment)     (Trigger Data Sync)
                       │                         │
                       ▼                         ▼
       ┌────────────────────────┐       ┌────────────────────────┐
       │     Image Picker API   │       │   Hive Box Controller  │
       │    (Camera / Gallery)  │       │  (Nested CRUD Engine)  │
       └───────────────┬────────┘       └────────────┬───────────┘
                       │                             │
              (Saves File Path)               (Persists Data)
                       │                             │
                       ▼                             ▼
       ┌─────────────────────────────────────────────────────────┐
       │           Device Sandbox / Persistent Storage           │
       └──────┬──────────────────────┬──────────────────────┬────┘
              │                      │                      │
              ▼                      ▼                      ▼
         [Android]                 [iOS]                  [Web]
   (SQLite / App Folder)     (NSDocumentDirectory)    (IndexedDB)
