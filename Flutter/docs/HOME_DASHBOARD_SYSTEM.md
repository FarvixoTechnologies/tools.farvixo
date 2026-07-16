# 🏠 HOME_DASHBOARD_SYSTEM.md

# Part 1 — Foundation & Architecture

---

# Document Information

| Property    | Value                                |
| ----------- | ------------------------------------ |
| Project     | Farvixo                              |
| Module      | Home Dashboard                       |
| Version     | v1.0.0                               |
| Status      | Production Ready                     |
| Platform    | Flutter • Android • iOS • Web        |
| UI Design   | Material Design 3                    |
| Responsive  | Mobile • Tablet • Desktop • Foldable |
| Performance | Adaptive 60 / 90 / 120 FPS           |

---

# Overview

The **Home Dashboard** is the central hub of the Farvixo ecosystem. It provides quick access to AI services, tools, user data, notifications, and personalized content through a clean, intelligent, and highly responsive interface.

The dashboard should load instantly, adapt to different screen sizes, and prioritize frequently used features while remaining simple and visually premium.

---

# Objectives

* Instant access to all tools
* AI-first experience
* Personalized dashboard
* Fast navigation
* Responsive design
* Cloud synchronization
* Offline support
* High performance
* Enterprise scalability

---

# Dashboard Flow

```text
App Launch
     │
     ▼
Authentication
     │
     ▼
Home Dashboard
     │
     ├── AI Assistant
     ├── Search
     ├── Categories
     ├── Quick Actions
     ├── Recent Activity
     ├── Favorites
     ├── Trending Tools
     ├── Notifications
     └── User Profile
```

---

# Architecture

```text
Home Dashboard
      │
      ├── App Bar
      ├── Search
      ├── AI Assistant
      ├── Quick Actions
      ├── Categories
      ├── Tool Grid
      ├── Recommended Tools
      ├── Recent Activity
      ├── Notifications
      └── Bottom Navigation
```

---

# Dashboard Sections

### App Bar

Contains:

* Farvixo Logo
* Welcome Message
* Search Icon
* Notification Icon
* Profile Avatar

---

### Smart Search

Features:

* Instant Search
* AI Suggestions
* Voice Search
* Recent Searches
* Trending Searches

---

### AI Assistant Card

Displays:

* AI Greeting
* Quick Prompts
* Recent Conversations
* One-Tap AI Chat

---

### Quick Actions

Examples:

* AI Chat
* OCR
* Image to PDF
* PDF Tools
* QR Generator
* Image Generator

---

### Categories

Examples:

* AI
* PDF
* Images
* Video
* Audio
* Documents
* Utilities
* Developer
* Security

---

### Tool Grid

Display:

* Tool Icon
* Tool Name
* Favorite Button
* New Badge
* Pro Badge (if applicable)

Supports:

* Grid View
* List View

---

### Personalized Sections

* Recently Used
* Favorites
* Recommended
* Trending
* Continue Working

---

### Notifications

Display:

* Updates
* AI Suggestions
* System Alerts
* Announcements

---

# Navigation

Primary Navigation

* Home
* AI
* Explore
* Activity
* Profile

---

# Folder Structure

```text
lib/

dashboard/
 ├── widgets/
 ├── models/
 ├── providers/
 ├── controllers/
 ├── screens/
 ├── services/
 ├── animations/
 └── utils/
```

---

# Design Principles

* Clean Interface
* AI First
* Minimal Layout
* Adaptive Components
* Smooth Motion
* Consistent Branding
* Accessible UI

---

# Theme Support

* Light Theme
* Dark Theme
* System Theme

Automatic switching based on device settings.

---

# Responsive Support

Supported Devices

* Android Phones
* Android Tablets
* Foldables
* iPhone
* iPad
* Desktop Web

Orientation

* Portrait
* Landscape

---

# Performance Goals

| Metric          | Target                     |
| --------------- | -------------------------- |
| Dashboard Load  | ≤ 1 sec                    |
| Search Response | ≤ 100 ms                   |
| Navigation      | ≤ 300 ms                   |
| Animation       | Adaptive 60 / 90 / 120 FPS |
| Memory Usage    | Optimized                  |

---

# Accessibility

Support

* Screen Readers
* High Contrast
* Large Fonts
* Reduced Motion
* Keyboard Navigation (Web)

---

# Best Practices

* Load only visible widgets first.
* Lazy-load secondary content.
* Cache frequently used tools.
* Keep animations lightweight.
* Prioritize user-specific content.
* Ensure offline compatibility where possible.

---

# Part 1 Summary

This section establishes the foundation of the Farvixo Home Dashboard, including its architecture, core modules, navigation, layout, personalization, responsive behavior, and performance goals.

**Next:** **Part 2 — UI/UX Design & Dashboard Widgets**, covering App Bar, Hero Banner, AI Cards, Search UI, Tool Cards, Widget layouts, animations, and Material Design 3 specifications.

# 🏠 HOME_DASHBOARD_SYSTEM.md

# Part 2 — UI/UX Design & Dashboard Widgets

---

# Dashboard Layout

The Home Dashboard should follow a modern **Material Design 3** layout with adaptive spacing and responsive components.

```text
┌──────────────────────────────────────┐
│ Status Bar                           │
├──────────────────────────────────────┤
│ App Bar                              │
├──────────────────────────────────────┤
│ AI Hero Banner                       │
├──────────────────────────────────────┤
│ Smart Search                         │
├──────────────────────────────────────┤
│ Quick Actions                        │
├──────────────────────────────────────┤
│ Categories                           │
├──────────────────────────────────────┤
│ Recommended Tools                    │
├──────────────────────────────────────┤
│ Recently Used                        │
├──────────────────────────────────────┤
│ Trending Tools                       │
├──────────────────────────────────────┤
│ Continue Working                     │
├──────────────────────────────────────┤
│ Bottom Navigation                    │
└──────────────────────────────────────┘
```

---

# App Bar

### Left

* Farvixo Logo
* Greeting
* User Name

### Right

* Search
* Notification
* Profile Avatar

Features

* Dynamic Greeting
* Sticky Header
* Blur Effect
* Scroll Animation

---

# AI Hero Banner

Purpose

Show the AI assistant as the primary entry point.

Content

* Animated AI Orb
* Greeting Message
* AI Status
* "Ask Anything"
* Start Chat Button
* Voice Chat Button

Optional

* Daily AI Tips
* Smart Suggestions

---

# Smart Search

Functions

* Instant Search
* Voice Search
* AI Search
* Search History
* Trending Searches
* Search Filters

Placeholder

> Search AI, Tools, Documents, Images...

---

# Quick Actions

Display 6–8 frequently used shortcuts.

Examples

* 🤖 AI Chat
* 📄 PDF Tools
* 🖼️ Image Tools
* 🎥 Video Tools
* 🔍 OCR
* 🌐 Translator
* 📷 QR Scanner
* ⚙️ All Tools

---

# Categories

Recommended Categories

* AI
* PDF
* Images
* Video
* Audio
* Documents
* Productivity
* Developer
* Security
* Utilities

Display

* Horizontal Scroll
* Icon + Label
* Active State
* Smooth Animation

---

# Tool Cards

Each Tool Card should include:

* Tool Icon
* Tool Name
* Short Description
* Favorite Button
* New Badge
* Pro Badge (if applicable)
* Last Used
* One-Tap Open

---

# Recommended Section

Based on:

* User Activity
* AI Analysis
* Trending Usage
* Favorites
* Recently Opened

---

# Recently Used

Show:

* Last Opened Tools
* Recent Documents
* Continue Editing

Limit

* Last 10 Items

---

# Trending Tools

Display

* Most Popular
* New Releases
* AI Recommended
* Seasonal Picks

---

# Continue Working

Restore unfinished tasks:

* PDF Editing
* AI Conversations
* OCR Results
* Image Editing
* Saved Drafts

---

# Notifications Widget

Display

* App Updates
* AI Suggestions
* Security Alerts
* New Features
* Promotions (Optional)

---

# Profile Widget

Quick Access

* Account
* Premium
* Settings
* Cloud Sync
* Logout

---

# Bottom Navigation

Tabs

🏠 Home

🤖 AI

🔍 Explore

📂 Activity

👤 Profile

Active tab should have:

* Filled Icon
* Label
* Smooth Animation

---

# Animations

Use

* Fade
* Scale
* Slide
* Hero Animation
* Ripple Effect
* Material Motion

Avoid

* Heavy animations
* Lag
* Excessive transitions

---

# Responsive Layout

### Mobile

* 2-column tool grid

### Tablet

* 4-column tool grid

### Desktop

* 6-column adaptive grid

### Foldable

* Dual-pane layout (when expanded)

---

# Theme

Support

* Light
* Dark
* System

Effects

* Dynamic Color
* Glass Cards
* Soft Shadows
* Adaptive Contrast

---

# Performance

| Metric           | Target                     |
| ---------------- | -------------------------- |
| Dashboard Render | ≤ 1 sec                    |
| Search Response  | ≤ 100 ms                   |
| Card Animation   | ≤ 300 ms                   |
| Refresh Rate     | Adaptive 60 / 90 / 120 FPS |
| Frame Drops      | Zero                       |

---

# Accessibility

Support

* Screen Readers
* Dynamic Font Sizes
* High Contrast
* Reduced Motion
* Keyboard Navigation (Web/Desktop)

---

# Best Practices

* Show the most important actions above the fold.
* Prioritize AI and Search at the top.
* Keep the dashboard uncluttered.
* Lazy-load non-visible widgets.
* Personalize recommendations using user behavior.
* Maintain consistent spacing, typography, and iconography.

---

# Part 2 Summary

This section defines the complete UI/UX of the Farvixo Home Dashboard, including the App Bar, AI Hero Banner, Smart Search, Quick Actions, Categories, Tool Cards, Personalized Sections, Bottom Navigation, responsive layouts, animations, and Material Design 3 principles.

**Next:** **Part 3 — Features, AI Integration & Tool Management**, covering dashboard intelligence, AI recommendations, cloud sync, offline mode, widgets, and advanced user interactions.

# 🏠 HOME_DASHBOARD_SYSTEM.md

# Part 3 — Features, AI Integration & Tool Management

---

# Overview

The Home Dashboard is the **AI-powered control center** of Farvixo. It intelligently adapts to each user by analyzing usage patterns, preferences, favorites, and recent activity to surface the most relevant tools and actions.

---

# Dashboard Intelligence

The dashboard should automatically personalize content based on:

* User Behavior
* Frequently Used Tools
* Favorite Tools
* Search History
* Recent Activity
* AI Recommendations
* Time of Day
* Device Type
* Language Preference

---

# AI Assistant

The AI Assistant is the primary feature of the dashboard.

### Capabilities

* AI Chat
* Voice Chat
* Image Understanding
* Document Analysis
* Code Assistance
* Smart Recommendations
* Writing Assistant
* Translation
* OCR Helper

---

# AI Quick Prompts

Examples

* Explain this PDF
* Convert Image to PDF
* Summarize Document
* Translate Text
* Generate Image
* Remove Background
* Extract Text
* Improve Photo

---

# AI Recommendation Engine

Automatically recommends:

* Frequently used tools
* Similar tools
* Trending tools
* New releases
* Recently updated tools
* AI-powered suggestions

---

# Smart Search

Features

* Instant Search
* AI Search
* Voice Search
* Search History
* Trending Searches
* Fuzzy Matching
* Category Filter

---

# Tool Management

Each tool contains:

* Tool ID
* Tool Name
* Category
* Icon
* Description
* Version
* Status
* Favorite
* Last Used
* Usage Count

---

# Favorites

Users can:

* Pin favorite tools
* Rearrange favorites
* Remove favorites
* Sync favorites across devices

---

# Recently Used

Store:

* Last opened tools
* Last edited documents
* AI conversations
* Recent uploads

Display limit:

**10–20 items**

---

# Continue Working

Restore unfinished work:

* PDF Editing
* OCR
* AI Chat
* Image Editing
* Video Conversion
* Saved Drafts

---

# Cloud Sync

Synchronize:

* Favorites
* History
* Preferences
* Themes
* Language
* AI Conversations
* Saved Projects

---

# Offline Mode

Available Features

* Cached Tools
* Local Files
* Recent History
* Saved Projects

Unavailable

* Cloud AI
* Remote Sync
* Online Search

---

# Notifications

Types

* AI Suggestions
* System Updates
* Feature Announcements
* Security Alerts
* Sync Status

---

# Widget System

Dashboard widgets include:

* Weather (Optional)
* Storage Usage
* AI Activity
* Tool Usage
* Daily Tips
* Recent Files
* Cloud Status
* Premium Status

Widgets should be:

* Reorderable
* Hideable
* Responsive

---

# User Profile

Quick Actions

* Edit Profile
* Subscription
* Settings
* Language
* Theme
* Logout

---

# Activity Center

Display:

* Recent Actions
* Downloads
* Uploads
* AI History
* Notifications
* Sync History

---

# Multi-Device Support

Sync across:

* Android
* iPhone
* Tablet
* Desktop Web

Automatically restore:

* Session
* Dashboard layout
* Favorites
* Preferences

---

# Dashboard Settings

Allow users to customize:

* Widget Order
* Theme
* Grid/List View
* Default Landing Page
* AI Preferences
* Notification Preferences

---

# Performance

| Metric             | Target                     |
| ------------------ | -------------------------- |
| AI Suggestion Load | ≤ 300 ms                   |
| Search Response    | ≤ 100 ms                   |
| Widget Refresh     | ≤ 500 ms                   |
| Dashboard Sync     | Background                 |
| Refresh Rate       | Adaptive 60 / 90 / 120 FPS |

---

# Security

Protect:

* User Data
* AI Conversations
* Cloud Sync
* Authentication Session
* Local Preferences

Use:

* Encrypted Storage
* HTTPS
* Secure APIs
* Token Validation

---

# Best Practices

* Prioritize frequently used tools.
* Keep AI Assistant easily accessible.
* Load recommendations asynchronously.
* Sync user preferences automatically.
* Support offline functionality.
* Make widgets customizable.
* Keep dashboard responsive and uncluttered.

---

# Part 3 Summary

This section defines the intelligent features of the Farvixo Home Dashboard, including AI Assistant integration, recommendation engine, smart search, favorites, cloud sync, offline mode, widgets, activity tracking, user customization, and secure data management.

**Next:** **Part 4 — Performance, Security, Responsive Design & Production Optimization**, covering adaptive layouts, accessibility, optimization strategies, testing, and enterprise deployment guidelines.

# 🏠 HOME_DASHBOARD_SYSTEM.md

# Part 4 — Performance, Security, Responsive Design & Production Optimization

---

# Overview

The **Farvixo Home Dashboard** must deliver a fast, secure, and responsive experience across all supported devices. Every interaction should feel smooth, with adaptive rendering, intelligent resource management, and enterprise-grade security.

---

# Performance Goals

| Metric                    | Target                     |
| ------------------------- | -------------------------- |
| Dashboard Initial Load    | ≤ 1 sec                    |
| Search Response           | ≤ 100 ms                   |
| Widget Refresh            | ≤ 500 ms                   |
| Tool Open Time            | ≤ 300 ms                   |
| API Response              | ≤ 500 ms                   |
| AI Response (First Token) | ≤ 2 sec                    |
| Refresh Rate              | Adaptive 60 / 90 / 120 FPS |

---

# Rendering Performance

### Supported Refresh Rates

* 60Hz → 60 FPS
* 90Hz → 90 FPS
* 120Hz → 120 FPS

Requirements

* Zero frame drops
* Smooth scrolling
* Stable animations
* Hardware acceleration
* Consistent frame timing

---

# Memory Optimization

Strategies

* Lazy widget loading
* Smart image caching
* SVG icons
* Dispose unused widgets
* Reuse controllers
* Background cleanup

Target

* Low memory usage
* No memory leaks

---

# Network Optimization

* Parallel API requests
* Background synchronization
* Intelligent retry
* Request caching
* Offline fallback
* Incremental data loading

---

# Dashboard Caching

Cache

* User Profile
* Favorites
* Tool List
* Categories
* Recent Activity
* AI Suggestions
* Theme
* Language

Benefits

* Faster startup
* Reduced API usage
* Offline support

---

# Responsive Layout

### Mobile

* 2-column tool grid
* Bottom navigation
* Single-column widgets

### Tablet

* 4-column grid
* Expanded widgets
* Larger cards

### Desktop

* 6-column adaptive grid
* Sidebar navigation
* Multi-panel layout

### Foldable

* Dual-pane support
* Adaptive spacing
* Flexible widget arrangement

---

# Security

Protect

* User Session
* Cloud Data
* AI Conversations
* Preferences
* Local Cache

Security Features

* JWT Authentication
* HTTPS Only
* Encrypted Local Storage
* Secure API Requests
* Token Refresh
* Session Timeout
* Device Validation

Optional

* Root Detection
* Jailbreak Detection
* Emulator Detection

---

# Privacy

Never expose

* Access Tokens
* Refresh Tokens
* Passwords
* API Keys
* Personal Information

Support

* Privacy Controls
* Data Export
* Account Deletion
* Permission Management

---

# Accessibility

Support

* Screen Readers
* Dynamic Font Sizes
* High Contrast
* Reduced Motion
* Keyboard Navigation (Web)
* Color-Blind Friendly Design

---

# Error Handling

Gracefully handle

* Network Failure
* AI Service Failure
* Sync Error
* Authentication Expiry
* Server Error
* Empty Dashboard
* Missing Data

Display

* Friendly Messages
* Retry Actions
* Offline Indicators

---

# Analytics

Track

* Dashboard Opens
* Search Usage
* Tool Launches
* AI Interactions
* Favorite Actions
* Widget Usage
* Notification Opens

Respect user consent where required.

---

# Production Checklist

### UI

* Material Design 3 compliant
* Responsive layouts
* Adaptive themes
* Smooth transitions

### Performance

* Dashboard loads within target time
* No frame drops
* Optimized memory usage
* Background sync working

### Security

* Authentication verified
* Secure storage enabled
* Token refresh tested
* API requests encrypted

### Functionality

* Search works
* AI Assistant responds
* Widgets update correctly
* Favorites sync
* Offline mode works

---

# Testing Matrix

| Device         | Status |
| -------------- | ------ |
| Android Phone  | ✅      |
| Android Tablet | ✅      |
| Foldable       | ✅      |
| iPhone         | ✅      |
| iPad           | ✅      |
| Desktop Web    | ✅      |
| Portrait       | ✅      |
| Landscape      | ✅      |
| Dark Theme     | ✅      |
| Light Theme    | ✅      |

---

# Best Practices

* Load critical widgets first.
* Defer non-essential content.
* Cache frequently accessed data.
* Keep animations lightweight.
* Avoid unnecessary API calls.
* Use adaptive layouts for all screen sizes.
* Continuously monitor dashboard performance.

---

# Part 4 Summary

This section defines the production optimization strategy for the Farvixo Home Dashboard, including performance tuning, adaptive **60/90/120 FPS** rendering, caching, responsive layouts, security, privacy, accessibility, analytics, testing, and release readiness.

**Next:** **Part 5 — Production Guide, Dashboard Architecture Diagram, Release Checklist & Future Roadmap**, completing the `HOME_DASHBOARD_SYSTEM.md`.

# 🏠 HOME_DASHBOARD_SYSTEM.md

# Part 5 — Production Guide, Release Checklist & Future Roadmap

---

# Overview

This document completes the **Farvixo Home Dashboard System** by defining the final production architecture, dashboard lifecycle, release checklist, testing strategy, monitoring, and future upgrade roadmap.

The Home Dashboard serves as the **central hub** of the Farvixo ecosystem, connecting AI, tools, cloud services, user data, and personalization into one intelligent interface.

---

# Complete Dashboard Flow

```text
User Opens App
        │
        ▼
Authentication Check
        │
        ▼
Dashboard Initialization
        │
        ▼
Load User Profile
        │
        ▼
Load Dashboard Widgets
        │
        ▼
Load AI Assistant
        │
        ▼
Load Categories
        │
        ▼
Load Recommended Tools
        │
        ▼
Restore Recent Activity
        │
        ▼
Dashboard Ready
```

---

# Dashboard Component Architecture

```text
Home Dashboard
│
├── App Bar
├── Smart Search
├── AI Assistant
├── Hero Banner
├── Quick Actions
├── Categories
├── Tool Grid/List
├── Recommended Tools
├── Recently Used
├── Continue Working
├── Trending Tools
├── Notifications
├── Activity Center
├── Cloud Sync
├── Profile
└── Bottom Navigation
```

---

# Dashboard Lifecycle

```text
Initialize

↓

Load Settings

↓

Restore Session

↓

Load Dashboard

↓

Background Sync

↓

Real-time Updates

↓

Dispose Resources
```

---

# Widget Priority

### Priority 1

* App Bar
* Search
* AI Assistant
* Categories

### Priority 2

* Tool Grid
* Quick Actions
* Favorites
* Recently Used

### Priority 3

* Trending
* Recommendations
* Activity
* Notifications

### Background

* Cloud Sync
* Analytics
* Update Check
* AI Suggestions
* Image Cache

---

# Production Standards

### UI

* Material Design 3
* Adaptive Layout
* Responsive Grid
* Glassmorphism (Optional)
* Dynamic Color
* Smooth Motion
* Premium Typography

---

### Performance

| Item           | Target                     |
| -------------- | -------------------------- |
| Dashboard Load | ≤ 1 sec                    |
| Search         | ≤ 100 ms                   |
| Widget Refresh | ≤ 500 ms                   |
| Navigation     | ≤ 300 ms                   |
| Animation      | Adaptive 60 / 90 / 120 FPS |
| Frame Drops    | Zero                       |

---

### Security

Enterprise Requirements

* HTTPS
* JWT Authentication
* Secure Storage
* Token Refresh
* API Encryption
* Device Validation
* Session Recovery

---

### Accessibility

Support

* Screen Reader
* High Contrast
* Dynamic Text Size
* Reduced Motion
* Keyboard Navigation
* RTL Languages

---

# Release Checklist

## Dashboard

* Dashboard loads correctly
* Search works
* Categories load
* AI Assistant responds
* Widgets display properly
* Navigation works

---

## Performance

* Fast startup
* No lag
* No memory leaks
* Stable FPS
* Optimized scrolling

---

## Security

* Login verified
* Session restored
* Tokens encrypted
* Logout works
* API secure

---

## Sync

* Cloud sync
* Favorites
* Recent Activity
* Settings
* AI History

---

## Offline

* Dashboard opens
* Cached tools available
* Local history works
* User informed about offline state

---

# Monitoring

Track

* Dashboard Opens
* Active Users
* Tool Usage
* Search Queries
* AI Requests
* Widget Usage
* Errors
* Crash Reports
* Startup Time
* Memory Usage

---

# Future Roadmap

## Version 1.1

* Dynamic Dashboard Widgets
* Smart AI Recommendations
* Custom Widget Order

---

## Version 1.2

* Drag & Drop Widgets
* Live Dashboard Updates
* AI Productivity Score
* Daily Goals

---

## Version 2.0

* Fully AI-Personalized Dashboard
* Predictive Tool Suggestions
* Voice-First Dashboard
* Multi-Window Support
* Cross-Device Continuity
* AI Automation Center

---

# Developer Notes

* Keep the dashboard modular.
* Lazy-load non-critical sections.
* Optimize all API requests.
* Cache frequently used content.
* Separate UI, business logic, and services.
* Follow Material Design 3 guidelines.
* Ensure compatibility across Android, iOS, Tablets, Foldables, and Web.

---

# Success Criteria

The Home Dashboard is considered production-ready when:

* Dashboard loads within target performance.
* AI Assistant is always accessible.
* Search provides instant results.
* Widgets are responsive and customizable.
* User preferences sync across devices.
* Offline mode functions correctly.
* Security and accessibility standards are met.
* Adaptive **60/90/120 FPS** rendering is maintained on supported devices.

---

# Final Summary

The **Farvixo Home Dashboard System v1.0.0** provides a modern, intelligent, and scalable dashboard experience built around **AI-first interactions**, personalized recommendations, fast tool discovery, secure cloud synchronization, and responsive Material Design 3 interfaces. With adaptive layouts, enterprise-grade security, offline support, and modular architecture, it serves as the foundation of the Farvixo ecosystem and is ready for production deployment.

---

# Document Status

| Property        | Value                                |
| --------------- | ------------------------------------ |
| Document        | HOME_DASHBOARD_SYSTEM.md             |
| Version         | v1.0.0                               |
| Status          | ✅ Production Ready                   |
| Platforms       | Flutter • Android • iOS • Web        |
| UI              | Material Design 3                    |
| Performance     | Adaptive 60 / 90 / 120 FPS           |
| Architecture    | Enterprise Modular                   |
| AI Integration  | Full                                 |
| Offline Support | Yes                                  |
| Cloud Sync      | Yes                                  |
| Responsive      | Mobile • Tablet • Foldable • Desktop |

---

# Implementation Map

| Spec Section | Implementation |
| --- | --- |
| Dashboard UI (app bar, greeting, hero, search, quick actions, categories, sections, banners) | `lib/features/home/home_screen.dart` |
| App Bar | Logo + wordmark, notification bell with unread dot, profile avatar (initial) |
| Dynamic greeting | Time-aware (morning/afternoon/evening) + display name |
| AI Hero Banner | Brand-gradient card + quick prompts → AI tab |
| Smart Search | "Search AI, tools, documents..." → `/search` |
| Quick Actions | 8 shortcuts (AI Chat, PDF, Image, OCR, Translator, Compress PDF, Video, All Tools) |
| Recently Used | `lib/providers/tool_activity_provider.dart` — max 10, deduped, persisted, Clear action; recorded on every tool open |
| Favorites | Heart toggle on `lib/widgets/tool_card.dart`, persisted, Favorites row on dashboard |
| Recommendation engine | Local heuristic — most-used categories minus already-known tools; hidden until history exists |
| Trending Tools | Badged tools (POPULAR / NEW / AI) |
| Personalization matrix | Guest → upgrade banner; free → Go Pro banner; pro → no upsell |
| Responsive grid | 2 cols (<600 px), 4 (600–1000 px), 6 (≥1000 px); content max-width 1080 px |
| Pull-to-refresh | RefreshIndicator (local-first, never blocks) |
| Bottom navigation | `lib/features/shell/main_shell.dart` |
| Local persistence | `StorageService.recentToolIds` / `favoriteToolIds` (SharedPreferences) |
