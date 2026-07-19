# FARVIXO PROFILE_PAGE.md
## Version 2026 Enterprise Edition
### Mobile Profile Specification (Editable Profile)

Status: Production Ready

---

## PAGE PURPOSE

The Profile Page is ONLY for user identity and personal information.

Users can view and edit their profile from one beautiful screen.

This page DOES NOT contain:

- App Settings
- Theme
- Notifications
- Privacy
- Security Settings

Those belong in Settings.

---

## PAGE HIERARCHY

Status Bar → Profile Hero → Profile Card → Account Information → Achievements → Activity → My Content → Security Status → Profile Actions → Danger Zone

## Flutter implementation

- `lib/features/profile/profile_screen.dart` — view hierarchy
- `lib/features/profile/edit_profile_screen.dart` — full-screen editor (tabs)
- `lib/models/profile_details.dart` — editable identity fields
- `lib/providers/profile_details_provider.dart` — persistence
- Route: `/profile/edit`
