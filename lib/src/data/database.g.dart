// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $SessionsTable extends Sessions
    with TableInfo<$SessionsTable, SessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationSecondsMeta = const VerificationMeta(
    'durationSeconds',
  );
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
    'duration_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedMeta = const VerificationMeta(
    'completed',
  );
  @override
  late final GeneratedColumn<bool> completed = GeneratedColumn<bool>(
    'completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _outcomeMeta = const VerificationMeta(
    'outcome',
  );
  @override
  late final GeneratedColumn<String> outcome = GeneratedColumn<String>(
    'outcome',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pausedSecondsMeta = const VerificationMeta(
    'pausedSeconds',
  );
  @override
  late final GeneratedColumn<int> pausedSeconds = GeneratedColumn<int>(
    'paused_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _pausedSinceMeta = const VerificationMeta(
    'pausedSince',
  );
  @override
  late final GeneratedColumn<DateTime> pausedSince = GeneratedColumn<DateTime>(
    'paused_since',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    startedAt,
    durationSeconds,
    completed,
    outcome,
    pausedSeconds,
    pausedSince,
    endedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<SessionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
        _durationSecondsMeta,
        durationSeconds.isAcceptableOrUnknown(
          data['duration_seconds']!,
          _durationSecondsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_durationSecondsMeta);
    }
    if (data.containsKey('completed')) {
      context.handle(
        _completedMeta,
        completed.isAcceptableOrUnknown(data['completed']!, _completedMeta),
      );
    }
    if (data.containsKey('outcome')) {
      context.handle(
        _outcomeMeta,
        outcome.isAcceptableOrUnknown(data['outcome']!, _outcomeMeta),
      );
    }
    if (data.containsKey('paused_seconds')) {
      context.handle(
        _pausedSecondsMeta,
        pausedSeconds.isAcceptableOrUnknown(
          data['paused_seconds']!,
          _pausedSecondsMeta,
        ),
      );
    }
    if (data.containsKey('paused_since')) {
      context.handle(
        _pausedSinceMeta,
        pausedSince.isAcceptableOrUnknown(
          data['paused_since']!,
          _pausedSinceMeta,
        ),
      );
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      durationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_seconds'],
      )!,
      completed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}completed'],
      )!,
      outcome: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}outcome'],
      ),
      pausedSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}paused_seconds'],
      )!,
      pausedSince: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}paused_since'],
      ),
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ended_at'],
      ),
    );
  }

  @override
  $SessionsTable createAlias(String alias) {
    return $SessionsTable(attachedDatabase, alias);
  }
}

class SessionRow extends DataClass implements Insertable<SessionRow> {
  final String id;

  /// The anchor, stored as UTC. Drift keeps `DateTime` columns as Unix seconds,
  /// which carry no zone; the mapping in `drift_session_repository.dart` is
  /// what guarantees a UTC instant goes in and a UTC instant comes out.
  final DateTime startedAt;

  /// The planned duration, in seconds.
  ///
  /// PRD §4.3 names this column `durationMinutes`. Seconds instead — see
  /// `docs/adr/0003-durations-are-stored-in-seconds.md`.
  final int durationSeconds;

  /// Whether the session reached its planned duration.
  ///
  /// Derived from [outcome] and written alongside it by
  /// `drift_session_repository.dart`, which is the only writer of either — so
  /// the two cannot disagree. Kept as a column of its own because every count
  /// in the app filters on it (ADR 0002), and a boolean is what an index on
  /// that filter wants.
  final bool completed;

  /// [SessionOutcome.name] — how the session ended, or null while it runs.
  ///
  /// Text rather than an ordinal, for the same reason [Plants.type] is: the
  /// rows stay readable, and stay correct if the enum is ever reordered.
  final String? outcome;

  /// How much of the session was spent paused, over every pause that finished.
  final int pausedSeconds;

  /// When the pause currently open began, or null if the session is not paused.
  ///
  /// Stored so that a session restored on a cold start comes back held if that
  /// is how the user left it. A session the user did *not* hold goes on
  /// counting down while the app is away, which is the whole of REQ-013's
  /// promise about backgrounding.
  final DateTime? pausedSince;

  /// When the session stopped running. Null while it runs.
  final DateTime? endedAt;
  const SessionRow({
    required this.id,
    required this.startedAt,
    required this.durationSeconds,
    required this.completed,
    this.outcome,
    required this.pausedSeconds,
    this.pausedSince,
    this.endedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['started_at'] = Variable<DateTime>(startedAt);
    map['duration_seconds'] = Variable<int>(durationSeconds);
    map['completed'] = Variable<bool>(completed);
    if (!nullToAbsent || outcome != null) {
      map['outcome'] = Variable<String>(outcome);
    }
    map['paused_seconds'] = Variable<int>(pausedSeconds);
    if (!nullToAbsent || pausedSince != null) {
      map['paused_since'] = Variable<DateTime>(pausedSince);
    }
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<DateTime>(endedAt);
    }
    return map;
  }

  SessionsCompanion toCompanion(bool nullToAbsent) {
    return SessionsCompanion(
      id: Value(id),
      startedAt: Value(startedAt),
      durationSeconds: Value(durationSeconds),
      completed: Value(completed),
      outcome: outcome == null && nullToAbsent
          ? const Value.absent()
          : Value(outcome),
      pausedSeconds: Value(pausedSeconds),
      pausedSince: pausedSince == null && nullToAbsent
          ? const Value.absent()
          : Value(pausedSince),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
    );
  }

  factory SessionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionRow(
      id: serializer.fromJson<String>(json['id']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      durationSeconds: serializer.fromJson<int>(json['durationSeconds']),
      completed: serializer.fromJson<bool>(json['completed']),
      outcome: serializer.fromJson<String?>(json['outcome']),
      pausedSeconds: serializer.fromJson<int>(json['pausedSeconds']),
      pausedSince: serializer.fromJson<DateTime?>(json['pausedSince']),
      endedAt: serializer.fromJson<DateTime?>(json['endedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'durationSeconds': serializer.toJson<int>(durationSeconds),
      'completed': serializer.toJson<bool>(completed),
      'outcome': serializer.toJson<String?>(outcome),
      'pausedSeconds': serializer.toJson<int>(pausedSeconds),
      'pausedSince': serializer.toJson<DateTime?>(pausedSince),
      'endedAt': serializer.toJson<DateTime?>(endedAt),
    };
  }

  SessionRow copyWith({
    String? id,
    DateTime? startedAt,
    int? durationSeconds,
    bool? completed,
    Value<String?> outcome = const Value.absent(),
    int? pausedSeconds,
    Value<DateTime?> pausedSince = const Value.absent(),
    Value<DateTime?> endedAt = const Value.absent(),
  }) => SessionRow(
    id: id ?? this.id,
    startedAt: startedAt ?? this.startedAt,
    durationSeconds: durationSeconds ?? this.durationSeconds,
    completed: completed ?? this.completed,
    outcome: outcome.present ? outcome.value : this.outcome,
    pausedSeconds: pausedSeconds ?? this.pausedSeconds,
    pausedSince: pausedSince.present ? pausedSince.value : this.pausedSince,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
  );
  SessionRow copyWithCompanion(SessionsCompanion data) {
    return SessionRow(
      id: data.id.present ? data.id.value : this.id,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
      completed: data.completed.present ? data.completed.value : this.completed,
      outcome: data.outcome.present ? data.outcome.value : this.outcome,
      pausedSeconds: data.pausedSeconds.present
          ? data.pausedSeconds.value
          : this.pausedSeconds,
      pausedSince: data.pausedSince.present
          ? data.pausedSince.value
          : this.pausedSince,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionRow(')
          ..write('id: $id, ')
          ..write('startedAt: $startedAt, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('completed: $completed, ')
          ..write('outcome: $outcome, ')
          ..write('pausedSeconds: $pausedSeconds, ')
          ..write('pausedSince: $pausedSince, ')
          ..write('endedAt: $endedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    startedAt,
    durationSeconds,
    completed,
    outcome,
    pausedSeconds,
    pausedSince,
    endedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionRow &&
          other.id == this.id &&
          other.startedAt == this.startedAt &&
          other.durationSeconds == this.durationSeconds &&
          other.completed == this.completed &&
          other.outcome == this.outcome &&
          other.pausedSeconds == this.pausedSeconds &&
          other.pausedSince == this.pausedSince &&
          other.endedAt == this.endedAt);
}

class SessionsCompanion extends UpdateCompanion<SessionRow> {
  final Value<String> id;
  final Value<DateTime> startedAt;
  final Value<int> durationSeconds;
  final Value<bool> completed;
  final Value<String?> outcome;
  final Value<int> pausedSeconds;
  final Value<DateTime?> pausedSince;
  final Value<DateTime?> endedAt;
  final Value<int> rowid;
  const SessionsCompanion({
    this.id = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.completed = const Value.absent(),
    this.outcome = const Value.absent(),
    this.pausedSeconds = const Value.absent(),
    this.pausedSince = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionsCompanion.insert({
    required String id,
    required DateTime startedAt,
    required int durationSeconds,
    this.completed = const Value.absent(),
    this.outcome = const Value.absent(),
    this.pausedSeconds = const Value.absent(),
    this.pausedSince = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       startedAt = Value(startedAt),
       durationSeconds = Value(durationSeconds);
  static Insertable<SessionRow> custom({
    Expression<String>? id,
    Expression<DateTime>? startedAt,
    Expression<int>? durationSeconds,
    Expression<bool>? completed,
    Expression<String>? outcome,
    Expression<int>? pausedSeconds,
    Expression<DateTime>? pausedSince,
    Expression<DateTime>? endedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (startedAt != null) 'started_at': startedAt,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (completed != null) 'completed': completed,
      if (outcome != null) 'outcome': outcome,
      if (pausedSeconds != null) 'paused_seconds': pausedSeconds,
      if (pausedSince != null) 'paused_since': pausedSince,
      if (endedAt != null) 'ended_at': endedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionsCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? startedAt,
    Value<int>? durationSeconds,
    Value<bool>? completed,
    Value<String?>? outcome,
    Value<int>? pausedSeconds,
    Value<DateTime?>? pausedSince,
    Value<DateTime?>? endedAt,
    Value<int>? rowid,
  }) {
    return SessionsCompanion(
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      completed: completed ?? this.completed,
      outcome: outcome ?? this.outcome,
      pausedSeconds: pausedSeconds ?? this.pausedSeconds,
      pausedSince: pausedSince ?? this.pausedSince,
      endedAt: endedAt ?? this.endedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    if (completed.present) {
      map['completed'] = Variable<bool>(completed.value);
    }
    if (outcome.present) {
      map['outcome'] = Variable<String>(outcome.value);
    }
    if (pausedSeconds.present) {
      map['paused_seconds'] = Variable<int>(pausedSeconds.value);
    }
    if (pausedSince.present) {
      map['paused_since'] = Variable<DateTime>(pausedSince.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionsCompanion(')
          ..write('id: $id, ')
          ..write('startedAt: $startedAt, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('completed: $completed, ')
          ..write('outcome: $outcome, ')
          ..write('pausedSeconds: $pausedSeconds, ')
          ..write('pausedSince: $pausedSince, ')
          ..write('endedAt: $endedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings
    with TableInfo<$SettingsTable, SettingsRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _sessionLengthSecondsMeta =
      const VerificationMeta('sessionLengthSeconds');
  @override
  late final GeneratedColumn<int> sessionLengthSeconds = GeneratedColumn<int>(
    'session_length_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _breakLengthSecondsMeta =
      const VerificationMeta('breakLengthSeconds');
  @override
  late final GeneratedColumn<int> breakLengthSeconds = GeneratedColumn<int>(
    'break_length_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _longBreakAfterSessionsMeta =
      const VerificationMeta('longBreakAfterSessions');
  @override
  late final GeneratedColumn<int> longBreakAfterSessions = GeneratedColumn<int>(
    'long_break_after_sessions',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hapticsEnabledMeta = const VerificationMeta(
    'hapticsEnabled',
  );
  @override
  late final GeneratedColumn<bool> hapticsEnabled = GeneratedColumn<bool>(
    'haptics_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("haptics_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _liveSurfaceEnabledMeta =
      const VerificationMeta('liveSurfaceEnabled');
  @override
  late final GeneratedColumn<bool> liveSurfaceEnabled = GeneratedColumn<bool>(
    'live_surface_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("live_surface_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _autoStartBreakMeta = const VerificationMeta(
    'autoStartBreak',
  );
  @override
  late final GeneratedColumn<bool> autoStartBreak = GeneratedColumn<bool>(
    'auto_start_break',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("auto_start_break" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _autoStartNextSessionMeta =
      const VerificationMeta('autoStartNextSession');
  @override
  late final GeneratedColumn<bool> autoStartNextSession = GeneratedColumn<bool>(
    'auto_start_next_session',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("auto_start_next_session" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _ambientSoundMeta = const VerificationMeta(
    'ambientSound',
  );
  @override
  late final GeneratedColumn<String> ambientSound = GeneratedColumn<String>(
    'ambient_sound',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('silence'),
  );
  static const VerificationMeta _endSoundMeta = const VerificationMeta(
    'endSound',
  );
  @override
  late final GeneratedColumn<String> endSound = GeneratedColumn<String>(
    'end_sound',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('windChime'),
  );
  static const VerificationMeta _gardenThemeMeta = const VerificationMeta(
    'gardenTheme',
  );
  @override
  late final GeneratedColumn<String> gardenTheme = GeneratedColumn<String>(
    'garden_theme',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('zen'),
  );
  static const VerificationMeta _quietModeEnabledMeta = const VerificationMeta(
    'quietModeEnabled',
  );
  @override
  late final GeneratedColumn<bool> quietModeEnabled = GeneratedColumn<bool>(
    'quiet_mode_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("quiet_mode_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _quietModeHintDismissedMeta =
      const VerificationMeta('quietModeHintDismissed');
  @override
  late final GeneratedColumn<bool> quietModeHintDismissed =
      GeneratedColumn<bool>(
        'quiet_mode_hint_dismissed',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("quiet_mode_hint_dismissed" IN (0, 1))',
        ),
        defaultValue: const Constant(false),
      );
  static const VerificationMeta _onboardingCompletedMeta =
      const VerificationMeta('onboardingCompleted');
  @override
  late final GeneratedColumn<bool> onboardingCompleted = GeneratedColumn<bool>(
    'onboarding_completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("onboarding_completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionLengthSeconds,
    breakLengthSeconds,
    longBreakAfterSessions,
    hapticsEnabled,
    liveSurfaceEnabled,
    autoStartBreak,
    autoStartNextSession,
    ambientSound,
    endSound,
    gardenTheme,
    quietModeEnabled,
    quietModeHintDismissed,
    onboardingCompleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingsRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('session_length_seconds')) {
      context.handle(
        _sessionLengthSecondsMeta,
        sessionLengthSeconds.isAcceptableOrUnknown(
          data['session_length_seconds']!,
          _sessionLengthSecondsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sessionLengthSecondsMeta);
    }
    if (data.containsKey('break_length_seconds')) {
      context.handle(
        _breakLengthSecondsMeta,
        breakLengthSeconds.isAcceptableOrUnknown(
          data['break_length_seconds']!,
          _breakLengthSecondsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_breakLengthSecondsMeta);
    }
    if (data.containsKey('long_break_after_sessions')) {
      context.handle(
        _longBreakAfterSessionsMeta,
        longBreakAfterSessions.isAcceptableOrUnknown(
          data['long_break_after_sessions']!,
          _longBreakAfterSessionsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_longBreakAfterSessionsMeta);
    }
    if (data.containsKey('haptics_enabled')) {
      context.handle(
        _hapticsEnabledMeta,
        hapticsEnabled.isAcceptableOrUnknown(
          data['haptics_enabled']!,
          _hapticsEnabledMeta,
        ),
      );
    }
    if (data.containsKey('live_surface_enabled')) {
      context.handle(
        _liveSurfaceEnabledMeta,
        liveSurfaceEnabled.isAcceptableOrUnknown(
          data['live_surface_enabled']!,
          _liveSurfaceEnabledMeta,
        ),
      );
    }
    if (data.containsKey('auto_start_break')) {
      context.handle(
        _autoStartBreakMeta,
        autoStartBreak.isAcceptableOrUnknown(
          data['auto_start_break']!,
          _autoStartBreakMeta,
        ),
      );
    }
    if (data.containsKey('auto_start_next_session')) {
      context.handle(
        _autoStartNextSessionMeta,
        autoStartNextSession.isAcceptableOrUnknown(
          data['auto_start_next_session']!,
          _autoStartNextSessionMeta,
        ),
      );
    }
    if (data.containsKey('ambient_sound')) {
      context.handle(
        _ambientSoundMeta,
        ambientSound.isAcceptableOrUnknown(
          data['ambient_sound']!,
          _ambientSoundMeta,
        ),
      );
    }
    if (data.containsKey('end_sound')) {
      context.handle(
        _endSoundMeta,
        endSound.isAcceptableOrUnknown(data['end_sound']!, _endSoundMeta),
      );
    }
    if (data.containsKey('garden_theme')) {
      context.handle(
        _gardenThemeMeta,
        gardenTheme.isAcceptableOrUnknown(
          data['garden_theme']!,
          _gardenThemeMeta,
        ),
      );
    }
    if (data.containsKey('quiet_mode_enabled')) {
      context.handle(
        _quietModeEnabledMeta,
        quietModeEnabled.isAcceptableOrUnknown(
          data['quiet_mode_enabled']!,
          _quietModeEnabledMeta,
        ),
      );
    }
    if (data.containsKey('quiet_mode_hint_dismissed')) {
      context.handle(
        _quietModeHintDismissedMeta,
        quietModeHintDismissed.isAcceptableOrUnknown(
          data['quiet_mode_hint_dismissed']!,
          _quietModeHintDismissedMeta,
        ),
      );
    }
    if (data.containsKey('onboarding_completed')) {
      context.handle(
        _onboardingCompletedMeta,
        onboardingCompleted.isAcceptableOrUnknown(
          data['onboarding_completed']!,
          _onboardingCompletedMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SettingsRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingsRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sessionLengthSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}session_length_seconds'],
      )!,
      breakLengthSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}break_length_seconds'],
      )!,
      longBreakAfterSessions: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}long_break_after_sessions'],
      )!,
      hapticsEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}haptics_enabled'],
      )!,
      liveSurfaceEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}live_surface_enabled'],
      )!,
      autoStartBreak: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}auto_start_break'],
      )!,
      autoStartNextSession: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}auto_start_next_session'],
      )!,
      ambientSound: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ambient_sound'],
      )!,
      endSound: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}end_sound'],
      )!,
      gardenTheme: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}garden_theme'],
      )!,
      quietModeEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}quiet_mode_enabled'],
      )!,
      quietModeHintDismissed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}quiet_mode_hint_dismissed'],
      )!,
      onboardingCompleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}onboarding_completed'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class SettingsRow extends DataClass implements Insertable<SettingsRow> {
  /// Pinned to 1 by [customConstraints]. Present at all because SQLite wants a
  /// key, not because there is ever a second row to tell apart.
  ///
  /// The 1 is written out here and in the constraint rather than read from
  /// [AppDatabase.settingsRowId], because both are read at build time by
  /// drift's generator, which resolves literals and not references.
  final int id;

  /// The planned duration of the next session, in seconds. PRD §4.3 names this
  /// `sessionLengthMinutes`; seconds instead, for the reasons in
  /// `docs/adr/0003-durations-are-stored-in-seconds.md`.
  final int sessionLengthSeconds;

  /// How long a break runs, in seconds. Same departure from §4.3's
  /// `breakLengthMinutes`, same reason.
  final int breakLengthSeconds;

  /// How many focus sessions run before the break becomes a long one.
  final int longBreakAfterSessions;

  /// REQ-037: whether a completing session and a growing plant are allowed to
  /// buzz. Defaulted rather than nullable, so a row written before ticket 06
  /// reads as on — which is what a user who never turned it off means.
  final bool hapticsEnabled;

  /// REQ-033: whether a running session is shown outside the app. Defaulted to
  /// on for the same reason [hapticsEnabled] is — a row written before ticket
  /// 08 belongs to a user who never had the switch to turn off.
  final bool liveSurfaceEnabled;

  /// REQ-032: whether a break begins on its own when a session finishes.
  ///
  /// Defaulted to *off*, unlike the two switches above it, and that is the
  /// requirement rather than an oversight: a user upgrading into ticket 09 has
  /// never asked the app to start anything for them, and the first thing they
  /// should not meet is a timer that began counting without being asked.
  final bool autoStartBreak;

  /// REQ-032: whether a focus session begins on its own when a break ends. Off
  /// by default, for the reason [autoStartBreak] is.
  final bool autoStartNextSession;

  /// REQ-012: [AmbientSound.name] — which bed plays under a focus session.
  ///
  /// Text rather than an ordinal, for the reason [Plants.type] is: the rows
  /// stay readable, and stay correct if the enum is ever reordered. Defaulted
  /// to silence, which is both the setting a row written before this ticket
  /// means and the one a fresh install starts on — an app that began making
  /// rain because a user upgraded would have decided something about the room
  /// they are sitting in.
  final String ambientSound;

  /// REQ-031: [EndSound.name] — which sound a finished session makes.
  ///
  /// Text rather than an ordinal, for the reason [ambientSound] is. Defaulted
  /// to the wind chime rather than to `none`, which is the opposite of the bed
  /// above it and right for the opposite reason: a user upgrading into this
  /// ticket has been hearing the chime since ticket 06, and a default of
  /// silence would take away a sound they never asked to lose.
  final String endSound;

  /// REQ-034: [GardenTheme.name] — which biome the garden is dressed in.
  ///
  /// Text rather than an ordinal, for the reason [ambientSound] is: the rows
  /// stay readable and stay correct if the enum is ever reordered. Defaulted to
  /// `zen` — so a row written before this ticket, and a row naming a theme this
  /// build does not have, both read as the garden every install starts in.
  final String gardenTheme;

  /// REQ-014: whether the phone is asked to go quiet for the length of a
  /// session.
  ///
  /// Defaulted to *off*, like the two auto-start switches and for a sharper
  /// version of their reason: this one decides which of the user's calls get
  /// through, and nobody upgrading into this ticket has asked for that.
  final bool quietModeEnabled;

  /// Whether the one-time hint about silencing a phone the app cannot silence
  /// itself has been put away.
  ///
  /// Not a preference, and stored here anyway: this is the app's single-row
  /// store, and a second table for one boolean would be a table to migrate for
  /// the rest of the app's life. PRD §4.3 keeps `onboardingCompleted` here for
  /// the same reason.
  final bool quietModeHintDismissed;

  /// REQ-003: whether the user has been through onboarding.
  ///
  /// Defaulted to *false*, which reads oddly beside the columns above it and is
  /// right for the same reason they are: a fresh install has no row at all, so
  /// what this default describes is only the value a row written before this
  /// column existed would take. The migration step that adds it does not leave
  /// it at that default — see the 12 → 13 case in [AppDatabase.migration] —
  /// because a row on disk means a user who has been using the app, and showing
  /// them a welcome screen on upgrade would be the app forgetting them.
  final bool onboardingCompleted;
  const SettingsRow({
    required this.id,
    required this.sessionLengthSeconds,
    required this.breakLengthSeconds,
    required this.longBreakAfterSessions,
    required this.hapticsEnabled,
    required this.liveSurfaceEnabled,
    required this.autoStartBreak,
    required this.autoStartNextSession,
    required this.ambientSound,
    required this.endSound,
    required this.gardenTheme,
    required this.quietModeEnabled,
    required this.quietModeHintDismissed,
    required this.onboardingCompleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['session_length_seconds'] = Variable<int>(sessionLengthSeconds);
    map['break_length_seconds'] = Variable<int>(breakLengthSeconds);
    map['long_break_after_sessions'] = Variable<int>(longBreakAfterSessions);
    map['haptics_enabled'] = Variable<bool>(hapticsEnabled);
    map['live_surface_enabled'] = Variable<bool>(liveSurfaceEnabled);
    map['auto_start_break'] = Variable<bool>(autoStartBreak);
    map['auto_start_next_session'] = Variable<bool>(autoStartNextSession);
    map['ambient_sound'] = Variable<String>(ambientSound);
    map['end_sound'] = Variable<String>(endSound);
    map['garden_theme'] = Variable<String>(gardenTheme);
    map['quiet_mode_enabled'] = Variable<bool>(quietModeEnabled);
    map['quiet_mode_hint_dismissed'] = Variable<bool>(quietModeHintDismissed);
    map['onboarding_completed'] = Variable<bool>(onboardingCompleted);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(
      id: Value(id),
      sessionLengthSeconds: Value(sessionLengthSeconds),
      breakLengthSeconds: Value(breakLengthSeconds),
      longBreakAfterSessions: Value(longBreakAfterSessions),
      hapticsEnabled: Value(hapticsEnabled),
      liveSurfaceEnabled: Value(liveSurfaceEnabled),
      autoStartBreak: Value(autoStartBreak),
      autoStartNextSession: Value(autoStartNextSession),
      ambientSound: Value(ambientSound),
      endSound: Value(endSound),
      gardenTheme: Value(gardenTheme),
      quietModeEnabled: Value(quietModeEnabled),
      quietModeHintDismissed: Value(quietModeHintDismissed),
      onboardingCompleted: Value(onboardingCompleted),
    );
  }

  factory SettingsRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingsRow(
      id: serializer.fromJson<int>(json['id']),
      sessionLengthSeconds: serializer.fromJson<int>(
        json['sessionLengthSeconds'],
      ),
      breakLengthSeconds: serializer.fromJson<int>(json['breakLengthSeconds']),
      longBreakAfterSessions: serializer.fromJson<int>(
        json['longBreakAfterSessions'],
      ),
      hapticsEnabled: serializer.fromJson<bool>(json['hapticsEnabled']),
      liveSurfaceEnabled: serializer.fromJson<bool>(json['liveSurfaceEnabled']),
      autoStartBreak: serializer.fromJson<bool>(json['autoStartBreak']),
      autoStartNextSession: serializer.fromJson<bool>(
        json['autoStartNextSession'],
      ),
      ambientSound: serializer.fromJson<String>(json['ambientSound']),
      endSound: serializer.fromJson<String>(json['endSound']),
      gardenTheme: serializer.fromJson<String>(json['gardenTheme']),
      quietModeEnabled: serializer.fromJson<bool>(json['quietModeEnabled']),
      quietModeHintDismissed: serializer.fromJson<bool>(
        json['quietModeHintDismissed'],
      ),
      onboardingCompleted: serializer.fromJson<bool>(
        json['onboardingCompleted'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sessionLengthSeconds': serializer.toJson<int>(sessionLengthSeconds),
      'breakLengthSeconds': serializer.toJson<int>(breakLengthSeconds),
      'longBreakAfterSessions': serializer.toJson<int>(longBreakAfterSessions),
      'hapticsEnabled': serializer.toJson<bool>(hapticsEnabled),
      'liveSurfaceEnabled': serializer.toJson<bool>(liveSurfaceEnabled),
      'autoStartBreak': serializer.toJson<bool>(autoStartBreak),
      'autoStartNextSession': serializer.toJson<bool>(autoStartNextSession),
      'ambientSound': serializer.toJson<String>(ambientSound),
      'endSound': serializer.toJson<String>(endSound),
      'gardenTheme': serializer.toJson<String>(gardenTheme),
      'quietModeEnabled': serializer.toJson<bool>(quietModeEnabled),
      'quietModeHintDismissed': serializer.toJson<bool>(quietModeHintDismissed),
      'onboardingCompleted': serializer.toJson<bool>(onboardingCompleted),
    };
  }

  SettingsRow copyWith({
    int? id,
    int? sessionLengthSeconds,
    int? breakLengthSeconds,
    int? longBreakAfterSessions,
    bool? hapticsEnabled,
    bool? liveSurfaceEnabled,
    bool? autoStartBreak,
    bool? autoStartNextSession,
    String? ambientSound,
    String? endSound,
    String? gardenTheme,
    bool? quietModeEnabled,
    bool? quietModeHintDismissed,
    bool? onboardingCompleted,
  }) => SettingsRow(
    id: id ?? this.id,
    sessionLengthSeconds: sessionLengthSeconds ?? this.sessionLengthSeconds,
    breakLengthSeconds: breakLengthSeconds ?? this.breakLengthSeconds,
    longBreakAfterSessions:
        longBreakAfterSessions ?? this.longBreakAfterSessions,
    hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
    liveSurfaceEnabled: liveSurfaceEnabled ?? this.liveSurfaceEnabled,
    autoStartBreak: autoStartBreak ?? this.autoStartBreak,
    autoStartNextSession: autoStartNextSession ?? this.autoStartNextSession,
    ambientSound: ambientSound ?? this.ambientSound,
    endSound: endSound ?? this.endSound,
    gardenTheme: gardenTheme ?? this.gardenTheme,
    quietModeEnabled: quietModeEnabled ?? this.quietModeEnabled,
    quietModeHintDismissed:
        quietModeHintDismissed ?? this.quietModeHintDismissed,
    onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
  );
  SettingsRow copyWithCompanion(SettingsCompanion data) {
    return SettingsRow(
      id: data.id.present ? data.id.value : this.id,
      sessionLengthSeconds: data.sessionLengthSeconds.present
          ? data.sessionLengthSeconds.value
          : this.sessionLengthSeconds,
      breakLengthSeconds: data.breakLengthSeconds.present
          ? data.breakLengthSeconds.value
          : this.breakLengthSeconds,
      longBreakAfterSessions: data.longBreakAfterSessions.present
          ? data.longBreakAfterSessions.value
          : this.longBreakAfterSessions,
      hapticsEnabled: data.hapticsEnabled.present
          ? data.hapticsEnabled.value
          : this.hapticsEnabled,
      liveSurfaceEnabled: data.liveSurfaceEnabled.present
          ? data.liveSurfaceEnabled.value
          : this.liveSurfaceEnabled,
      autoStartBreak: data.autoStartBreak.present
          ? data.autoStartBreak.value
          : this.autoStartBreak,
      autoStartNextSession: data.autoStartNextSession.present
          ? data.autoStartNextSession.value
          : this.autoStartNextSession,
      ambientSound: data.ambientSound.present
          ? data.ambientSound.value
          : this.ambientSound,
      endSound: data.endSound.present ? data.endSound.value : this.endSound,
      gardenTheme: data.gardenTheme.present
          ? data.gardenTheme.value
          : this.gardenTheme,
      quietModeEnabled: data.quietModeEnabled.present
          ? data.quietModeEnabled.value
          : this.quietModeEnabled,
      quietModeHintDismissed: data.quietModeHintDismissed.present
          ? data.quietModeHintDismissed.value
          : this.quietModeHintDismissed,
      onboardingCompleted: data.onboardingCompleted.present
          ? data.onboardingCompleted.value
          : this.onboardingCompleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingsRow(')
          ..write('id: $id, ')
          ..write('sessionLengthSeconds: $sessionLengthSeconds, ')
          ..write('breakLengthSeconds: $breakLengthSeconds, ')
          ..write('longBreakAfterSessions: $longBreakAfterSessions, ')
          ..write('hapticsEnabled: $hapticsEnabled, ')
          ..write('liveSurfaceEnabled: $liveSurfaceEnabled, ')
          ..write('autoStartBreak: $autoStartBreak, ')
          ..write('autoStartNextSession: $autoStartNextSession, ')
          ..write('ambientSound: $ambientSound, ')
          ..write('endSound: $endSound, ')
          ..write('gardenTheme: $gardenTheme, ')
          ..write('quietModeEnabled: $quietModeEnabled, ')
          ..write('quietModeHintDismissed: $quietModeHintDismissed, ')
          ..write('onboardingCompleted: $onboardingCompleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionLengthSeconds,
    breakLengthSeconds,
    longBreakAfterSessions,
    hapticsEnabled,
    liveSurfaceEnabled,
    autoStartBreak,
    autoStartNextSession,
    ambientSound,
    endSound,
    gardenTheme,
    quietModeEnabled,
    quietModeHintDismissed,
    onboardingCompleted,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingsRow &&
          other.id == this.id &&
          other.sessionLengthSeconds == this.sessionLengthSeconds &&
          other.breakLengthSeconds == this.breakLengthSeconds &&
          other.longBreakAfterSessions == this.longBreakAfterSessions &&
          other.hapticsEnabled == this.hapticsEnabled &&
          other.liveSurfaceEnabled == this.liveSurfaceEnabled &&
          other.autoStartBreak == this.autoStartBreak &&
          other.autoStartNextSession == this.autoStartNextSession &&
          other.ambientSound == this.ambientSound &&
          other.endSound == this.endSound &&
          other.gardenTheme == this.gardenTheme &&
          other.quietModeEnabled == this.quietModeEnabled &&
          other.quietModeHintDismissed == this.quietModeHintDismissed &&
          other.onboardingCompleted == this.onboardingCompleted);
}

class SettingsCompanion extends UpdateCompanion<SettingsRow> {
  final Value<int> id;
  final Value<int> sessionLengthSeconds;
  final Value<int> breakLengthSeconds;
  final Value<int> longBreakAfterSessions;
  final Value<bool> hapticsEnabled;
  final Value<bool> liveSurfaceEnabled;
  final Value<bool> autoStartBreak;
  final Value<bool> autoStartNextSession;
  final Value<String> ambientSound;
  final Value<String> endSound;
  final Value<String> gardenTheme;
  final Value<bool> quietModeEnabled;
  final Value<bool> quietModeHintDismissed;
  final Value<bool> onboardingCompleted;
  const SettingsCompanion({
    this.id = const Value.absent(),
    this.sessionLengthSeconds = const Value.absent(),
    this.breakLengthSeconds = const Value.absent(),
    this.longBreakAfterSessions = const Value.absent(),
    this.hapticsEnabled = const Value.absent(),
    this.liveSurfaceEnabled = const Value.absent(),
    this.autoStartBreak = const Value.absent(),
    this.autoStartNextSession = const Value.absent(),
    this.ambientSound = const Value.absent(),
    this.endSound = const Value.absent(),
    this.gardenTheme = const Value.absent(),
    this.quietModeEnabled = const Value.absent(),
    this.quietModeHintDismissed = const Value.absent(),
    this.onboardingCompleted = const Value.absent(),
  });
  SettingsCompanion.insert({
    this.id = const Value.absent(),
    required int sessionLengthSeconds,
    required int breakLengthSeconds,
    required int longBreakAfterSessions,
    this.hapticsEnabled = const Value.absent(),
    this.liveSurfaceEnabled = const Value.absent(),
    this.autoStartBreak = const Value.absent(),
    this.autoStartNextSession = const Value.absent(),
    this.ambientSound = const Value.absent(),
    this.endSound = const Value.absent(),
    this.gardenTheme = const Value.absent(),
    this.quietModeEnabled = const Value.absent(),
    this.quietModeHintDismissed = const Value.absent(),
    this.onboardingCompleted = const Value.absent(),
  }) : sessionLengthSeconds = Value(sessionLengthSeconds),
       breakLengthSeconds = Value(breakLengthSeconds),
       longBreakAfterSessions = Value(longBreakAfterSessions);
  static Insertable<SettingsRow> custom({
    Expression<int>? id,
    Expression<int>? sessionLengthSeconds,
    Expression<int>? breakLengthSeconds,
    Expression<int>? longBreakAfterSessions,
    Expression<bool>? hapticsEnabled,
    Expression<bool>? liveSurfaceEnabled,
    Expression<bool>? autoStartBreak,
    Expression<bool>? autoStartNextSession,
    Expression<String>? ambientSound,
    Expression<String>? endSound,
    Expression<String>? gardenTheme,
    Expression<bool>? quietModeEnabled,
    Expression<bool>? quietModeHintDismissed,
    Expression<bool>? onboardingCompleted,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionLengthSeconds != null)
        'session_length_seconds': sessionLengthSeconds,
      if (breakLengthSeconds != null)
        'break_length_seconds': breakLengthSeconds,
      if (longBreakAfterSessions != null)
        'long_break_after_sessions': longBreakAfterSessions,
      if (hapticsEnabled != null) 'haptics_enabled': hapticsEnabled,
      if (liveSurfaceEnabled != null)
        'live_surface_enabled': liveSurfaceEnabled,
      if (autoStartBreak != null) 'auto_start_break': autoStartBreak,
      if (autoStartNextSession != null)
        'auto_start_next_session': autoStartNextSession,
      if (ambientSound != null) 'ambient_sound': ambientSound,
      if (endSound != null) 'end_sound': endSound,
      if (gardenTheme != null) 'garden_theme': gardenTheme,
      if (quietModeEnabled != null) 'quiet_mode_enabled': quietModeEnabled,
      if (quietModeHintDismissed != null)
        'quiet_mode_hint_dismissed': quietModeHintDismissed,
      if (onboardingCompleted != null)
        'onboarding_completed': onboardingCompleted,
    });
  }

  SettingsCompanion copyWith({
    Value<int>? id,
    Value<int>? sessionLengthSeconds,
    Value<int>? breakLengthSeconds,
    Value<int>? longBreakAfterSessions,
    Value<bool>? hapticsEnabled,
    Value<bool>? liveSurfaceEnabled,
    Value<bool>? autoStartBreak,
    Value<bool>? autoStartNextSession,
    Value<String>? ambientSound,
    Value<String>? endSound,
    Value<String>? gardenTheme,
    Value<bool>? quietModeEnabled,
    Value<bool>? quietModeHintDismissed,
    Value<bool>? onboardingCompleted,
  }) {
    return SettingsCompanion(
      id: id ?? this.id,
      sessionLengthSeconds: sessionLengthSeconds ?? this.sessionLengthSeconds,
      breakLengthSeconds: breakLengthSeconds ?? this.breakLengthSeconds,
      longBreakAfterSessions:
          longBreakAfterSessions ?? this.longBreakAfterSessions,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      liveSurfaceEnabled: liveSurfaceEnabled ?? this.liveSurfaceEnabled,
      autoStartBreak: autoStartBreak ?? this.autoStartBreak,
      autoStartNextSession: autoStartNextSession ?? this.autoStartNextSession,
      ambientSound: ambientSound ?? this.ambientSound,
      endSound: endSound ?? this.endSound,
      gardenTheme: gardenTheme ?? this.gardenTheme,
      quietModeEnabled: quietModeEnabled ?? this.quietModeEnabled,
      quietModeHintDismissed:
          quietModeHintDismissed ?? this.quietModeHintDismissed,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sessionLengthSeconds.present) {
      map['session_length_seconds'] = Variable<int>(sessionLengthSeconds.value);
    }
    if (breakLengthSeconds.present) {
      map['break_length_seconds'] = Variable<int>(breakLengthSeconds.value);
    }
    if (longBreakAfterSessions.present) {
      map['long_break_after_sessions'] = Variable<int>(
        longBreakAfterSessions.value,
      );
    }
    if (hapticsEnabled.present) {
      map['haptics_enabled'] = Variable<bool>(hapticsEnabled.value);
    }
    if (liveSurfaceEnabled.present) {
      map['live_surface_enabled'] = Variable<bool>(liveSurfaceEnabled.value);
    }
    if (autoStartBreak.present) {
      map['auto_start_break'] = Variable<bool>(autoStartBreak.value);
    }
    if (autoStartNextSession.present) {
      map['auto_start_next_session'] = Variable<bool>(
        autoStartNextSession.value,
      );
    }
    if (ambientSound.present) {
      map['ambient_sound'] = Variable<String>(ambientSound.value);
    }
    if (endSound.present) {
      map['end_sound'] = Variable<String>(endSound.value);
    }
    if (gardenTheme.present) {
      map['garden_theme'] = Variable<String>(gardenTheme.value);
    }
    if (quietModeEnabled.present) {
      map['quiet_mode_enabled'] = Variable<bool>(quietModeEnabled.value);
    }
    if (quietModeHintDismissed.present) {
      map['quiet_mode_hint_dismissed'] = Variable<bool>(
        quietModeHintDismissed.value,
      );
    }
    if (onboardingCompleted.present) {
      map['onboarding_completed'] = Variable<bool>(onboardingCompleted.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('id: $id, ')
          ..write('sessionLengthSeconds: $sessionLengthSeconds, ')
          ..write('breakLengthSeconds: $breakLengthSeconds, ')
          ..write('longBreakAfterSessions: $longBreakAfterSessions, ')
          ..write('hapticsEnabled: $hapticsEnabled, ')
          ..write('liveSurfaceEnabled: $liveSurfaceEnabled, ')
          ..write('autoStartBreak: $autoStartBreak, ')
          ..write('autoStartNextSession: $autoStartNextSession, ')
          ..write('ambientSound: $ambientSound, ')
          ..write('endSound: $endSound, ')
          ..write('gardenTheme: $gardenTheme, ')
          ..write('quietModeEnabled: $quietModeEnabled, ')
          ..write('quietModeHintDismissed: $quietModeHintDismissed, ')
          ..write('onboardingCompleted: $onboardingCompleted')
          ..write(')'))
        .toString();
  }
}

class $PlantsTable extends Plants with TableInfo<$PlantsTable, PlantRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlantsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _speciesMeta = const VerificationMeta(
    'species',
  );
  @override
  late final GeneratedColumn<String> species = GeneratedColumn<String>(
    'species',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _growthStageMeta = const VerificationMeta(
    'growthStage',
  );
  @override
  late final GeneratedColumn<int> growthStage = GeneratedColumn<int>(
    'growth_stage',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _plantedAtMeta = const VerificationMeta(
    'plantedAt',
  );
  @override
  late final GeneratedColumn<DateTime> plantedAt = GeneratedColumn<DateTime>(
    'planted_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionDurationSecondsMeta =
      const VerificationMeta('sessionDurationSeconds');
  @override
  late final GeneratedColumn<int> sessionDurationSeconds = GeneratedColumn<int>(
    'session_duration_seconds',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _milestoneSessionsMeta = const VerificationMeta(
    'milestoneSessions',
  );
  @override
  late final GeneratedColumn<int> milestoneSessions = GeneratedColumn<int>(
    'milestone_sessions',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _plotXMeta = const VerificationMeta('plotX');
  @override
  late final GeneratedColumn<int> plotX = GeneratedColumn<int>(
    'plot_x',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _plotYMeta = const VerificationMeta('plotY');
  @override
  late final GeneratedColumn<int> plotY = GeneratedColumn<int>(
    'plot_y',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    type,
    species,
    growthStage,
    plantedAt,
    sessionDurationSeconds,
    milestoneSessions,
    plotX,
    plotY,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'plants';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlantRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('species')) {
      context.handle(
        _speciesMeta,
        species.isAcceptableOrUnknown(data['species']!, _speciesMeta),
      );
    } else if (isInserting) {
      context.missing(_speciesMeta);
    }
    if (data.containsKey('growth_stage')) {
      context.handle(
        _growthStageMeta,
        growthStage.isAcceptableOrUnknown(
          data['growth_stage']!,
          _growthStageMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_growthStageMeta);
    }
    if (data.containsKey('planted_at')) {
      context.handle(
        _plantedAtMeta,
        plantedAt.isAcceptableOrUnknown(data['planted_at']!, _plantedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_plantedAtMeta);
    }
    if (data.containsKey('session_duration_seconds')) {
      context.handle(
        _sessionDurationSecondsMeta,
        sessionDurationSeconds.isAcceptableOrUnknown(
          data['session_duration_seconds']!,
          _sessionDurationSecondsMeta,
        ),
      );
    }
    if (data.containsKey('milestone_sessions')) {
      context.handle(
        _milestoneSessionsMeta,
        milestoneSessions.isAcceptableOrUnknown(
          data['milestone_sessions']!,
          _milestoneSessionsMeta,
        ),
      );
    }
    if (data.containsKey('plot_x')) {
      context.handle(
        _plotXMeta,
        plotX.isAcceptableOrUnknown(data['plot_x']!, _plotXMeta),
      );
    }
    if (data.containsKey('plot_y')) {
      context.handle(
        _plotYMeta,
        plotY.isAcceptableOrUnknown(data['plot_y']!, _plotYMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {sessionId},
    {milestoneSessions},
  ];
  @override
  PlantRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlantRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      ),
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      species: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}species'],
      )!,
      growthStage: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}growth_stage'],
      )!,
      plantedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}planted_at'],
      )!,
      sessionDurationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}session_duration_seconds'],
      ),
      milestoneSessions: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}milestone_sessions'],
      ),
      plotX: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}plot_x'],
      ),
      plotY: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}plot_y'],
      ),
    );
  }

  @override
  $PlantsTable createAlias(String alias) {
    return $PlantsTable(attachedDatabase, alias);
  }
}

class PlantRow extends DataClass implements Insertable<PlantRow> {
  final String id;

  /// The session this plant grew from. Null for a plant no session earned.
  ///
  /// Not a foreign key, and ticket 22 is what settled that it does not need to
  /// be. The only thing in the app that deletes a session is REQ-036's reset,
  /// and it deletes every plant in the same transaction — see
  /// `DriftGardenReset`. A cascade would be a rule for a case that cannot
  /// arise: there is no way in this app to delete one session and leave its
  /// plant standing, and adding a constraint to forbid it would be adding a
  /// migration to say something already true.
  final String? sessionId;

  /// [PlantType.name]. Text rather than an ordinal so the rows stay readable
  /// and stay correct if the enum is ever reordered.
  final String type;

  /// [PlantSpecies.name].
  final String species;

  /// [GrowthStage.index], 0 to 4, as PRD §4.3 specifies.
  final int growthStage;

  /// When the seed went into the soil: the session's anchor, in UTC.
  final DateTime plantedAt;

  /// The planned duration of the session that grew this, in seconds. §4.3 names
  /// this `sessionDurationMinutes`; seconds instead, per ADR 0003.
  ///
  /// Nullable from version 11, for REQ-021's bonus plants: no session grew one,
  /// so it has no duration. Zero would have avoided a migration and would have
  /// been a lie — "a session of no length" is a different claim from "no
  /// session", and it is the one a card would read out.
  final int? sessionDurationSeconds;

  /// [Milestone.sessions] — which milestone awarded this plant, or null if a
  /// session grew it: §4.3's `milestoneSessions`.
  ///
  /// The count rather than the enum's name, because the count *is* the
  /// milestone's identity — renaming a member then costs nothing and changing
  /// one of REQ-021's numbers is a migration, which is the right way round.
  ///
  /// §4.3 also carries an `isBonusPlant` boolean beside this. It is not here:
  /// a plant is a bonus plant exactly when this column is set, and a second
  /// column that could disagree with the first is a bug waiting for the write
  /// that sets only one of them.
  final int? milestoneSessions;

  /// Where in the isometric grid this plant stands — §4.3's `plotX`/`plotY`.
  ///
  /// Written down rather than recomputed on the way out, which is what makes
  /// the garden look the same on every launch: the plot is chosen once, against
  /// the garden as it stood at that moment, and never chosen again.
  ///
  /// Nullable, and the two columns are null together: a plant the garden has no
  /// plot for. Only reachable past two hundred plants — see
  /// `docs/adr/0006-the-garden-has-a-plot-for-every-plant-it-can-hold.md`.
  final int? plotX;
  final int? plotY;
  const PlantRow({
    required this.id,
    this.sessionId,
    required this.type,
    required this.species,
    required this.growthStage,
    required this.plantedAt,
    this.sessionDurationSeconds,
    this.milestoneSessions,
    this.plotX,
    this.plotY,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || sessionId != null) {
      map['session_id'] = Variable<String>(sessionId);
    }
    map['type'] = Variable<String>(type);
    map['species'] = Variable<String>(species);
    map['growth_stage'] = Variable<int>(growthStage);
    map['planted_at'] = Variable<DateTime>(plantedAt);
    if (!nullToAbsent || sessionDurationSeconds != null) {
      map['session_duration_seconds'] = Variable<int>(sessionDurationSeconds);
    }
    if (!nullToAbsent || milestoneSessions != null) {
      map['milestone_sessions'] = Variable<int>(milestoneSessions);
    }
    if (!nullToAbsent || plotX != null) {
      map['plot_x'] = Variable<int>(plotX);
    }
    if (!nullToAbsent || plotY != null) {
      map['plot_y'] = Variable<int>(plotY);
    }
    return map;
  }

  PlantsCompanion toCompanion(bool nullToAbsent) {
    return PlantsCompanion(
      id: Value(id),
      sessionId: sessionId == null && nullToAbsent
          ? const Value.absent()
          : Value(sessionId),
      type: Value(type),
      species: Value(species),
      growthStage: Value(growthStage),
      plantedAt: Value(plantedAt),
      sessionDurationSeconds: sessionDurationSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(sessionDurationSeconds),
      milestoneSessions: milestoneSessions == null && nullToAbsent
          ? const Value.absent()
          : Value(milestoneSessions),
      plotX: plotX == null && nullToAbsent
          ? const Value.absent()
          : Value(plotX),
      plotY: plotY == null && nullToAbsent
          ? const Value.absent()
          : Value(plotY),
    );
  }

  factory PlantRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlantRow(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String?>(json['sessionId']),
      type: serializer.fromJson<String>(json['type']),
      species: serializer.fromJson<String>(json['species']),
      growthStage: serializer.fromJson<int>(json['growthStage']),
      plantedAt: serializer.fromJson<DateTime>(json['plantedAt']),
      sessionDurationSeconds: serializer.fromJson<int?>(
        json['sessionDurationSeconds'],
      ),
      milestoneSessions: serializer.fromJson<int?>(json['milestoneSessions']),
      plotX: serializer.fromJson<int?>(json['plotX']),
      plotY: serializer.fromJson<int?>(json['plotY']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String?>(sessionId),
      'type': serializer.toJson<String>(type),
      'species': serializer.toJson<String>(species),
      'growthStage': serializer.toJson<int>(growthStage),
      'plantedAt': serializer.toJson<DateTime>(plantedAt),
      'sessionDurationSeconds': serializer.toJson<int?>(sessionDurationSeconds),
      'milestoneSessions': serializer.toJson<int?>(milestoneSessions),
      'plotX': serializer.toJson<int?>(plotX),
      'plotY': serializer.toJson<int?>(plotY),
    };
  }

  PlantRow copyWith({
    String? id,
    Value<String?> sessionId = const Value.absent(),
    String? type,
    String? species,
    int? growthStage,
    DateTime? plantedAt,
    Value<int?> sessionDurationSeconds = const Value.absent(),
    Value<int?> milestoneSessions = const Value.absent(),
    Value<int?> plotX = const Value.absent(),
    Value<int?> plotY = const Value.absent(),
  }) => PlantRow(
    id: id ?? this.id,
    sessionId: sessionId.present ? sessionId.value : this.sessionId,
    type: type ?? this.type,
    species: species ?? this.species,
    growthStage: growthStage ?? this.growthStage,
    plantedAt: plantedAt ?? this.plantedAt,
    sessionDurationSeconds: sessionDurationSeconds.present
        ? sessionDurationSeconds.value
        : this.sessionDurationSeconds,
    milestoneSessions: milestoneSessions.present
        ? milestoneSessions.value
        : this.milestoneSessions,
    plotX: plotX.present ? plotX.value : this.plotX,
    plotY: plotY.present ? plotY.value : this.plotY,
  );
  PlantRow copyWithCompanion(PlantsCompanion data) {
    return PlantRow(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      type: data.type.present ? data.type.value : this.type,
      species: data.species.present ? data.species.value : this.species,
      growthStage: data.growthStage.present
          ? data.growthStage.value
          : this.growthStage,
      plantedAt: data.plantedAt.present ? data.plantedAt.value : this.plantedAt,
      sessionDurationSeconds: data.sessionDurationSeconds.present
          ? data.sessionDurationSeconds.value
          : this.sessionDurationSeconds,
      milestoneSessions: data.milestoneSessions.present
          ? data.milestoneSessions.value
          : this.milestoneSessions,
      plotX: data.plotX.present ? data.plotX.value : this.plotX,
      plotY: data.plotY.present ? data.plotY.value : this.plotY,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlantRow(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('type: $type, ')
          ..write('species: $species, ')
          ..write('growthStage: $growthStage, ')
          ..write('plantedAt: $plantedAt, ')
          ..write('sessionDurationSeconds: $sessionDurationSeconds, ')
          ..write('milestoneSessions: $milestoneSessions, ')
          ..write('plotX: $plotX, ')
          ..write('plotY: $plotY')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    type,
    species,
    growthStage,
    plantedAt,
    sessionDurationSeconds,
    milestoneSessions,
    plotX,
    plotY,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlantRow &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.type == this.type &&
          other.species == this.species &&
          other.growthStage == this.growthStage &&
          other.plantedAt == this.plantedAt &&
          other.sessionDurationSeconds == this.sessionDurationSeconds &&
          other.milestoneSessions == this.milestoneSessions &&
          other.plotX == this.plotX &&
          other.plotY == this.plotY);
}

class PlantsCompanion extends UpdateCompanion<PlantRow> {
  final Value<String> id;
  final Value<String?> sessionId;
  final Value<String> type;
  final Value<String> species;
  final Value<int> growthStage;
  final Value<DateTime> plantedAt;
  final Value<int?> sessionDurationSeconds;
  final Value<int?> milestoneSessions;
  final Value<int?> plotX;
  final Value<int?> plotY;
  final Value<int> rowid;
  const PlantsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.type = const Value.absent(),
    this.species = const Value.absent(),
    this.growthStage = const Value.absent(),
    this.plantedAt = const Value.absent(),
    this.sessionDurationSeconds = const Value.absent(),
    this.milestoneSessions = const Value.absent(),
    this.plotX = const Value.absent(),
    this.plotY = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlantsCompanion.insert({
    required String id,
    this.sessionId = const Value.absent(),
    required String type,
    required String species,
    required int growthStage,
    required DateTime plantedAt,
    this.sessionDurationSeconds = const Value.absent(),
    this.milestoneSessions = const Value.absent(),
    this.plotX = const Value.absent(),
    this.plotY = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       type = Value(type),
       species = Value(species),
       growthStage = Value(growthStage),
       plantedAt = Value(plantedAt);
  static Insertable<PlantRow> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<String>? type,
    Expression<String>? species,
    Expression<int>? growthStage,
    Expression<DateTime>? plantedAt,
    Expression<int>? sessionDurationSeconds,
    Expression<int>? milestoneSessions,
    Expression<int>? plotX,
    Expression<int>? plotY,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (type != null) 'type': type,
      if (species != null) 'species': species,
      if (growthStage != null) 'growth_stage': growthStage,
      if (plantedAt != null) 'planted_at': plantedAt,
      if (sessionDurationSeconds != null)
        'session_duration_seconds': sessionDurationSeconds,
      if (milestoneSessions != null) 'milestone_sessions': milestoneSessions,
      if (plotX != null) 'plot_x': plotX,
      if (plotY != null) 'plot_y': plotY,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlantsCompanion copyWith({
    Value<String>? id,
    Value<String?>? sessionId,
    Value<String>? type,
    Value<String>? species,
    Value<int>? growthStage,
    Value<DateTime>? plantedAt,
    Value<int?>? sessionDurationSeconds,
    Value<int?>? milestoneSessions,
    Value<int?>? plotX,
    Value<int?>? plotY,
    Value<int>? rowid,
  }) {
    return PlantsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      type: type ?? this.type,
      species: species ?? this.species,
      growthStage: growthStage ?? this.growthStage,
      plantedAt: plantedAt ?? this.plantedAt,
      sessionDurationSeconds:
          sessionDurationSeconds ?? this.sessionDurationSeconds,
      milestoneSessions: milestoneSessions ?? this.milestoneSessions,
      plotX: plotX ?? this.plotX,
      plotY: plotY ?? this.plotY,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (species.present) {
      map['species'] = Variable<String>(species.value);
    }
    if (growthStage.present) {
      map['growth_stage'] = Variable<int>(growthStage.value);
    }
    if (plantedAt.present) {
      map['planted_at'] = Variable<DateTime>(plantedAt.value);
    }
    if (sessionDurationSeconds.present) {
      map['session_duration_seconds'] = Variable<int>(
        sessionDurationSeconds.value,
      );
    }
    if (milestoneSessions.present) {
      map['milestone_sessions'] = Variable<int>(milestoneSessions.value);
    }
    if (plotX.present) {
      map['plot_x'] = Variable<int>(plotX.value);
    }
    if (plotY.present) {
      map['plot_y'] = Variable<int>(plotY.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlantsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('type: $type, ')
          ..write('species: $species, ')
          ..write('growthStage: $growthStage, ')
          ..write('plantedAt: $plantedAt, ')
          ..write('sessionDurationSeconds: $sessionDurationSeconds, ')
          ..write('milestoneSessions: $milestoneSessions, ')
          ..write('plotX: $plotX, ')
          ..write('plotY: $plotY, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AnalyticsEventsTable extends AnalyticsEvents
    with TableInfo<$AnalyticsEventsTable, AnalyticsEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AnalyticsEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parametersMeta = const VerificationMeta(
    'parameters',
  );
  @override
  late final GeneratedColumn<String> parameters = GeneratedColumn<String>(
    'parameters',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordedAtMeta = const VerificationMeta(
    'recordedAt',
  );
  @override
  late final GeneratedColumn<DateTime> recordedAt = GeneratedColumn<DateTime>(
    'recorded_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, parameters, recordedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'analytics_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<AnalyticsEventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('parameters')) {
      context.handle(
        _parametersMeta,
        parameters.isAcceptableOrUnknown(data['parameters']!, _parametersMeta),
      );
    } else if (isInserting) {
      context.missing(_parametersMeta);
    }
    if (data.containsKey('recorded_at')) {
      context.handle(
        _recordedAtMeta,
        recordedAt.isAcceptableOrUnknown(data['recorded_at']!, _recordedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_recordedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AnalyticsEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AnalyticsEventRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      parameters: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parameters'],
      )!,
      recordedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}recorded_at'],
      )!,
    );
  }

  @override
  $AnalyticsEventsTable createAlias(String alias) {
    return $AnalyticsEventsTable(attachedDatabase, alias);
  }
}

class AnalyticsEventRow extends DataClass
    implements Insertable<AnalyticsEventRow> {
  /// Insertion order, and the log's idea of "recent".
  ///
  /// Not the timestamp: a device clock corrected backwards would otherwise
  /// shuffle the log, and the row that was written last is the row that
  /// happened last whatever the clock says about it.
  final int id;

  /// [AnalyticsEventName.recorded] — §7.1's name for this event.
  ///
  /// Text rather than an ordinal, for the reason [Plants.type] is: the rows stay
  /// readable, and stay correct if the enum is ever reordered.
  final String name;

  /// The event's parameters, as a JSON object.
  final String parameters;

  /// When it happened, stored as UTC like every other instant in the schema.
  final DateTime recordedAt;
  const AnalyticsEventRow({
    required this.id,
    required this.name,
    required this.parameters,
    required this.recordedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['parameters'] = Variable<String>(parameters);
    map['recorded_at'] = Variable<DateTime>(recordedAt);
    return map;
  }

  AnalyticsEventsCompanion toCompanion(bool nullToAbsent) {
    return AnalyticsEventsCompanion(
      id: Value(id),
      name: Value(name),
      parameters: Value(parameters),
      recordedAt: Value(recordedAt),
    );
  }

  factory AnalyticsEventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AnalyticsEventRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      parameters: serializer.fromJson<String>(json['parameters']),
      recordedAt: serializer.fromJson<DateTime>(json['recordedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'parameters': serializer.toJson<String>(parameters),
      'recordedAt': serializer.toJson<DateTime>(recordedAt),
    };
  }

  AnalyticsEventRow copyWith({
    int? id,
    String? name,
    String? parameters,
    DateTime? recordedAt,
  }) => AnalyticsEventRow(
    id: id ?? this.id,
    name: name ?? this.name,
    parameters: parameters ?? this.parameters,
    recordedAt: recordedAt ?? this.recordedAt,
  );
  AnalyticsEventRow copyWithCompanion(AnalyticsEventsCompanion data) {
    return AnalyticsEventRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      parameters: data.parameters.present
          ? data.parameters.value
          : this.parameters,
      recordedAt: data.recordedAt.present
          ? data.recordedAt.value
          : this.recordedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AnalyticsEventRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('parameters: $parameters, ')
          ..write('recordedAt: $recordedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, parameters, recordedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AnalyticsEventRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.parameters == this.parameters &&
          other.recordedAt == this.recordedAt);
}

class AnalyticsEventsCompanion extends UpdateCompanion<AnalyticsEventRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> parameters;
  final Value<DateTime> recordedAt;
  const AnalyticsEventsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.parameters = const Value.absent(),
    this.recordedAt = const Value.absent(),
  });
  AnalyticsEventsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String parameters,
    required DateTime recordedAt,
  }) : name = Value(name),
       parameters = Value(parameters),
       recordedAt = Value(recordedAt);
  static Insertable<AnalyticsEventRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? parameters,
    Expression<DateTime>? recordedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (parameters != null) 'parameters': parameters,
      if (recordedAt != null) 'recorded_at': recordedAt,
    });
  }

  AnalyticsEventsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? parameters,
    Value<DateTime>? recordedAt,
  }) {
    return AnalyticsEventsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      parameters: parameters ?? this.parameters,
      recordedAt: recordedAt ?? this.recordedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (parameters.present) {
      map['parameters'] = Variable<String>(parameters.value);
    }
    if (recordedAt.present) {
      map['recorded_at'] = Variable<DateTime>(recordedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AnalyticsEventsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('parameters: $parameters, ')
          ..write('recordedAt: $recordedAt')
          ..write(')'))
        .toString();
  }
}

class $GardenDecorTable extends GardenDecor
    with TableInfo<$GardenDecorTable, DecorRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GardenDecorTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _plotXMeta = const VerificationMeta('plotX');
  @override
  late final GeneratedColumn<int> plotX = GeneratedColumn<int>(
    'plot_x',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _plotYMeta = const VerificationMeta('plotY');
  @override
  late final GeneratedColumn<int> plotY = GeneratedColumn<int>(
    'plot_y',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _placedAtMeta = const VerificationMeta(
    'placedAt',
  );
  @override
  late final GeneratedColumn<DateTime> placedAt = GeneratedColumn<DateTime>(
    'placed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, kind, plotX, plotY, placedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'decor';
  @override
  VerificationContext validateIntegrity(
    Insertable<DecorRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('plot_x')) {
      context.handle(
        _plotXMeta,
        plotX.isAcceptableOrUnknown(data['plot_x']!, _plotXMeta),
      );
    } else if (isInserting) {
      context.missing(_plotXMeta);
    }
    if (data.containsKey('plot_y')) {
      context.handle(
        _plotYMeta,
        plotY.isAcceptableOrUnknown(data['plot_y']!, _plotYMeta),
      );
    } else if (isInserting) {
      context.missing(_plotYMeta);
    }
    if (data.containsKey('placed_at')) {
      context.handle(
        _placedAtMeta,
        placedAt.isAcceptableOrUnknown(data['placed_at']!, _placedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_placedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {plotX, plotY},
  ];
  @override
  DecorRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DecorRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      plotX: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}plot_x'],
      )!,
      plotY: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}plot_y'],
      )!,
      placedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}placed_at'],
      )!,
    );
  }

  @override
  $GardenDecorTable createAlias(String alias) {
    return $GardenDecorTable(attachedDatabase, alias);
  }
}

class DecorRow extends DataClass implements Insertable<DecorRow> {
  final String id;

  /// [DecorKind.name]. Text rather than an ordinal, for the reason
  /// [Plants.type] is: the rows stay readable, and stay correct if the enum is
  /// ever reordered — and ticket 23 may well add to it.
  final String kind;

  /// Where in the isometric grid this item stands.
  ///
  /// **Not nullable, unlike [Plants.plotX].** A plant with no plot is a plant
  /// the garden is holding for the user (ADR 0006); an item with no plot is
  /// nothing at all. See `docs/adr/0017-…`.
  final int plotX;
  final int plotY;

  /// When the user put it down, in UTC. The order an arrangement is read back
  /// in, so that two reads of one garden hand back one arrangement.
  final DateTime placedAt;
  const DecorRow({
    required this.id,
    required this.kind,
    required this.plotX,
    required this.plotY,
    required this.placedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    map['plot_x'] = Variable<int>(plotX);
    map['plot_y'] = Variable<int>(plotY);
    map['placed_at'] = Variable<DateTime>(placedAt);
    return map;
  }

  GardenDecorCompanion toCompanion(bool nullToAbsent) {
    return GardenDecorCompanion(
      id: Value(id),
      kind: Value(kind),
      plotX: Value(plotX),
      plotY: Value(plotY),
      placedAt: Value(placedAt),
    );
  }

  factory DecorRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DecorRow(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      plotX: serializer.fromJson<int>(json['plotX']),
      plotY: serializer.fromJson<int>(json['plotY']),
      placedAt: serializer.fromJson<DateTime>(json['placedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'plotX': serializer.toJson<int>(plotX),
      'plotY': serializer.toJson<int>(plotY),
      'placedAt': serializer.toJson<DateTime>(placedAt),
    };
  }

  DecorRow copyWith({
    String? id,
    String? kind,
    int? plotX,
    int? plotY,
    DateTime? placedAt,
  }) => DecorRow(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    plotX: plotX ?? this.plotX,
    plotY: plotY ?? this.plotY,
    placedAt: placedAt ?? this.placedAt,
  );
  DecorRow copyWithCompanion(GardenDecorCompanion data) {
    return DecorRow(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      plotX: data.plotX.present ? data.plotX.value : this.plotX,
      plotY: data.plotY.present ? data.plotY.value : this.plotY,
      placedAt: data.placedAt.present ? data.placedAt.value : this.placedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DecorRow(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('plotX: $plotX, ')
          ..write('plotY: $plotY, ')
          ..write('placedAt: $placedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, kind, plotX, plotY, placedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DecorRow &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.plotX == this.plotX &&
          other.plotY == this.plotY &&
          other.placedAt == this.placedAt);
}

class GardenDecorCompanion extends UpdateCompanion<DecorRow> {
  final Value<String> id;
  final Value<String> kind;
  final Value<int> plotX;
  final Value<int> plotY;
  final Value<DateTime> placedAt;
  final Value<int> rowid;
  const GardenDecorCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.plotX = const Value.absent(),
    this.plotY = const Value.absent(),
    this.placedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GardenDecorCompanion.insert({
    required String id,
    required String kind,
    required int plotX,
    required int plotY,
    required DateTime placedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       plotX = Value(plotX),
       plotY = Value(plotY),
       placedAt = Value(placedAt);
  static Insertable<DecorRow> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<int>? plotX,
    Expression<int>? plotY,
    Expression<DateTime>? placedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (plotX != null) 'plot_x': plotX,
      if (plotY != null) 'plot_y': plotY,
      if (placedAt != null) 'placed_at': placedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GardenDecorCompanion copyWith({
    Value<String>? id,
    Value<String>? kind,
    Value<int>? plotX,
    Value<int>? plotY,
    Value<DateTime>? placedAt,
    Value<int>? rowid,
  }) {
    return GardenDecorCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      plotX: plotX ?? this.plotX,
      plotY: plotY ?? this.plotY,
      placedAt: placedAt ?? this.placedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (plotX.present) {
      map['plot_x'] = Variable<int>(plotX.value);
    }
    if (plotY.present) {
      map['plot_y'] = Variable<int>(plotY.value);
    }
    if (placedAt.present) {
      map['placed_at'] = Variable<DateTime>(placedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GardenDecorCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('plotX: $plotX, ')
          ..write('plotY: $plotY, ')
          ..write('placedAt: $placedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SessionsTable sessions = $SessionsTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final $PlantsTable plants = $PlantsTable(this);
  late final $AnalyticsEventsTable analyticsEvents = $AnalyticsEventsTable(
    this,
  );
  late final $GardenDecorTable gardenDecor = $GardenDecorTable(this);
  late final Index sessionsCompletedStartedAt = Index(
    'sessions_completed_started_at',
    'CREATE INDEX sessions_completed_started_at ON sessions (completed, started_at)',
  );
  late final Index plantsPlantedAt = Index(
    'plants_planted_at',
    'CREATE INDEX plants_planted_at ON plants (planted_at)',
  );
  late final Index analyticsEventsName = Index(
    'analytics_events_name',
    'CREATE INDEX analytics_events_name ON analytics_events (name)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    sessions,
    settings,
    plants,
    analyticsEvents,
    gardenDecor,
    sessionsCompletedStartedAt,
    plantsPlantedAt,
    analyticsEventsName,
  ];
}

typedef $$SessionsTableCreateCompanionBuilder =
    SessionsCompanion Function({
      required String id,
      required DateTime startedAt,
      required int durationSeconds,
      Value<bool> completed,
      Value<String?> outcome,
      Value<int> pausedSeconds,
      Value<DateTime?> pausedSince,
      Value<DateTime?> endedAt,
      Value<int> rowid,
    });
typedef $$SessionsTableUpdateCompanionBuilder =
    SessionsCompanion Function({
      Value<String> id,
      Value<DateTime> startedAt,
      Value<int> durationSeconds,
      Value<bool> completed,
      Value<String?> outcome,
      Value<int> pausedSeconds,
      Value<DateTime?> pausedSince,
      Value<DateTime?> endedAt,
      Value<int> rowid,
    });

class $$SessionsTableFilterComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get outcome => $composableBuilder(
    column: $table.outcome,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pausedSeconds => $composableBuilder(
    column: $table.pausedSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get pausedSince => $composableBuilder(
    column: $table.pausedSince,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get outcome => $composableBuilder(
    column: $table.outcome,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pausedSeconds => $composableBuilder(
    column: $table.pausedSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get pausedSince => $composableBuilder(
    column: $table.pausedSince,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get completed =>
      $composableBuilder(column: $table.completed, builder: (column) => column);

  GeneratedColumn<String> get outcome =>
      $composableBuilder(column: $table.outcome, builder: (column) => column);

  GeneratedColumn<int> get pausedSeconds => $composableBuilder(
    column: $table.pausedSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get pausedSince => $composableBuilder(
    column: $table.pausedSince,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);
}

class $$SessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SessionsTable,
          SessionRow,
          $$SessionsTableFilterComposer,
          $$SessionsTableOrderingComposer,
          $$SessionsTableAnnotationComposer,
          $$SessionsTableCreateCompanionBuilder,
          $$SessionsTableUpdateCompanionBuilder,
          (
            SessionRow,
            BaseReferences<_$AppDatabase, $SessionsTable, SessionRow>,
          ),
          SessionRow,
          PrefetchHooks Function()
        > {
  $$SessionsTableTableManager(_$AppDatabase db, $SessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<int> durationSeconds = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                Value<String?> outcome = const Value.absent(),
                Value<int> pausedSeconds = const Value.absent(),
                Value<DateTime?> pausedSince = const Value.absent(),
                Value<DateTime?> endedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionsCompanion(
                id: id,
                startedAt: startedAt,
                durationSeconds: durationSeconds,
                completed: completed,
                outcome: outcome,
                pausedSeconds: pausedSeconds,
                pausedSince: pausedSince,
                endedAt: endedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required DateTime startedAt,
                required int durationSeconds,
                Value<bool> completed = const Value.absent(),
                Value<String?> outcome = const Value.absent(),
                Value<int> pausedSeconds = const Value.absent(),
                Value<DateTime?> pausedSince = const Value.absent(),
                Value<DateTime?> endedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionsCompanion.insert(
                id: id,
                startedAt: startedAt,
                durationSeconds: durationSeconds,
                completed: completed,
                outcome: outcome,
                pausedSeconds: pausedSeconds,
                pausedSince: pausedSince,
                endedAt: endedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SessionsTable,
      SessionRow,
      $$SessionsTableFilterComposer,
      $$SessionsTableOrderingComposer,
      $$SessionsTableAnnotationComposer,
      $$SessionsTableCreateCompanionBuilder,
      $$SessionsTableUpdateCompanionBuilder,
      (SessionRow, BaseReferences<_$AppDatabase, $SessionsTable, SessionRow>),
      SessionRow,
      PrefetchHooks Function()
    >;
typedef $$SettingsTableCreateCompanionBuilder =
    SettingsCompanion Function({
      Value<int> id,
      required int sessionLengthSeconds,
      required int breakLengthSeconds,
      required int longBreakAfterSessions,
      Value<bool> hapticsEnabled,
      Value<bool> liveSurfaceEnabled,
      Value<bool> autoStartBreak,
      Value<bool> autoStartNextSession,
      Value<String> ambientSound,
      Value<String> endSound,
      Value<String> gardenTheme,
      Value<bool> quietModeEnabled,
      Value<bool> quietModeHintDismissed,
      Value<bool> onboardingCompleted,
    });
typedef $$SettingsTableUpdateCompanionBuilder =
    SettingsCompanion Function({
      Value<int> id,
      Value<int> sessionLengthSeconds,
      Value<int> breakLengthSeconds,
      Value<int> longBreakAfterSessions,
      Value<bool> hapticsEnabled,
      Value<bool> liveSurfaceEnabled,
      Value<bool> autoStartBreak,
      Value<bool> autoStartNextSession,
      Value<String> ambientSound,
      Value<String> endSound,
      Value<String> gardenTheme,
      Value<bool> quietModeEnabled,
      Value<bool> quietModeHintDismissed,
      Value<bool> onboardingCompleted,
    });

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sessionLengthSeconds => $composableBuilder(
    column: $table.sessionLengthSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get breakLengthSeconds => $composableBuilder(
    column: $table.breakLengthSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get longBreakAfterSessions => $composableBuilder(
    column: $table.longBreakAfterSessions,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hapticsEnabled => $composableBuilder(
    column: $table.hapticsEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get liveSurfaceEnabled => $composableBuilder(
    column: $table.liveSurfaceEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get autoStartBreak => $composableBuilder(
    column: $table.autoStartBreak,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get autoStartNextSession => $composableBuilder(
    column: $table.autoStartNextSession,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ambientSound => $composableBuilder(
    column: $table.ambientSound,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get endSound => $composableBuilder(
    column: $table.endSound,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gardenTheme => $composableBuilder(
    column: $table.gardenTheme,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get quietModeEnabled => $composableBuilder(
    column: $table.quietModeEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get quietModeHintDismissed => $composableBuilder(
    column: $table.quietModeHintDismissed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get onboardingCompleted => $composableBuilder(
    column: $table.onboardingCompleted,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sessionLengthSeconds => $composableBuilder(
    column: $table.sessionLengthSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get breakLengthSeconds => $composableBuilder(
    column: $table.breakLengthSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get longBreakAfterSessions => $composableBuilder(
    column: $table.longBreakAfterSessions,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hapticsEnabled => $composableBuilder(
    column: $table.hapticsEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get liveSurfaceEnabled => $composableBuilder(
    column: $table.liveSurfaceEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get autoStartBreak => $composableBuilder(
    column: $table.autoStartBreak,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get autoStartNextSession => $composableBuilder(
    column: $table.autoStartNextSession,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ambientSound => $composableBuilder(
    column: $table.ambientSound,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endSound => $composableBuilder(
    column: $table.endSound,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gardenTheme => $composableBuilder(
    column: $table.gardenTheme,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get quietModeEnabled => $composableBuilder(
    column: $table.quietModeEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get quietModeHintDismissed => $composableBuilder(
    column: $table.quietModeHintDismissed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get onboardingCompleted => $composableBuilder(
    column: $table.onboardingCompleted,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get sessionLengthSeconds => $composableBuilder(
    column: $table.sessionLengthSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get breakLengthSeconds => $composableBuilder(
    column: $table.breakLengthSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get longBreakAfterSessions => $composableBuilder(
    column: $table.longBreakAfterSessions,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get hapticsEnabled => $composableBuilder(
    column: $table.hapticsEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get liveSurfaceEnabled => $composableBuilder(
    column: $table.liveSurfaceEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get autoStartBreak => $composableBuilder(
    column: $table.autoStartBreak,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get autoStartNextSession => $composableBuilder(
    column: $table.autoStartNextSession,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ambientSound => $composableBuilder(
    column: $table.ambientSound,
    builder: (column) => column,
  );

  GeneratedColumn<String> get endSound =>
      $composableBuilder(column: $table.endSound, builder: (column) => column);

  GeneratedColumn<String> get gardenTheme => $composableBuilder(
    column: $table.gardenTheme,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get quietModeEnabled => $composableBuilder(
    column: $table.quietModeEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get quietModeHintDismissed => $composableBuilder(
    column: $table.quietModeHintDismissed,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get onboardingCompleted => $composableBuilder(
    column: $table.onboardingCompleted,
    builder: (column) => column,
  );
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          SettingsRow,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (
            SettingsRow,
            BaseReferences<_$AppDatabase, $SettingsTable, SettingsRow>,
          ),
          SettingsRow,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> sessionLengthSeconds = const Value.absent(),
                Value<int> breakLengthSeconds = const Value.absent(),
                Value<int> longBreakAfterSessions = const Value.absent(),
                Value<bool> hapticsEnabled = const Value.absent(),
                Value<bool> liveSurfaceEnabled = const Value.absent(),
                Value<bool> autoStartBreak = const Value.absent(),
                Value<bool> autoStartNextSession = const Value.absent(),
                Value<String> ambientSound = const Value.absent(),
                Value<String> endSound = const Value.absent(),
                Value<String> gardenTheme = const Value.absent(),
                Value<bool> quietModeEnabled = const Value.absent(),
                Value<bool> quietModeHintDismissed = const Value.absent(),
                Value<bool> onboardingCompleted = const Value.absent(),
              }) => SettingsCompanion(
                id: id,
                sessionLengthSeconds: sessionLengthSeconds,
                breakLengthSeconds: breakLengthSeconds,
                longBreakAfterSessions: longBreakAfterSessions,
                hapticsEnabled: hapticsEnabled,
                liveSurfaceEnabled: liveSurfaceEnabled,
                autoStartBreak: autoStartBreak,
                autoStartNextSession: autoStartNextSession,
                ambientSound: ambientSound,
                endSound: endSound,
                gardenTheme: gardenTheme,
                quietModeEnabled: quietModeEnabled,
                quietModeHintDismissed: quietModeHintDismissed,
                onboardingCompleted: onboardingCompleted,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int sessionLengthSeconds,
                required int breakLengthSeconds,
                required int longBreakAfterSessions,
                Value<bool> hapticsEnabled = const Value.absent(),
                Value<bool> liveSurfaceEnabled = const Value.absent(),
                Value<bool> autoStartBreak = const Value.absent(),
                Value<bool> autoStartNextSession = const Value.absent(),
                Value<String> ambientSound = const Value.absent(),
                Value<String> endSound = const Value.absent(),
                Value<String> gardenTheme = const Value.absent(),
                Value<bool> quietModeEnabled = const Value.absent(),
                Value<bool> quietModeHintDismissed = const Value.absent(),
                Value<bool> onboardingCompleted = const Value.absent(),
              }) => SettingsCompanion.insert(
                id: id,
                sessionLengthSeconds: sessionLengthSeconds,
                breakLengthSeconds: breakLengthSeconds,
                longBreakAfterSessions: longBreakAfterSessions,
                hapticsEnabled: hapticsEnabled,
                liveSurfaceEnabled: liveSurfaceEnabled,
                autoStartBreak: autoStartBreak,
                autoStartNextSession: autoStartNextSession,
                ambientSound: ambientSound,
                endSound: endSound,
                gardenTheme: gardenTheme,
                quietModeEnabled: quietModeEnabled,
                quietModeHintDismissed: quietModeHintDismissed,
                onboardingCompleted: onboardingCompleted,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      SettingsRow,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (SettingsRow, BaseReferences<_$AppDatabase, $SettingsTable, SettingsRow>),
      SettingsRow,
      PrefetchHooks Function()
    >;
typedef $$PlantsTableCreateCompanionBuilder =
    PlantsCompanion Function({
      required String id,
      Value<String?> sessionId,
      required String type,
      required String species,
      required int growthStage,
      required DateTime plantedAt,
      Value<int?> sessionDurationSeconds,
      Value<int?> milestoneSessions,
      Value<int?> plotX,
      Value<int?> plotY,
      Value<int> rowid,
    });
typedef $$PlantsTableUpdateCompanionBuilder =
    PlantsCompanion Function({
      Value<String> id,
      Value<String?> sessionId,
      Value<String> type,
      Value<String> species,
      Value<int> growthStage,
      Value<DateTime> plantedAt,
      Value<int?> sessionDurationSeconds,
      Value<int?> milestoneSessions,
      Value<int?> plotX,
      Value<int?> plotY,
      Value<int> rowid,
    });

class $$PlantsTableFilterComposer
    extends Composer<_$AppDatabase, $PlantsTable> {
  $$PlantsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get species => $composableBuilder(
    column: $table.species,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get growthStage => $composableBuilder(
    column: $table.growthStage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get plantedAt => $composableBuilder(
    column: $table.plantedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sessionDurationSeconds => $composableBuilder(
    column: $table.sessionDurationSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get milestoneSessions => $composableBuilder(
    column: $table.milestoneSessions,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get plotX => $composableBuilder(
    column: $table.plotX,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get plotY => $composableBuilder(
    column: $table.plotY,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PlantsTableOrderingComposer
    extends Composer<_$AppDatabase, $PlantsTable> {
  $$PlantsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get species => $composableBuilder(
    column: $table.species,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get growthStage => $composableBuilder(
    column: $table.growthStage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get plantedAt => $composableBuilder(
    column: $table.plantedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sessionDurationSeconds => $composableBuilder(
    column: $table.sessionDurationSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get milestoneSessions => $composableBuilder(
    column: $table.milestoneSessions,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get plotX => $composableBuilder(
    column: $table.plotX,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get plotY => $composableBuilder(
    column: $table.plotY,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlantsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlantsTable> {
  $$PlantsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get species =>
      $composableBuilder(column: $table.species, builder: (column) => column);

  GeneratedColumn<int> get growthStage => $composableBuilder(
    column: $table.growthStage,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get plantedAt =>
      $composableBuilder(column: $table.plantedAt, builder: (column) => column);

  GeneratedColumn<int> get sessionDurationSeconds => $composableBuilder(
    column: $table.sessionDurationSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get milestoneSessions => $composableBuilder(
    column: $table.milestoneSessions,
    builder: (column) => column,
  );

  GeneratedColumn<int> get plotX =>
      $composableBuilder(column: $table.plotX, builder: (column) => column);

  GeneratedColumn<int> get plotY =>
      $composableBuilder(column: $table.plotY, builder: (column) => column);
}

class $$PlantsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlantsTable,
          PlantRow,
          $$PlantsTableFilterComposer,
          $$PlantsTableOrderingComposer,
          $$PlantsTableAnnotationComposer,
          $$PlantsTableCreateCompanionBuilder,
          $$PlantsTableUpdateCompanionBuilder,
          (PlantRow, BaseReferences<_$AppDatabase, $PlantsTable, PlantRow>),
          PlantRow,
          PrefetchHooks Function()
        > {
  $$PlantsTableTableManager(_$AppDatabase db, $PlantsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlantsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlantsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlantsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> sessionId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> species = const Value.absent(),
                Value<int> growthStage = const Value.absent(),
                Value<DateTime> plantedAt = const Value.absent(),
                Value<int?> sessionDurationSeconds = const Value.absent(),
                Value<int?> milestoneSessions = const Value.absent(),
                Value<int?> plotX = const Value.absent(),
                Value<int?> plotY = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlantsCompanion(
                id: id,
                sessionId: sessionId,
                type: type,
                species: species,
                growthStage: growthStage,
                plantedAt: plantedAt,
                sessionDurationSeconds: sessionDurationSeconds,
                milestoneSessions: milestoneSessions,
                plotX: plotX,
                plotY: plotY,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> sessionId = const Value.absent(),
                required String type,
                required String species,
                required int growthStage,
                required DateTime plantedAt,
                Value<int?> sessionDurationSeconds = const Value.absent(),
                Value<int?> milestoneSessions = const Value.absent(),
                Value<int?> plotX = const Value.absent(),
                Value<int?> plotY = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlantsCompanion.insert(
                id: id,
                sessionId: sessionId,
                type: type,
                species: species,
                growthStage: growthStage,
                plantedAt: plantedAt,
                sessionDurationSeconds: sessionDurationSeconds,
                milestoneSessions: milestoneSessions,
                plotX: plotX,
                plotY: plotY,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PlantsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlantsTable,
      PlantRow,
      $$PlantsTableFilterComposer,
      $$PlantsTableOrderingComposer,
      $$PlantsTableAnnotationComposer,
      $$PlantsTableCreateCompanionBuilder,
      $$PlantsTableUpdateCompanionBuilder,
      (PlantRow, BaseReferences<_$AppDatabase, $PlantsTable, PlantRow>),
      PlantRow,
      PrefetchHooks Function()
    >;
typedef $$AnalyticsEventsTableCreateCompanionBuilder =
    AnalyticsEventsCompanion Function({
      Value<int> id,
      required String name,
      required String parameters,
      required DateTime recordedAt,
    });
typedef $$AnalyticsEventsTableUpdateCompanionBuilder =
    AnalyticsEventsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> parameters,
      Value<DateTime> recordedAt,
    });

class $$AnalyticsEventsTableFilterComposer
    extends Composer<_$AppDatabase, $AnalyticsEventsTable> {
  $$AnalyticsEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parameters => $composableBuilder(
    column: $table.parameters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AnalyticsEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $AnalyticsEventsTable> {
  $$AnalyticsEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parameters => $composableBuilder(
    column: $table.parameters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AnalyticsEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AnalyticsEventsTable> {
  $$AnalyticsEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get parameters => $composableBuilder(
    column: $table.parameters,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => column,
  );
}

class $$AnalyticsEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AnalyticsEventsTable,
          AnalyticsEventRow,
          $$AnalyticsEventsTableFilterComposer,
          $$AnalyticsEventsTableOrderingComposer,
          $$AnalyticsEventsTableAnnotationComposer,
          $$AnalyticsEventsTableCreateCompanionBuilder,
          $$AnalyticsEventsTableUpdateCompanionBuilder,
          (
            AnalyticsEventRow,
            BaseReferences<
              _$AppDatabase,
              $AnalyticsEventsTable,
              AnalyticsEventRow
            >,
          ),
          AnalyticsEventRow,
          PrefetchHooks Function()
        > {
  $$AnalyticsEventsTableTableManager(
    _$AppDatabase db,
    $AnalyticsEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AnalyticsEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AnalyticsEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AnalyticsEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> parameters = const Value.absent(),
                Value<DateTime> recordedAt = const Value.absent(),
              }) => AnalyticsEventsCompanion(
                id: id,
                name: name,
                parameters: parameters,
                recordedAt: recordedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String parameters,
                required DateTime recordedAt,
              }) => AnalyticsEventsCompanion.insert(
                id: id,
                name: name,
                parameters: parameters,
                recordedAt: recordedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AnalyticsEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AnalyticsEventsTable,
      AnalyticsEventRow,
      $$AnalyticsEventsTableFilterComposer,
      $$AnalyticsEventsTableOrderingComposer,
      $$AnalyticsEventsTableAnnotationComposer,
      $$AnalyticsEventsTableCreateCompanionBuilder,
      $$AnalyticsEventsTableUpdateCompanionBuilder,
      (
        AnalyticsEventRow,
        BaseReferences<_$AppDatabase, $AnalyticsEventsTable, AnalyticsEventRow>,
      ),
      AnalyticsEventRow,
      PrefetchHooks Function()
    >;
typedef $$GardenDecorTableCreateCompanionBuilder =
    GardenDecorCompanion Function({
      required String id,
      required String kind,
      required int plotX,
      required int plotY,
      required DateTime placedAt,
      Value<int> rowid,
    });
typedef $$GardenDecorTableUpdateCompanionBuilder =
    GardenDecorCompanion Function({
      Value<String> id,
      Value<String> kind,
      Value<int> plotX,
      Value<int> plotY,
      Value<DateTime> placedAt,
      Value<int> rowid,
    });

class $$GardenDecorTableFilterComposer
    extends Composer<_$AppDatabase, $GardenDecorTable> {
  $$GardenDecorTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get plotX => $composableBuilder(
    column: $table.plotX,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get plotY => $composableBuilder(
    column: $table.plotY,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get placedAt => $composableBuilder(
    column: $table.placedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GardenDecorTableOrderingComposer
    extends Composer<_$AppDatabase, $GardenDecorTable> {
  $$GardenDecorTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get plotX => $composableBuilder(
    column: $table.plotX,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get plotY => $composableBuilder(
    column: $table.plotY,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get placedAt => $composableBuilder(
    column: $table.placedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GardenDecorTableAnnotationComposer
    extends Composer<_$AppDatabase, $GardenDecorTable> {
  $$GardenDecorTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get plotX =>
      $composableBuilder(column: $table.plotX, builder: (column) => column);

  GeneratedColumn<int> get plotY =>
      $composableBuilder(column: $table.plotY, builder: (column) => column);

  GeneratedColumn<DateTime> get placedAt =>
      $composableBuilder(column: $table.placedAt, builder: (column) => column);
}

class $$GardenDecorTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GardenDecorTable,
          DecorRow,
          $$GardenDecorTableFilterComposer,
          $$GardenDecorTableOrderingComposer,
          $$GardenDecorTableAnnotationComposer,
          $$GardenDecorTableCreateCompanionBuilder,
          $$GardenDecorTableUpdateCompanionBuilder,
          (
            DecorRow,
            BaseReferences<_$AppDatabase, $GardenDecorTable, DecorRow>,
          ),
          DecorRow,
          PrefetchHooks Function()
        > {
  $$GardenDecorTableTableManager(_$AppDatabase db, $GardenDecorTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GardenDecorTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GardenDecorTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GardenDecorTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int> plotX = const Value.absent(),
                Value<int> plotY = const Value.absent(),
                Value<DateTime> placedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GardenDecorCompanion(
                id: id,
                kind: kind,
                plotX: plotX,
                plotY: plotY,
                placedAt: placedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String kind,
                required int plotX,
                required int plotY,
                required DateTime placedAt,
                Value<int> rowid = const Value.absent(),
              }) => GardenDecorCompanion.insert(
                id: id,
                kind: kind,
                plotX: plotX,
                plotY: plotY,
                placedAt: placedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GardenDecorTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GardenDecorTable,
      DecorRow,
      $$GardenDecorTableFilterComposer,
      $$GardenDecorTableOrderingComposer,
      $$GardenDecorTableAnnotationComposer,
      $$GardenDecorTableCreateCompanionBuilder,
      $$GardenDecorTableUpdateCompanionBuilder,
      (DecorRow, BaseReferences<_$AppDatabase, $GardenDecorTable, DecorRow>),
      DecorRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SessionsTableTableManager get sessions =>
      $$SessionsTableTableManager(_db, _db.sessions);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$PlantsTableTableManager get plants =>
      $$PlantsTableTableManager(_db, _db.plants);
  $$AnalyticsEventsTableTableManager get analyticsEvents =>
      $$AnalyticsEventsTableTableManager(_db, _db.analyticsEvents);
  $$GardenDecorTableTableManager get gardenDecor =>
      $$GardenDecorTableTableManager(_db, _db.gardenDecor);
}
