## What and why

## Checklist

- [ ] `dart format --output=none --set-exit-if-changed .` passes
- [ ] `flutter analyze` passes
- [ ] `./tool/check_forbidden_patterns.sh` passes
- [ ] `flutter test` passes, with tests added or updated
- [ ] New screens handle loading, empty, error and offline states and fit 320 dp wide at large text
- [ ] Architecture rules are respected (`GetBuilder` with ids only, dependencies in `GetDI`, networking only through `flutter_network_plus`)
- [ ] No secrets, environment files or personal data committed
- [ ] `CHANGELOG.md` updated for user-visible changes
