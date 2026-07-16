# 🚀 LAUNCH_SPLASH_SYSTEM.md

# Part 1 — Foundation & Architecture

---

# Document Information

| Property   | Value                        |
| ---------- | ---------------------------- |
| Project    | Farvixo                      |
| Module     | Launch & Splash System       |
| Version    | v1.0.0                       |
| Status     | Production Ready             |
| Platform   | Flutter • Android • iOS      |
| UI         | Material Design 3            |
| Target FPS | Adaptive (60 / 90 / 120 FPS) |
| Theme      | Light & Dark                 |

---

# Overview

The **Launch & Splash System** provides the first user experience of the Farvixo application. It is designed to deliver an instant, smooth, and premium startup while preparing all essential services in the background.

The startup experience consists of two stages:

1. **Native Launch Screen** – Displayed instantly by Android/iOS.
2. **Flutter Splash Screen** – Initializes the application and routes the user.

---

# Objectives

* Instant startup
* Premium branding
* Fast initialization
* Smooth animations
* Secure startup flow
* Responsive design
* Battery-efficient performance
* Scalable architecture

---

# Startup Flow

```text
User Opens App
      │
      ▼
Native Launch Screen
      │
      ▼
Flutter Engine
      │
      ▼
Splash Screen
      │
      ▼
Initialize Services
      │
      ▼
Authentication Check
      │
      ▼
Dashboard / Login / Onboarding
```

---

# Core Architecture

```text
Operating System
        │
        ▼
Native Launch
        │
        ▼
Flutter Engine
        │
        ▼
Splash Controller
        │
        ▼
Initialization Manager
        │
        ▼
Navigation Router
        │
        ▼
Application
```

---

# Native Launch Screen

Responsibilities:

* Display instantly
* Show Farvixo logo
* Match system theme
* Hide engine startup delay
* No business logic
* No network requests
* No heavy animations

---

# Flutter Splash Screen

Responsibilities:

* Load app configuration
* Restore user session
* Initialize local database
* Load theme & language
* Check authentication
* Check internet connection
* Initialize AI services
* Navigate to the correct screen

---

# Startup Modes

### Cold Start

* Full application launch
* Target: **≤ 2 seconds**

### Warm Start

* Resume from memory
* Target: **≤ 800 ms**

### Hot Resume

* Return from background
* Target: **≤ 300 ms**

---

# Folder Structure

```text
lib/
 ├── core/
 ├── launch/
 ├── splash/
 ├── services/
 ├── navigation/
 ├── auth/
 ├── database/
 ├── theme/
 └── ui/

assets/
 ├── images/
 ├── icons/
 ├── animations/
 └── fonts/
```

---

# Branding

### Logo

* SVG preferred
* Center aligned
* Adaptive size
* High resolution

### Background

* Premium gradient
* Soft glow
* Minimal design
* Dark & Light support

---

# Performance Targets

| Metric        | Target                         |
| ------------- | ------------------------------ |
| Native Launch | < 100 ms                       |
| Cold Start    | ≤ 2 sec                        |
| Warm Start    | ≤ 800 ms                       |
| Hot Resume    | ≤ 300 ms                       |
| FPS           | **Adaptive 60 / 90 / 120 FPS** |
| Frame Drops   | Zero                           |
| UI Lag        | None                           |

---

# Design Principles

* Fast
* Minimal
* Modern
* Consistent
* Accessible
* Scalable
* Reliable

---

# Best Practices

* Keep the native launch screen lightweight.
* Perform initialization only in the Flutter splash.
* Load services asynchronously.
* Never block the UI thread.
* Use adaptive refresh rates (60/90/120Hz).
* Cache frequently used resources.
* Handle initialization failures gracefully.

---

# Part 1 Summary

This section defines the foundation of the Farvixo Launch & Splash System, including startup architecture, lifecycle, responsibilities, branding, performance goals, and design principles.

**Next:** **Part 2 — Native Launch UI & Flutter Splash Design**, covering Android Splash API, iOS Launch Screen, logo animations, Material 3 UI, adaptive layouts, transitions, and motion system.
# 🚀 LAUNCH_SPLASH_SYSTEM.md

# Part 2 — Native Launch UI & Flutter Splash Design

---

# Native Launch Screen

## Purpose

The Native Launch Screen is displayed immediately by the operating system before the Flutter engine starts. It should provide a seamless and premium first impression while hiding application startup time.

---

# Android Launch

### Android 12+

* Android SplashScreen API
* Adaptive App Icon
* Material 3 Support
* Dynamic Color Support
* Edge-to-Edge Layout
* Light & Dark Theme Support

### Android Below 12

* Custom Splash Theme
* Static Brand Background
* Center Logo
* Fast Transition to Flutter

---

# iOS Launch Screen

The iOS Launch Screen should follow Apple's Human Interface Guidelines.

### Features

* LaunchScreen.storyboard
* Center Logo
* Adaptive Layout
* Auto Layout Constraints
* Safe Area Support
* Light & Dark Mode

---

# Flutter Splash Screen

## Purpose

The Flutter Splash Screen starts immediately after the Flutter engine initializes.

Responsibilities include:

* Display branding
* Show loading animation
* Initialize application
* Route the user

---

# Splash Layout

```text
──────────────────────────────

           ✨

      FARVIXO LOGO

   Smart AI Ecosystem

   Initializing...

   ███████████░░░░

 Version 1.0.0

──────────────────────────────
```

---

# UI Components

### Header

* Empty
* Clean Layout

### Center

* Animated Logo
* Brand Name
* Tagline

### Bottom

* Progress Indicator
* Loading Message
* Version Number

---

# Logo Specification

| Property  | Value      |
| --------- | ---------- |
| Format    | SVG        |
| Quality   | Vector     |
| Alignment | Center     |
| Scale     | Responsive |
| Animation | Enabled    |

---

# Background Design

Recommended:

* Purple Gradient
* Blue Accent
* Glass Effect
* Soft Glow
* Radial Lighting
* Smooth Blur

Avoid:

* Heavy textures
* Bright flashing colors
* Busy backgrounds

---

# Color Palette

| Element    | Color            |
| ---------- | ---------------- |
| Primary    | Purple           |
| Secondary  | Blue             |
| Accent     | Cyan             |
| Background | Dark Gradient    |
| Text       | White / Adaptive |

---

# Typography

| Element      | Size     |
| ------------ | -------- |
| Logo         | 40–48 px |
| App Name     | 28 px    |
| Tagline      | 16 px    |
| Loading Text | 14 px    |
| Version      | 12 px    |

---

# Logo Animation

Animation Sequence:

```text
Invisible

↓

Fade In

↓

Scale Up

↓

Soft Glow

↓

Pulse

↓

Idle
```

Animation Duration:

* Fade : 400ms
* Scale : 500ms
* Glow : Continuous
* Pulse : Every 2 seconds

---

# Loading Indicator

Supported Types:

* Circular Loader
* Linear Progress
* AI Wave
* Orbit Loader
* Neural Pulse
* Gradient Progress Bar

Recommended:

**Animated Gradient Progress Bar**

---

# Loading Messages

Examples:

* Initializing...
* Preparing Workspace...
* Loading AI Engine...
* Syncing Settings...
* Almost Ready...

Messages should rotate automatically every 2–3 seconds.

---

# Transition

Transition to next screen:

* Fade
* Scale
* Slide
* Material Motion
* Hero Transition

Duration:

**300–500ms**

---

# Responsive Design

Supported Devices

* Android Phones
* Tablets
* Foldables
* iPhone
* iPad

Orientation

* Portrait
* Landscape

Safe Area

* Fully Supported

---

# Theme Support

### Light Theme

* White Background
* Dark Text
* Purple Accent

### Dark Theme

* Dark Gradient
* White Text
* Blue Glow

Theme should automatically follow system settings.

---

# Motion Guidelines

* Smooth animations
* No abrupt movement
* Material Motion
* Hardware Accelerated
* Adaptive Refresh Rate

Supported Refresh Rates:

* 60Hz
* 90Hz
* 120Hz

---

# Performance Targets

| Metric          | Target                     |
| --------------- | -------------------------- |
| Animation FPS   | Adaptive 60 / 90 / 120 FPS |
| Frame Drops     | Zero                       |
| Animation Delay | None                       |
| GPU Rendering   | Hardware Accelerated       |
| UI Response     | Instant                    |

---

# Accessibility

* Screen Reader Labels
* High Contrast
* Dynamic Font Support
* Reduced Motion Mode
* Color-Blind Friendly

---

# Best Practices

* Use SVG assets whenever possible.
* Keep animations smooth and lightweight.
* Do not delay startup unnecessarily.
* Match native and Flutter backgrounds to avoid flicker.
* Maintain consistent branding across Android and iOS.
* Optimize all assets for fast rendering.

---

# Part 2 Summary

This section defines the complete visual design of the Launch & Splash experience, including Android Native Splash, iOS Launch Screen, Flutter Splash UI, branding, animations, responsive layouts, adaptive refresh rates, and Material 3 design principles.

**Next:** **Part 3 — Initialization Engine & Startup Pipeline**, covering authentication, database initialization, AI engine startup, caching, remote configuration, session recovery, notifications, and navigation logic.
# 🚀 LAUNCH_SPLASH_SYSTEM.md

# Part 3 — Initialization Engine & Startup Pipeline

---

# Overview

The **Initialization Engine** prepares the Farvixo application before the user reaches the main interface. All critical services are loaded asynchronously to ensure a fast, secure, and reliable startup.

**Goals**

* Fast startup
* Parallel initialization
* Zero UI blocking
* Secure session recovery
* Stable navigation
* Offline readiness

---

# Startup Pipeline

```text
User Opens App
      │
      ▼
Flutter Engine Ready
      │
      ▼
Splash Controller
      │
      ▼
Initialization Manager
      │
      ▼
Critical Services
      │
      ▼
Authentication Check
      │
      ▼
Navigation Decision
      │
      ▼
Home / Login / Onboarding
```

---

# Initialization Priority

### Priority 1 — Critical

* App Configuration
* Secure Storage
* Crash Handler
* Local Settings
* Theme
* Language

---

### Priority 2 — Core

* Authentication
* Local Database
* Internet Status
* Cache Manager
* Session Recovery

---

### Priority 3 — Services

* AI Engine
* Notifications
* Analytics
* Remote Config
* Feature Flags

---

### Priority 4 — Background

* Image Cache
* Content Sync
* Update Check
* Recommendations
* Preloading Assets

---

# Initialization Flow

```text
Start

↓

Load Config

↓

Load Theme

↓

Load Language

↓

Initialize Database

↓

Restore Session

↓

Check Internet

↓

Initialize AI

↓

Load Remote Config

↓

Ready
```

---

# Authentication Flow

```text
User Exists?

↓

Yes

↓

Session Valid?

↓

Yes

↓

Dashboard

↓

No

↓

Login

↓

No Account

↓

Onboarding
```

---

# Local Database

Initialize:

* SQLite / Isar
* User Preferences
* Offline Data
* Recent Activity
* Cached AI Data

Requirements:

* Fast startup
* Automatic recovery
* Corruption detection
* Background optimization

---

# Secure Storage

Store securely:

* Login Token
* Refresh Token
* Session ID
* Encryption Keys
* User Preferences

Never store sensitive information in plain text.

---

# Session Recovery

On startup:

* Validate login token
* Refresh session if required
* Restore last state
* Recover navigation
* Handle expired sessions gracefully

---

# Internet Detection

Check:

* Internet availability
* Connection quality
* Offline mode
* Retry strategy

If offline:

* Load cached content
* Continue startup
* Notify user after launch

---

# AI Engine Initialization

Prepare:

* AI Models
* Prompt Manager
* Local AI Cache
* Vector Search
* AI Configuration

AI initialization should never block the UI.

---

# Cache Manager

Load:

* User Profile
* Recent Files
* Images
* Icons
* Frequently Used Data

Background cleanup:

* Remove expired cache
* Optimize storage
* Refresh metadata

---

# Remote Configuration

Download:

* Feature Flags
* App Settings
* Announcement Banner
* AI Configuration
* Experimental Features

Fallback:

Use locally cached configuration if the server is unavailable.

---

# Notifications

Initialize:

* Push Notifications
* Local Notifications
* Background Messages
* Deep Links

Do not request notification permission during startup unless necessary.

---

# Navigation Decision

```text
Splash

↓

Initialization Complete?

↓

Yes

↓

User Logged In?

↓

Yes

↓

Dashboard

↓

No

↓

Onboarding Completed?

↓

Yes

↓

Login

↓

No

↓

Onboarding
```

---

# Error Handling

If initialization fails:

* Retry automatically
* Log error
* Recover safely
* Continue where possible
* Show friendly error screen only if startup cannot continue

---

# Performance Targets

| Item              | Target     |
| ----------------- | ---------- |
| Config Load       | <100 ms    |
| Theme Load        | <50 ms     |
| Database Init     | <300 ms    |
| Session Restore   | <200 ms    |
| Internet Check    | <100 ms    |
| AI Initialization | Background |
| Total Startup     | ≤2 seconds |

---

# Security

* Secure storage encryption
* Session validation
* Token verification
* API key protection
* Root/Jailbreak awareness (optional)
* Tamper detection (optional)

---

# Best Practices

* Initialize critical services first.
* Run independent tasks in parallel.
* Never freeze the UI thread.
* Defer non-essential work until after the Home screen loads.
* Use cached data whenever possible.
* Fail gracefully and recover automatically.

---

# Part 3 Summary

This section defines the complete startup pipeline, including service initialization, authentication, local database, secure storage, AI engine preparation, remote configuration, cache management, navigation logic, performance targets, and error recovery.

**Next:** **Part 4 — Performance Optimization, Security, Accessibility & Quality Assurance**.
# 🚀 LAUNCH_SPLASH_SYSTEM.md

# Part 4 — Performance, Security & Quality Assurance

---

# Overview

The Launch & Splash System must provide a **fast, secure, stable, and premium startup experience** across Android and iOS while maintaining low resource usage and smooth animations.

---

# Performance Goals

| Metric               | Target    |
| -------------------- | --------- |
| Cold Start           | ≤ 2.0 sec |
| Warm Start           | ≤ 800 ms  |
| Hot Resume           | ≤ 300 ms  |
| Native Launch        | < 100 ms  |
| Startup Success Rate | 99.9%+    |
| App Crash Rate       | < 0.1%    |

---

# Rendering Performance

Target refresh rate should automatically adapt to the device.

| Refresh Rate  |  Target FPS |
| ------------- | ----------: |
| 60Hz Display  |      60 FPS |
| 90Hz Display  |      90 FPS |
| 120Hz Display | **120 FPS** |

Requirements:

* Zero visible lag
* Zero frame drops
* No animation stuttering
* Stable frame timing
* Hardware acceleration enabled

---

# Memory Optimization

The splash system should:

* Load only critical assets
* Use lazy loading
* Dispose unused resources
* Compress images
* Prefer SVG icons
* Cache frequently used assets

Target RAM during startup:

**≤ 150 MB**

---

# CPU Optimization

Use:

* Async initialization
* Parallel loading
* Background isolates
* Non-blocking operations
* Deferred initialization

Avoid:

* Heavy synchronous work
* Long loops on UI thread
* Large object creation during launch

---

# GPU Optimization

Recommended:

* Hardware rendering
* Minimal overdraw
* Lightweight gradients
* Efficient blur effects
* Optimized shadows
* Vector graphics

Avoid:

* Large transparent layers
* Heavy particle systems
* Multiple blur layers
* Excessive repainting

---

# Asset Optimization

Optimize:

* Images (WebP/AVIF where supported)
* SVG icons
* Fonts
* Animations
* Lottie files
* Audio (if any)

Preload only:

* Logo
* Essential fonts
* Primary colors
* Core animations

---

# Battery Efficiency

The launch process should:

* Minimize CPU wake-ups
* Avoid unnecessary background tasks
* Pause animations after navigation
* Limit GPU-intensive effects
* Respect battery saver mode

---

# Security

Validate during startup:

* Secure Storage
* Session Token
* App Signature
* API Configuration
* Certificate Integrity

Optional:

* Root Detection
* Jailbreak Detection
* Emulator Detection
* Tamper Detection

---

# Error Recovery

If an error occurs:

1. Retry silently.
2. Use cached configuration.
3. Continue with essential services.
4. Log diagnostics.
5. Show a user-friendly error screen only if startup cannot continue.

Never crash during initialization if recovery is possible.

---

# Logging

Record:

* Startup duration
* Initialization success/failure
* Navigation path
* Crash reports
* Performance metrics

Sensitive user information must never be logged.

---

# Analytics

Track:

* App Open
* Cold Start
* Warm Start
* Splash Duration
* Initialization Time
* Login Success
* Navigation Target

Use analytics only after user consent where required.

---

# Accessibility

Support:

* Screen readers
* Dynamic text sizes
* High-contrast mode
* Reduced motion
* Color-blind friendly palette
* Large touch targets

All launch UI should remain usable for every supported accessibility setting.

---

# Localization

The splash system should support:

* Multiple languages
* RTL layouts
* Localized loading messages
* Regional date/time formats
* Automatic language detection

---

# Quality Assurance Checklist

Before release, verify:

* Native launch appears instantly.
* Flutter splash transitions smoothly.
* No white or black flashes.
* No UI flicker.
* Theme changes correctly.
* Login routing works.
* Offline startup works.
* Animation remains smooth.
* Startup time meets targets.
* No memory leaks.

---

# Production Best Practices

* Keep native launch minimal.
* Initialize only critical services before navigation.
* Load secondary services after Home screen.
* Use adaptive refresh rates.
* Optimize all assets.
* Test on low-end and high-end devices.
* Maintain identical branding across Android and iOS.

---

# Common Mistakes to Avoid

❌ Artificial splash delays

❌ Blocking the UI thread

❌ Large uncompressed assets

❌ Heavy animations during startup

❌ Network dependency before UI appears

❌ Re-initializing services unnecessarily

❌ Excessive memory allocation

---

# Release Readiness

The Launch & Splash System is production-ready when:

* Startup is fast and stable.
* All critical services initialize successfully.
* Navigation is correct.
* Performance targets are achieved.
* Security validation passes.
* Accessibility requirements are met.
* No critical startup issues remain.

---

# Part 4 Summary

This section defines enterprise-grade performance optimization, adaptive **60/90/120 FPS** rendering, memory and GPU optimization, security validation, logging, analytics, accessibility, localization, quality assurance, and production best practices.

**Next:** **Part 5 — Final Production Guide, Complete Flow Diagrams, Testing Matrix, Release Checklist & Future Roadmap.**
# 🚀 LAUNCH_SPLASH_SYSTEM.md

# Part 5 — Production Guide, Release & Future Roadmap

---

# Overview

This final section completes the **Farvixo Launch & Splash System** by defining the complete production workflow, release requirements, testing strategy, monitoring, maintenance, and future enhancements.

---

# Complete Launch Flow

```text
User Taps App
        │
        ▼
Android/iOS Native Launch
        │
        ▼
Flutter Engine Initialization
        │
        ▼
Splash Screen UI
        │
        ▼
Load Configuration
        │
        ▼
Initialize Core Services
        │
        ▼
Restore Session
        │
        ▼
Authentication Check
        │
        ▼
Internet Check
        │
        ▼
Navigation Decision
        │
        ▼
Dashboard / Login / Onboarding
```

---

# Startup Timeline

| Stage               | Target Time |
| ------------------- | ----------- |
| Native Launch       | < 100 ms    |
| Flutter Engine      | < 400 ms    |
| Core Initialization | < 800 ms    |
| Session Restore     | < 200 ms    |
| Navigation          | < 100 ms    |
| Total Cold Start    | ≤ 2.0 sec   |

---

# Navigation Matrix

| Condition        | Destination             |
| ---------------- | ----------------------- |
| First Install    | Onboarding              |
| Logged In        | Dashboard               |
| Logged Out       | Login                   |
| Session Expired  | Login                   |
| Offline          | Dashboard (Cached Mode) |
| Force Update     | Update Screen           |
| Maintenance Mode | Maintenance Screen      |

---

# Startup Priority

### Critical

* App Configuration
* Theme
* Language
* Secure Storage
* Authentication

### High

* Database
* Cache
* Internet
* Remote Config

### Medium

* Notifications
* Analytics
* AI Services

### Background

* Image Cache
* Recommendations
* Asset Preloading
* Update Metadata

---

# Production Checklist

## UI

* Native splash displays instantly
* Logo centered correctly
* No flickering
* Smooth transition
* Adaptive layout
* Material 3 compliance

---

## Performance

* Cold start ≤ 2 sec
* Warm start ≤ 800 ms
* Hot resume ≤ 300 ms
* Adaptive 60/90/120 FPS
* No dropped frames
* Memory optimized

---

## Security

* Secure storage enabled
* Token validation
* API keys protected
* HTTPS enforced
* Sensitive logs disabled

---

## Functionality

* Theme loads correctly
* Language loads correctly
* Authentication works
* Offline mode works
* Session recovery works
* Navigation is correct

---

# Testing Matrix

| Device         | Status |
| -------------- | ------ |
| Android Phone  | ✅      |
| Android Tablet | ✅      |
| Foldable       | ✅      |
| iPhone         | ✅      |
| iPad           | ✅      |
| Portrait       | ✅      |
| Landscape      | ✅      |
| Dark Mode      | ✅      |
| Light Mode     | ✅      |
| Offline Mode   | ✅      |

---

# Monitoring

Track:

* Startup Time
* Splash Duration
* Crash Rate
* ANR Rate
* Memory Usage
* FPS
* Session Recovery Success
* Navigation Errors

---

# Maintenance

Regularly review:

* Startup performance
* Dependency updates
* Asset optimization
* Security patches
* Analytics reports
* Crash reports

---

# Future Roadmap

### Version 1.1

* Dynamic Splash Content
* Improved Asset Caching
* Faster Session Restore

### Version 1.2

* AI Startup Optimization
* Personalized Welcome Experience
* Smart Preloading

### Version 2.0

* Adaptive AI Launch Experience
* Cloud-Based Configuration
* Intelligent Startup Prediction
* Cross-Device Session Sync

---

# Developer Notes

* Keep the native launch screen lightweight.
* Never perform heavy work before the Flutter engine starts.
* Execute independent tasks in parallel.
* Defer non-essential services until after the Home screen.
* Optimize assets and animations for smooth rendering.
* Ensure startup remains reliable under poor network conditions.

---

# Success Criteria

The Launch & Splash System is considered production-ready when it:

* Starts instantly.
* Initializes critical services without blocking the UI.
* Maintains smooth adaptive **60/90/120 FPS** animations.
* Supports Android and iOS consistently.
* Handles offline and error scenarios gracefully.
* Routes users correctly every time.
* Meets security, accessibility, and performance standards.

---

# Final Summary

The **Farvixo Launch & Splash System** establishes a modern, scalable, and enterprise-grade startup experience. By combining a lightweight native launch screen with an optimized Flutter splash screen, asynchronous initialization, adaptive performance, and robust navigation logic, the application delivers a premium first impression while ensuring reliability, security, and scalability for future growth.

**Document Status:** ✅ Complete
**Version:** v1.0.0
**Ready For:** Development, QA, Production Release

---

# Implementation Map (v2.0.0 — Clean Architecture)

This specification is implemented in the codebase as follows (file structure
matches the LAUNCH & SPLASH SYSTEM v2.0.0 design):

```text
lib/
 ├── core/launch/
 │    ├── launch_manager.dart      ← orchestrator: preload → init → decide
 │    ├── splash_controller.dart   ← Riverpod state (progress, error, retry)
 │    ├── decision_engine.dart     ← logged in / session valid / first time
 │    ├── config_manager.dart      ← remote config + local JSON fallback
 │    ├── assets_loader.dart       ← smart preloading + auto retry
 │    └── models/splash_config.dart← min/max duration, colors, redirects
 └── ui/splash/
      ├── splash_screen.dart       ← AI-orbit splash, error fallback, exit fx
      └── widgets/
           ├── logo_widget.dart        ← orbit ring + scale_fade_rotate reveal
           ├── progress_widget.dart    ← step message + gradient bar + %
           └── background_effect.dart  ← gradient + particles/floating orbs
```

| Spec Section | Implementation |
| --- | --- |
| Launch Flow Architecture | `LaunchManager.run()` — Preload & Init → Decision Engine → Next Screen |
| Smart Decision Engine | `DecisionEngine.decide()` — logged in → session valid → refresh token/re-login; first time → onboarding |
| Configuration (remote/local) | `SplashConfig` + `ConfigManager` — minDuration 1500, maxDuration 3000, `#0A0E27` bg, `#8C52FF` progress, `#2A2E45` track, particles `#8C52FF`/`#00D4FF`, redirects |
| Animation & Branding | Orbit ring + neon glow (`logo_widget.dart`), particles/orbs (`background_effect.dart`), scale_fade_rotate reveal |
| Progress with Details | `progress_widget.dart` — real step messages + percentage |
| Error & Fallback Handling | Timeout → continue (offline first); fatal → "Something went wrong!" + Retry (`_ErrorFallback`) |
| Theme Adaptation | Light/dark backgrounds + `SplashConfig.copyWith` overrides |
| Next Screen Transitions | Fade + scale exit, 350 ms |
| Android 12+ SplashScreen API | `values-v31/styles.xml`, `values-night-v31/styles.xml` |
| Android < 12 launch theme | `values*/styles.xml`, `drawable*/launch_background.xml`, `values*/colors.xml` |
| iOS Launch Screen | `LaunchScreen.storyboard` — adaptive `systemBackgroundColor` |
| Startup Test | `test/widget_test.dart` — boot → splash → onboarding |
