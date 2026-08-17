import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

/// The current time. Override with [FixedClock] in tests; nothing should call
/// [DateTime.now] directly.
final clockProvider = Provider<Clock>((ref) => const SystemClock());
