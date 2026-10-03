# Contributing

Thanks for helping. This project is deliberately strict about architecture, so please read this page first.

## Setup

```bash
flutter pub get
cp env/development.example.json env/development.json
dart run tool/mock_server/main.dart            # terminal 1
flutter run --dart-define-from-file=env/development.json   # terminal 2
```

## Before you open a pull request

All of these must pass; CI runs the same commands.

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
./tool/check_forbidden_patterns.sh
flutter test
```

If you change the database schema, regenerate and commit the generated code: `dart run build_runner build`.

## Architecture rules (checked automatically)

- Use `GetxController` and `GetBuilder` only. No `Obx`, `.obs`, `Rx` types, GetX workers or Bindings.
- Every `GetBuilder` has an `id`, and controllers call `update([ids])`, never `update()`.
- All dependencies are created in `lib/di/get_di.dart`. Controllers never build their own dependencies, and routes declare no bindings.
- All HTTP goes through `flutter_network_plus`. Do not add Dio, `http` or another client.
- Only `lib/data` and `lib/di` may import `flutter_network_plus` or Drift.
- Controllers never call the network or the database; they call use cases.
- Business rules and validation belong in use cases and `Validators`, not in widgets or controllers.
- Entities (domain) are separate from models (data); pages see entities only.

## Code style

- Follow the lints in `analysis_options.yaml` and Effective Dart. No dead code, no commented-out code, no TODO placeholders for core behaviour, no magic numbers or strings (use `AppSpacing`, `AppSizes`, `AppStrings`, `AppLimits` and friends).
- Document public classes and methods that form an architectural API.
- Keep controllers and widgets small. If one grows large, split it.

## Tests

- Add or update tests with every change. Prefer the real dependency graph with `TestDi` and the fake backend over mocks of your own code. See [plans/docs/testing.md](plans/docs/testing.md).
- Cover loading, empty, error and success states for any new screen, and check it at 320 dp wide with large text.
- Do not write tests that depend on each other or on a production instance.

## Commits and pull requests

- Use [conventional commits](https://www.conventionalcommits.org/): `feat:`, `fix:`, `docs:`, `test:`, `refactor:`, `ci:`, `chore:`. Keep commits small and focused.
- Describe what changed and why. Link the issue it closes.
- Update `CHANGELOG.md` under *Unreleased* for user-visible changes.
- Never commit secrets, real environment files, keystores or tokens.

## Reporting bugs and ideas

Use the issue templates. For a bug, include the platform, the steps, what you expected and what happened; logs help but must not contain tokens or personal data.
