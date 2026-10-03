# Changelog

All notable changes are recorded here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses [semantic versioning](https://semver.org/).

## [Unreleased]

### Added
- Project foundation for Flutter 3.47 / Dart 3.13 on Android, iOS, macOS, Windows, Linux and web (web does not run; see the README).
- Clean architecture in three layers with a single dependency-injection root (`GetDI`) and no GetX Bindings.
- State management with GetX `GetBuilder` only, enforced by `tool/check_forbidden_patterns.sh`.
- Networking through `flutter_network_plus`: token refresh, retries, response cache, offline queue and optional SSL pinning.
- Authentication: register, sign in, session restore, sign out and forced sign out when a session cannot be refreshed.
- Dashboard, projects, tasks (search, filters, sorting, paging, create, edit, delete, quick changes) and profile screens, adaptive from phone to desktop.
- Offline support: local SQLite storage (Drift), saved data when the server is unreachable, local-first writes, replay of queued changes, rejected-change handling and account-switch cleanup.
- Light, dark and system themes, remembered between launches.
- Local mock API server implementing `plans/docs/api-contract.md`.
- 490 tests (unit, widget, flow and a device journey), about 94% line coverage.
- GitHub workflows for analysis, tests and builds; Android release signing from secrets.
- Documentation: README and architecture documents in `plans/docs`.

### Changed
- Local storage failures are reported as `CacheFailure` and never block data that already came from the server.
- Use cases with business logic log their activity at debug level.
- Offline changes can be sent from the pending-changes banner ("Sync now").

### Fixed
- Brief messages (such as "Task created") covered the bottom navigation bar and blocked taps for four seconds on phones. They are now standard Material snackbars shown above the bar. Found by running the journey on an Android emulator.
- The task form and profile pages are plain scrolling columns, so their buttons are always available.

### Known limitations
- The networking package does not support web, so the app cannot run on web.
- The GitHub workflows have not yet run on GitHub; Windows and Linux builds have not been run, and iOS has been built unsigned but not run.
- The local database is not encrypted.
