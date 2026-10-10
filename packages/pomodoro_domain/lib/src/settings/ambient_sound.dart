/// REQ-012's six beds: what the user can have playing under a focus session.
///
/// An enum rather than a string, and it lives in the domain rather than beside
/// the player, because what hangs off it is not about audio — which one the
/// *next* session starts with. That is a rule, and a rule about a bed is not
/// the business of the thing that decodes a file.
///
/// **All six are everybody's.** An earlier draft of this app sold three of
/// them; the app is free and there is nothing here to own — see
/// `docs/adr/0021-…`.
///
/// [silence] is one of the six rather than the absence of the other five. That
/// is the ticket's wording and it is also the honest model: a user who wants no
/// bed has chosen something, the choice is stored and defaulted like any other,
/// and the picker has six chips rather than five and an off switch.
enum AmbientSound {
  /// The default, and the only one a first run can be on. An app that started
  /// making rain at the first tap of START would be an app that decided
  /// something about the user's room.
  silence('Silence'),

  rain('Rain'),

  forest('Forest'),

  ocean('Ocean'),

  cafe('Café'),

  whiteNoise('White noise');

  const AmbientSound(this.label);

  /// What the picker calls this bed.
  final String label;

  /// The bed called [name], or [silence] if this build has never heard of it.
  ///
  /// Falls back rather than throwing, on the same reasoning the settings
  /// clamp their lengths: the name arrives from a stored row, and a row written
  /// by a build that offered a bed this one does not is a row to read as best
  /// it can be read. Silence is the answer that cannot be wrong — it is what a
  /// user who has chosen nothing gets, and it plays nothing over anybody.
  static AmbientSound named(String name) => values.firstWhere(
        (sound) => sound.name == name,
        orElse: () => silence,
      );
}
