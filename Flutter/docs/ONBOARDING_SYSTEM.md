# 🚀 ONBOARDING_SYSTEM.md

## Version 1.0.0

---

# Overview

The **Farvixo Onboarding System** is designed to introduce new users to the platform, personalize their experience, request essential permissions, and guide them toward authentication or the Home Dashboard.

The onboarding experience should be fast, engaging, responsive, and skippable while maintaining a premium Material Design 3 interface.

---

# Objectives

* Create an excellent first impression
* Explain Farvixo's core features
* Personalize the user experience
* Request permissions at the right time
* Increase user retention
* Reduce onboarding friction
* Support Android, iOS, Tablets, and Foldables

---

# User Flow

```text
App Launch
     │
     ▼
Welcome
     │
     ▼
Feature Highlights
     │
     ▼
AI Assistant Introduction
     │
     ▼
Choose Theme
     │
     ▼
Choose Language
     │
     ▼
Permissions (Optional)
     │
     ▼
Login / Sign Up / Continue as Guest
     │
     ▼
Home Dashboard
```

---

# Screen Structure

### Screen 1 — Welcome

Purpose

* Welcome the user
* Display Farvixo branding
* Introduce the platform

UI

* Animated Logo
* Welcome Title
* Short Description
* Get Started Button
* Skip Button

---

### Screen 2 — Features

Show major capabilities.

Example

* AI Assistant
* Smart Tools
* Fast Performance
* Cloud Sync
* Secure Storage
* Offline Support

---

### Screen 3 — Personalization

Allow users to customize:

* Light Theme
* Dark Theme
* System Theme
* Preferred Language

Selections should be saved automatically.

---

### Screen 4 — Permissions

Request only necessary permissions.

Examples

* Notifications
* Camera
* Storage
* Photos
* Microphone
* Location (if required)

Permissions should be requested only when needed.

---

### Screen 5 — Authentication

Options

* Sign In
* Sign Up
* Continue as Guest

Returning users should skip onboarding automatically.

---

# Navigation Rules

* First Launch → Show Onboarding
* Returning User → Skip Onboarding
* Logged In → Dashboard
* Guest Mode → Dashboard (Limited Features)

---

# UI Guidelines

Follow Material Design 3.

Use:

* Rounded Cards
* Filled Buttons
* Adaptive Layout
* Modern Icons
* Glassmorphism (Optional)
* Soft Shadows
* Smooth Motion

---

# Animation

Recommended sequence

```text
Fade In
↓
Slide Up
↓
Scale
↓
Glow
↓
Next Screen
```

Transition Duration

* 300–500 ms

Target Refresh Rate

* 60 FPS
* 90 FPS
* 120 FPS (Supported Devices)

---

# Responsive Design

Support

* Android
* iPhone
* Tablet
* Foldable
* Portrait
* Landscape

Safe Area

* Fully Supported

---

# Accessibility

* Screen Reader Support
* Large Text
* High Contrast
* Reduced Motion
* Color-Blind Friendly
* Accessible Touch Targets

---

# Performance Targets

| Metric            | Target        |
| ----------------- | ------------- |
| Screen Transition | ≤ 300 ms      |
| Animation         | 60/90/120 FPS |
| Memory Usage      | Optimized     |
| Startup Delay     | None          |
| UI Lag            | Zero          |

---

# Security

* Store onboarding completion securely.
* Encrypt user preferences.
* Never store sensitive information in plain text.
* Validate authentication before routing.

---

# Best Practices

* Keep onboarding under 5 screens.
* Allow users to skip onboarding.
* Explain value, not every feature.
* Use simple and concise text.
* Optimize images and animations.
* Load assets lazily.
* Keep transitions smooth.
* Maintain consistent Farvixo branding.

---

# Testing Checklist

* First launch shows onboarding.
* Returning users skip onboarding.
* Theme selection works.
* Language selection persists.
* Permissions behave correctly.
* Login navigation is correct.
* Guest mode works.
* No animation lag.
* Responsive on all supported devices.

---

# Success Criteria

The Onboarding System is successful when:

* Users understand Farvixo's value quickly.
* Navigation is seamless.
* Personalization is saved.
* Authentication flow is reliable.
* Performance remains smooth.
* The experience is accessible and consistent across all devices.

---

# Final Summary

The Farvixo Onboarding System provides a modern, premium, and production-ready first-time user experience. It combines intuitive navigation, personalization, adaptive performance, secure preference storage, and Material Design 3 principles to ensure users can start using the application quickly while understanding its key features.

---

# Implementation Map

| Spec Section | Implementation |
| --- | --- |
| Screens 1–5 | `lib/features/onboarding/onboarding_screen.dart` — Welcome, Features, Personalization, Permissions, Authentication |
| Theme personalization | `themeModeProvider` — persisted instantly via `StorageService.setThemeMode` |
| Language personalization | `lib/providers/language_provider.dart` + `StorageService.language` (en, हिन्दी, اردو, العربية, Español) |
| Permissions | Informational page — actual requests deferred until a tool needs them (per spec) |
| Skip / navigation rules | Skip → `/login`; `SplashController._decideRoute()` skips onboarding for returning users |
| Guest mode | `AuthNotifier.continueAsGuest()` → `/home` |
| Animation | One-shot fade + slide-up per page (`_PageShell`), 300 ms page transitions, reduced-motion aware |
| Responsive | Content constrained to 480 px, scrollable for large text, safe-area supported |
| Testing | `test/widget_test.dart` — first launch shows onboarding |
