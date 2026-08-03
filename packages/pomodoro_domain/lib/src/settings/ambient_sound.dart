/// Background sound played during a focus session. All six are free (ADR
/// 0021). [silence] is a real choice, not "off".
enum AmbientSound {
  /// Default. Don't start making noise until the user picks something.
  silence('Silence'),

  rain('Rain'),

  forest('Forest'),

  ocean('Ocean'),

  cafe('Café'),

  whiteNoise('White noise');

  const AmbientSound(this.label);

  final String label;

  /// Falls back to [silence] for names from a build that had other sounds.
  static AmbientSound named(String name) => values.firstWhere(
        (sound) => sound.name == name,
        orElse: () => silence,
      );
}
