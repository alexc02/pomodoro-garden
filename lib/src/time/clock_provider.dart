import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

/// The app's source of the current instant.
///
/// This is the first and simplest of the domain's ports, and it exists at this
/// ticket to prove the override path end to end: production injects
/// [SystemClock], tests override with [FixedClock] and get a clock they own.
/// Ticket 02's session state machine reads time through this provider, so
/// nothing downstream ever needs to reach for [DateTime.now].
final clockProvider = Provider<Clock>((ref) => const SystemClock());
