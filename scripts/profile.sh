#!/usr/bin/env bash
#
# Ticket 24's profiling run: every number this project can measure without a
# phone, taken the same way every time, printed as one table.
#
#   ./scripts/profile.sh              # the frame and launch benchmarks
#   ./scripts/profile.sh --size       # and build a release Android bundle to weigh
#
# What this is for is regressions. The numbers it prints are recorded in
# docs/performance-record.md with the machine they were taken on; a run that
# comes back several times higher than the row it matches is the signal, not the
# absolute value. The budgets themselves are asserted inside the tests, so a
# change bad enough to matter fails `flutter test` without anybody reading this.
#
# What it deliberately does not do is claim to measure a frame. There is no GPU
# and no vsync under `flutter test` — see the caveats at the top of
# test/garden/garden_performance_test.dart and docs/garden-performance-baseline.md,
# which also hold the device procedure this cannot replace.

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

# The benchmarks print through `debugPrint`, which `flutter test` only forwards
# when it is not compacting output. Both files are run in one invocation so the
# atlas and the harness are warmed once.
echo "==> frame and launch benchmarks (debug build, host)"
flutter test \
  test/garden/garden_performance_test.dart \
  test/performance/cold_launch_test.dart \
  2>&1 | grep -E 'baseline \|' || {
    echo "    no numbers came back — run the two files directly to see why" >&2
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
  # Per-ABI rather than the fat APK: Play delivers one ABI to a device, so the
  # universal build is not a number any user ever downloads. See
  # docs/performance-record.md for what these are and are not.
  echo "==> release size (Android, per ABI)"
  flutter build apk --release --split-per-abi > /dev/null
  for apk in build/app/outputs/flutter-apk/app-*-release.apk; do
    printf '    %-40s %s\n' "$(basename "$apk")" \
      "$(du -h "$apk" | cut -f1)"
  done
  echo
  echo "    iOS cannot be built here — it needs macOS and Xcode. See"
  echo "    docs/performance-record.md for the App Store thinning procedure."
fi

echo "Done. Record anything that moved in docs/performance-record.md."
