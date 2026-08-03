#!/usr/bin/env bash
#
# Analysis plus tests for the app and the domain package. Same as CI.
#
#   ./scripts/check.sh
#
# Exits non-zero on the first failure.

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

echo "==> flutter pub get"
flutter pub get

# --fatal-infos: our lints report at info level.
echo
echo "==> flutter analyze (app + domain, --fatal-infos)"
flutter analyze --fatal-infos

echo
echo "==> flutter test (app)"
flutter test

# Pure Dart, so plain `dart test`. Also catches an accidental Flutter dep.
echo
echo "==> dart test (domain core)"
(cd packages/pomodoro_domain && dart test)

echo
echo "All checks passed."
