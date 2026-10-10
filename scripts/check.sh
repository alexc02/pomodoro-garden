#!/usr/bin/env bash
#
# The project's check command: static analysis and the full test suite, across
# both packages in the workspace. This is what CI runs, and it is the same
# command locally, so a green run here means a green run there.
#
#   ./scripts/check.sh
#
# Exits non-zero on the first failure.

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

echo "==> flutter pub get"
flutter pub get

# --fatal-infos because the analyzer's info-level output is where the lints in
# analysis_options.yaml land. Without it, "analysis passes" would mean only
# "nothing is broken enough to be a warning".
echo
echo "==> flutter analyze (app + domain, --fatal-infos)"
flutter analyze --fatal-infos

echo
echo "==> flutter test (app)"
flutter test

# The domain core is pure Dart with no widget binding, so it runs under the
# Dart VM directly — faster, and it fails loudly if the package ever acquires a
# dependency that needs Flutter.
echo
echo "==> dart test (domain core)"
(cd packages/pomodoro_domain && dart test)

echo
echo "All checks passed."
