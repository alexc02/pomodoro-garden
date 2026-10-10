# One audio session, with two uses

The app has **one** audio session, because the platform has one, and it is configured by
**one** class. The two things that play — the end-of-session chime and the ambient bed —
ask that class for a *use*, and never set a category themselves.

The rule the two uses divide on is a sentence:

> **The silent switch wins, unless the user has asked for a bed.**

## The problem

Ticket 06 configured the audio session from `BundledEndSound`, at the moment of the first
chime, and that was right while the chime was the only thing that played. It set
`AVAudioSessionCategory.ambient` with `mixWithOthers`, which is a decision worth keeping:
`ambient` is the iOS category the ring switch mutes, and a focus app that chimed in a
meeting because the user had silenced their phone would have earned every word of the
review.

Ticket 10 adds a second player whose needs are the opposite of that in every particular:

| | Chime | Bed |
|---|---|---|
| iOS category | `ambient` — mutes with the ring switch | `playback` — ignores it |
| Behind a locked screen | stops, and should | plays, and must (REQ-012) |
| Other apps' audio | mixes with it | takes it |
| Android focus | transient, may duck | full gain, for the session |

`AVAudioSession` is one object per process, and an Android audio focus request is one per
app. So these are not two configurations that coexist; they are one configuration, and
whichever feature called `configure` last decides it. Left alone, the first chime of the
app's life would drop a running bed onto `ambient` — silencing rain on a locked screen,
on a device, weeks after anyone last looked at either file.

## The decision

`AppAudioSession` owns the configuration and exposes the two uses as an enum. Neither
player names a category.

The two verbs are deliberately asymmetric, and the asymmetry *is* the decision:

- **The bed calls `useFor`.** It takes the session when it starts and hands it back when
  it stops. While a bed plays, the whole app is on `playback`.
- **The chime calls `ensureConfigured`.** It needs the session to have been configured for
  *something*; it has no opinion about which. A chime that called `useFor` would be the
  bug above.

So a session with rain under it chimes on the `playback` category — louder, and past the
ring switch — and that is correct rather than tolerated: the user has audio playing out
loud because they asked for it, and the sound that ends the session belongs with the sound
that ran through it. `AmbienceKeeper` hands the session back when the bed goes, and the
next silent session chimes under `ambient` again.

## Why the bed takes the audio rather than mixing under it

REQ-012 asks the app to honour the user's choice when music is already playing. Two
readings:

- **Mix.** The bed plays over their album. For a two-hour session that is two things at
  once for two hours, and the bed — designed to be unnoticeable — is the one that loses.
- **Take it.** Their music stops and the bed plays.

The second, and it is the more literal reading of "the user's choice": they chose rain,
from a picker that showed them what they were choosing, while music was playing. Choosing
Silence hands the session straight back and their music with it. `duckOthers` was
considered and is worse than both — an album at half volume under looping rain for an
hour is the option nobody would pick if it were offered in words.

## What this costs

**One file keeps a number about another.** A session that ends with a bed under it fades
the bed out in under a second, while four seconds of wind chime are still ringing *on the
same session*. Released straight away, the chime's tail would be re-categorised to
`ambient` mid-note and muted on a silenced phone — half a chime, which is worse than
either whole answer.

So `BundledAmbience` holds the session for five seconds after the bed has gone, in a
constant named `_chimeOutlastsTheBedBy`. That is a fact about the chime living in the
ambience, and it was taken deliberately over the two alternatives: releasing immediately
truncates the chime, and never releasing leaves the app on `playback` — ignoring the ring
switch for every session afterwards. The coupling is named rather than hidden, and it is
generous in the safe direction: being early is a cut-off chime, being late is a category
held a moment longer by an app that has already stopped making any noise.

**`ensureConfigured` never re-asserts.** Once anything has configured the session, the
chime stops asking. If a future ticket adds a third thing that wants its own category,
this class is where it goes — as a third `AudioUse` and a rule about who outranks whom —
and not as a `configure` call of its own. That is the whole point of the file.

## Consequences

- `BundledEndSound` takes an `AppAudioSession` and names no category. Its behaviour is
  unchanged for every session without a bed, which is every session before this ticket.
- `ios/Runner/Info.plist` gains `UIBackgroundModes: audio`. The category is necessary and
  not sufficient — without the background mode iOS suspends the app at the lock screen and
  `playback` makes no difference. Both are asserted in
  `test/platform/background_audio_test.dart`, because neither can be observed by playing
  anything on a workstation.
- The bed holds full audio focus for the length of a session, which is what makes a phone
  call able to take it and hand it back. What to do when it does is
  `AudioInterruptions`, kept free of players so that the decisions can be tested without
  a device.
