/// `MM:SS`, rounded up so it only hits 00:00 when the session is actually
/// over. Minutes don't roll into hours: 120 minutes reads `120:00`.
String formatCountdown(Duration remaining) {
  final ceiling =
      (remaining.inMicroseconds / Duration.microsecondsPerSecond).ceil();
  // The state machine already clamps at zero; this is belt and braces.
  final seconds = ceiling < 0 ? 0 : ceiling;

  return _asMinutesAndSeconds(seconds);
}

/// `MM:SS`, rounded down: a 0.4 s pause reads `00:00`.
String formatElapsed(Duration elapsed) =>
    _asMinutesAndSeconds(elapsed.isNegative ? 0 : elapsed.inSeconds);

String _asMinutesAndSeconds(int seconds) {
  final minutes = seconds ~/ Duration.secondsPerMinute;
  final rest = seconds % Duration.secondsPerMinute;

  return '${minutes.toString().padLeft(2, '0')}:'
      '${rest.toString().padLeft(2, '0')}';
}
