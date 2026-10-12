#!/usr/bin/env bash
#
# Host-side perf numbers for spotting regressions.
#
#   ./scripts/profile.sh              # frame and launch benchmarks
#   ./scripts/profile.sh --size       # also build release APKs and print sizes
#
# Compare against earlier runs; look for big jumps, not absolute values.
# Budgets are asserted in the tests themselves. No GPU or vsync under
# `flutter test`, so these aren't real frame times.

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

WITH_SIZE=false
if [[ "${1:-}" == "--size" ]]; then
  WITH_SIZE=true
fi

echo "==> environment"
flutter --version | head -1
echo "    host: $(uname -sm), $(nproc) cores"
echo

# One invocation so the atlas and harness warm up once.
echo "==> frame and launch benchmarks (debug build, host)"
flutter test \
  test/garden/garden_performance_test.dart \
  test/performance/cold_launch_test.dart \
  2>&1 | grep -E 'baseline \|' || {
    echo "    no numbers came back; run the two files directly to see why" >&2
    exit 1
  }
echo

echo "==> memory: dart:ui handles opened and not closed"
flutter test test/garden/garden_memory_test.dart > /dev/null && \
  echo "    garden_memory_test: green (no texture or picture leaked)"
echo

echo "==> timer accuracy across a backgrounded two-hour session"
flutter test test/performance/timer_accuracy_test.dart > /dev/null && \
  echo "    timer_accuracy_test: green (exact, not merely within a second)"
echo

echo "==> soak: a hundred sessions, and a full garden animated for three minutes"
flutter test test/performance/soak_test.dart > /dev/null && \
  echo "    soak_test: green (nothing reached FlutterError.onError)"
echo

if [[ "$WITH_SIZE" == true ]]; then
  # Per-ABI: Play only ships one ABI to a device, so the fat APK size is
  # meaningless.
  echo "==> release size (Android, per ABI)"
  flutter build apk --release --split-per-abi > /dev/null
  for apk in build/app/outputs/flutter-apk/app-*-release.apk; do
    printf '    %-40s %s\n' "$(basename "$apk")" \
      "$(du -h "$apk" | cut -f1)"
  done
  echo
  echo "    iOS needs macOS and Xcode; use the App Store Connect size report."
fi

echo "Done."
