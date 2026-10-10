/// Formats [remaining] as the countdown reads it: `MM:SS`, rounded up.
///
/// Rounded up because a countdown shows the time you have *left*: with 24
/// minutes and 59.4 seconds to go the display should still say 25:00, and it
/// should reach 00:00 only when the session is genuinely over. Rounding down
/// would show 00:00 for the whole of the last second.
///
/// Minutes are not wrapped into hours. A 120-minute session reads `120:00`,
/// which is what the user chose; `2:00:00` would be a different number to
/// parse at a glance.
String formatCountdown(Duration remaining) {
  final ceiling =
      (remaining.inMicroseconds / Duration.microsecondsPerSecond).ceil();
  // A negative countdown is not a thing the user can be shown. The machine
  // clamps remaining time at zero already; this is the second line of defence.
  final seconds = ceiling < 0 ? 0 : ceiling;

  return _asMinutesAndSeconds(seconds);
}

/// Formats [elapsed] as a stopwatch reads it: `MM:SS`, rounded down.
///
/// The other direction from [formatCountdown], and rounded the other way for
/// the same reason. Time already spent is time you have finished spending: a
/// pause 0.4 seconds old has not lasted a second yet, so it reads `00:00` until
/// it has.
String formatElapsed(Duration elapsed) =>
    _asMinutesAndSeconds(elapsed.isNegative ? 0 : elapsed.inSeconds);

/// `MM:SS`. The half the two formatters agree on — they differ only in which
/// way they round on the way in.
String _asMinutesAndSeconds(int seconds) {
  final minutes = seconds ~/ Duration.secondsPerMinute;
  final rest = seconds % Duration.secondsPerMinute;

  return '${minutes.toString().padLeft(2, '0')}:'
      '${rest.toString().padLeft(2, '0')}';
}
