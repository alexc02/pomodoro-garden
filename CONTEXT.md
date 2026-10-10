# Pomodoro Garden

A focus timer whose reward is a garden. The user runs focus sessions; each completed
session plants something that stays. This file is the project's glossary — the words the
code, the tickets and the PRD all have to agree on. It holds no implementation detail.

## Language

### The session lifecycle

**Focus session**:
One stretch of intentional focus, of a length the user chose before it began.
_Avoid_: pomodoro, timer, run, sitting

**Anchor**:
The UTC instant a focus session began. Every question about how far along a session is
gets answered from the anchor and the current instant, never from counting.
_Avoid_: start tick, t-zero

**Planned duration**:
How long a session was meant to run when it started. Fixed for the life of that session —
changing the setting mid-session changes the *next* one.
_Avoid_: length, target, goal

**Elapsed**:
How much of the planned duration a session has consumed at a given instant. Never exceeds
the planned duration.
_Avoid_: time spent, progress (progress is the fraction, not the duration)

**Remaining**:
Planned duration minus elapsed. What the countdown shows.

**Progress**:
Elapsed as a fraction of planned duration, 0 to 1. What the ring fills to.

**Paused**:
A session whose countdown is held. It has not ended and it has not stopped growing —
paused time buys growth at half rate — but no paused second is an elapsed one, so a
session resumes exactly where it was held and ends later by however long it was held for.
_Avoid_: stopped, suspended, on hold

**Paused duration**:
How long a session has spent paused, over every pause that has *finished*. Recorded on the
session, because it is the difference between when a session was anchored and when it can
end. The pause a session is currently in is not in it — an open pause has no length yet,
only a start.
_Avoid_: pause time, total pause

**Paused so far**:
Paused duration plus however long the open pause has been running, asked of the clock at
the instant someone wants to know. What the screen counts up while a session is held, and
what half-rate growth is charged against. Distinct from paused duration because one is a
record and the other is a reading.

**Completed**:
A session that reached its planned duration. The only outcome that earns a plant.
_Avoid_: finished, done, ended, expired

**Ended**:
A session that is no longer running, by any route — completed, cancelled or voided.
Every completed session has ended; not every ended session completed.

**Cancelled**:
A session the user deliberately abandoned before its planned duration. Earns nothing.
_Avoid_: stopped, quit, aborted

**Voided**:
A session that ended without the user deciding to end it — the app was force-quit
mid-session. Earns nothing, and is distinguished from cancelled because the user's intent
differs even though the outcome does not.
_Avoid_: crashed, lost, orphaned

**Recorded session**:
The stored row for a session. Written when the session starts, updated when it ends. The
garden and every statistic are computed from these rows, never from a running counter.

### The garden

**Plant**:
What one completed session left behind. A stored record, not a drawing: it knows its
type, its species, the stage it reached, the day its seed went in and how long the
session that grew it was. Every plant in the garden came from a session; not every
session left a plant.
_Avoid_: reward, tree, flower (those are types)

**Plant type**:
Which of the six tiers a session earned, decided only by how long the session was
planned to run — wildflower, herb, flower, bush, small tree, large tree. A user picks a
type by picking a session length.
_Avoid_: tier, category, plant kind

**Species**:
Which plant within the type: basil rather than "a herb". Chosen when the seed drops and
fixed from then on — derived from the session's id, so asking again always gives the
same answer.
_Avoid_: variety, variant

**Milestone**:
A count of completed sessions that earns a plant on its own — ten, twenty-five, fifty, a
hundred, two hundred and fifty, five hundred, a thousand. Seven of them, and a milestone
*is* its count: that integer is what the garden stores and what an award is recognised by,
so the name is only what the user is shown.
_Avoid_: achievement, badge, level, streak

**Bonus plant**:
What a milestone awards. A plant in every respect that matters — it stands in a plot, it
has a species, it opens a card — and not a session's plant in the one that does: no
session grew it, so it has no length to report and it is no part of any count of work
done. A plant is a bonus plant exactly when it carries a milestone; there is no second
flag saying so.
_Avoid_: reward plant, special plant, trophy

**Award**:
The giving of a bonus plant, and the plant itself once given. Made against the *total*
number of completed sessions rather than at the moment one is crossed — the app is not
running when the number goes past — and made once, because what decides whether a
milestone is owed is whether its plant is already in the ground.
_Avoid_: unlock, grant, trigger

**Celebration**:
What the app says when an award is made: one quiet sheet, after the fact. Distinct from
the award, which has already happened — the plant is in the garden before anything is on
screen, and a celebration the user never saw costs them the animation and not the plant.
Never shown over a countdown.
_Avoid_: popup, congratulation, confetti

**Bloom**:
§5.3's "session end celebration": the timer screen's plant springing and throwing petals
for two seconds at the instant a session completes, then settling into its sway. Played
only for a completion the user watched — never for one found on the way back into the
app, never for a cancelled or voided session, never under reduced motion, and never in
the garden. Not a *celebration* in the sense above: it marks a session, not an award, and
at a milestone the celebration waits for the bloom to finish before it rises.
_Avoid_: session celebration, confetti, end animation

**Growth stage**:
How grown a plant looks: seed, sprout, young, maturing, mature. A pure function of how
far through its session the plant is, never a stored position that advances. A stage is
noticed the same way completion is — by asking — so a plant looks right whether the app
watched it grow or has just been opened.
_Avoid_: growth level, phase, step

**Growth progress**:
How far through its growing a plant is, 0 to 1 — which is *not* how far through its
session the plant is. The two are the same number until the session is paused, and after
that the plant is ahead: a paused minute buys half a minute of growth while buying no
elapsed time at all. Progress fills the ring; growth progress decides the stage.

**Planted**:
A plant's date is the day its seed went in — its session's anchor — not the day the
session finished. A session that ran across midnight belongs to the evening the user
remembers working.

**Plot**:
One slot in the isometric grid, where one thing can stand — a plant, or one of ticket
20's decor items, and never both. A pair of grid coordinates, not a place on screen —
where a plot lands moves every time the user drags the garden; which plot a plant is in is
decided once, when it is planted, and written down.
_Avoid_: slot, cell, tile (a tile is the *picture* of a plot's ground)

**Placement order**:
The two hundred plots, nearest the middle of the garden first. A new plant takes the
first one in it that is free, which is what "nearest available plot" means and why a
garden fills outwards from its centre. Fixed, and decided by integer arithmetic only, so
it is the same order on both platforms and in every version.

**Sowing**:
Where a new plant goes and what has to leave for it. Free of both plants and decor
ordinarily — an item is stepped over, not pushed aside — and only in a garden whose two
hundred plots all hold something does an item give way, the outermost one first. Decor is
never the reason a completed session goes unplaced. See `docs/adr/0017-…`.
_Avoid_: planting (that is the act), allocation

**Capacity**:
How many plots the garden has. A *floor* derived from completed sessions — twelve, plus
four per ten sessions, up to two hundred — and never fewer than the plants standing in
it. Capacity bounds what the garden shows, never what the app remembers.
_Avoid_: garden size, plot count as a stored number

**Unplaced**:
A plant the garden had no plot for: the two-hundred-and-first and beyond. Recorded like
any other plant and not drawn. Kept rather than dropped, because a session somebody sat
through is not something to lose to a display limit.

**Sprite**:
The picture of one plant type at one growth stage. Thirty of them. Every plant on screen
is drawn through a sprite obtained from the registry, and no screen names an image of
its own; that is what makes the real art a drop-in replacement.
_Avoid_: asset, image, icon

**Atlas**:
The one texture every picture in the garden is baked into — the plants and the decor
together — so that two hundred plants and the benches among them are one draw call. Built
out of the registries, never out of a named image, which is what keeps ticket 23 an asset
swap. One texture rather than two on purpose: a second would be a second batch, and a
bench in a batch of its own is always in front of every tree or always behind every tree.

**Footprint**:
How much of the square it is drawn in a sprite's picture actually fills. The sprite's own
answer, because only the picture knows — a wildflower fills the bottom half of its square
and a large tree fills all of it. It is a box rather than an outline: what it decides is
which plant a finger landed on, and a finger is wider than the gap between two petals.
_Avoid_: bounds (a sprite's *box* is its bounds), hitbox

**Season**:
Which of spring, summer, autumn and winter the garden is dressed for, read off the
device's local date and nothing else — three whole months each, turning at midnight on
the first. Not stored anywhere and not a plant's property: a plant grown in the snow is
a plant, in a garden that is snowy today. A season reaches the garden's colours and the
weather over them, and nothing else in the app.
_Avoid_: theme (that is the biome the user picked, and a different idea), time of year,
mode

**Hemisphere**:
Which way round the calendar's seasons run for this device. Guessed from the time zone —
whichever half of the year it puts its clocks forward in is its summer — never asked for
and never located. Zones with no daylight saving cannot be read and get the northern
calendar.

**Weather**:
What falls through a season's air: blossom in spring, leaves in autumn, snow in winter,
and nothing in summer. Ambient by definition — it takes no taps, says nothing to a screen
reader, and there is a fixed ceiling on how much of it can be in the sky at once.
_Avoid_: particles (that is how it is drawn), effect, overlay

**Theme**:
Which biome the user's garden is — the Zen Garden, the Tropical Greenhouse or the
Wildflower Meadow. Chosen, unlike a season, and free of the calendar: a theme is a thing
somebody picked and two of the three are things somebody bought. It reskins the garden's
background, its soil tiles and its decor, and it reaches nothing outside the garden — the
timer's ring is the same colour in the meadow as in the greenhouse. Every theme still
turns with the seasons, so what is actually on screen is a *skin*.
_Avoid_: biome (right idea, but "theme" is the word REQ-034 and the picker use), palette
(that is the colours it resolves to), skin (that is theme *and* season)

**Skin**:
How the garden is dressed at this moment: one theme, in one season. The pair, because
neither half decides a colour on its own — there are twelve of them and each is a
picture somebody chose rather than a rule applied to another picture. The only thing the
garden is ever painted from.
_Avoid_: theme, season (a skin is both), variant, style

**Decor**:
Two things that are deliberately one word, because they are one idea seen from two
sides: the *material* a garden's furniture is cut from — Zen's stone, the greenhouse's
teak, the meadow's silvered fence wood — and the *objects* cut from it that the user
stands in their empty plots. The material is the one garden colour a season leaves
alone: sky, soil, leaves and flowers all turn with the calendar, and a lantern does not.
What a season does reach is what an object holds — a pond's water, the shadow under a
bench, the light in a lantern.
_Avoid_: furniture, ornament, accent

**Decor item**:
One object standing in one plot: a stone lantern, a bench, a birdbath or a pond. A
decision rather than a record, and that is the whole difference between it and a plant —
a plant is an afternoon somebody sat through and is kept whatever happens to the garden
around it, where an item is something the user put down and can put somewhere else in two
taps. So an item always has a plot, and the one thing that can take it out of the garden
besides the user is a completed session with nowhere else to go. See `docs/adr/0017-…`.
_Avoid_: decoration, prop, asset

**Arrangement**:
Everything the user has stood in their garden, as one thing. Kept in a table of its own
beside the plants, and never deleted by anything but the user or a completed session with
nowhere else to go: what somebody composed is theirs.
_Avoid_: layout (that is the garden's plots), decor set

**Arranging**:
The mode the garden is in while the user is composing rather than looking. A tap means one
thing at a time and the screen says which — ordinarily a tap on a plant opens its card, and
while arranging a tap on empty soil puts something in it and a tap on an object picks it
up. Entered deliberately and left the same way, because a garden where every tap might
move something is a garden to be careful in.
_Avoid_: edit mode, decorating

**Camera**:
Where the garden is being looked at from: a zoom and a pan. The one thing that turns a
plot into a point on screen and a tap back into a plot. Reaches the screen and nothing
else — an *export* is drawn without one.
_Avoid_: viewport, transform, matrix

**Export**:
A picture of the whole garden, and the act of making one. Drawn rather than captured: the
same painter the screen uses, at a projection fitted to the garden itself, so an export is
never a screenshot of what the camera happened to be showing and never has a scrap of the
app in it. What it holds is what the garden holds — the background, today's season, the
chosen theme, every plant and every decor item — and nothing else. See `docs/adr/0018-…`.
_Avoid_: screenshot, capture, snapshot, render (that is how it is made)

**Sheet**:
The rectangle an export is drawn on: the garden's own bounds plus a margin of sky. The
garden's size rather than a fixed canvas, so a new user's twelve plots make a small
picture of a garden and not a small garden lost in a large picture. Measured in the same
logical units everything else in the garden is; how many pixels it becomes is a separate
decision. (The word is also Flutter's for a modal — a plant's *card* arrives as one — and
that is a different idea entirely.)

**Share sheet**:
Where a finished export goes: the platform's own, `UIActivityViewController` on iOS and a
chooser on Android. One destination and not two, because *Save Image* and *Save to Photos*
are rows **inside** it — so "reaches the share sheet" and "saves to the photo library" are
one action the app takes and one choice the user makes in it. What they choose is the
platform's business and is never reported back.
_Avoid_: share dialog, export sheet, save panel

**Card**:
What one plant says about itself when it is tapped: its species, the day it was planted,
how long its session was, how grown it is, and a quote. The plant's own page, and the
only place a plant is more than a picture. That it happens to arrive as a modal sheet is
how it is built, not what it is.
_Avoid_: popup, detail view, plant info

**Quote**:
The line about growth or patience on a plant's card. Drawn from a bundled set by the
plant's id, the same way a species is drawn by its session's — so a plant says the same
thing every time it is opened, months apart, rather than reshuffling on each visit.
_Avoid_: message, tip, affirmation

### The journal

**Journal**:
What the user has done, as a page rather than as a dashboard: the week behind them, the
month as a shape, and the totals that only go up. Derived in its entirety — six aggregate
queries over the sessions and the plants — so there is no figure in it that can disagree
with the garden next door.
_Avoid_: stats, analytics, dashboard, metrics

**Calendar day**:
One day on the device's own calendar: a date, with no time in it. The unit the journal
counts in, and deliberately not a span of hours — two days a year a local day is
twenty-three or twenty-five hours long, and neither of them is a day and a bit.
_Avoid_: date (the word is fine in prose, but the type is a day), 24 hours

**Anchored to a day**:
Which day a session belongs to: the local one its *anchor* fell in, whatever time it
finished. The evening the user remembers working, and the same day the plant it grew is
dated. See `docs/adr/0012-…`.
_Avoid_: session date, logged on

**Week**:
Seven days starting where the user's locale starts them — Monday in Berlin, Sunday in
Chicago, Saturday in Cairo. Never a fixed day, and never the last seven days: a week is a
thing with a first day, and "this week" is the one today is in.

**Streak**:
How many days in a row have at least one completed session in them, counting back from the
most recent. Derived from the days, never stored and never reset, so nothing can be owed
one. A day that has not finished is not a day that was missed — a user who has done nothing
yet today still has yesterday's streak until midnight.
_Avoid_: chain, run, combo

**Rested**:
How long it has been since the last completed session, once a whole day has gone by with
none. The only thing the app has to say about a gap, and it says it as REQ-029 does: *your
garden rested for two days*. There is no longest streak recorded and nothing to have fallen
short of, because a number the app keeps is a number it can hold over somebody.
_Avoid_: broken, lapsed, missed, lost

**Garden level**:
The same rule as capacity, said as a number the user keeps: one to start, and one more per
unlock. Level *n* has twelve plots plus four for each level above the first, so the two can
never disagree.
_Avoid_: rank, tier, XP

**Heatmap**:
The month drawn as a grid of days, each shaded by how much was grown in it and scaled to
that month's own busiest day. An empty day is bare soil rather than a gap — the user is
being shown the shape of their month, not measured against anyone else's.
_Avoid_: chart, graph, calendar (a heatmap is not something you can put an appointment in)

### Time

**Clock**:
The domain's only source of the current instant. Injected, so a test owns time.
_Avoid_: now, system time

**Tick**:
A repaint cue, nothing more. A tick tells the screen to re-read the clock; it never adds
to elapsed time and never decides that a session is over.
_Avoid_: countdown step

**Poll**:
Asking the session what it looks like at a given instant. Polling is how a session is
observed to have completed — completion is noticed, not fired.

### Settings

**Settings**:
Everything the user has chosen about how their timer behaves, as one value. Singular —
"the settings" is one thing that changes as a whole, not a bag of independent keys. Read
everywhere through one typed accessor; a feature never looks a setting up by name.
_Avoid_: preferences, config, options

**Session length**:
The setting. How long the *next* session started will run. Distinct from planned duration,
which is what one particular session was handed when it began: changing the session length
never touches a planned duration already in flight.
_Avoid_: duration, timer length

**Break length**:
How long a break runs. The setting exists from ticket 03; ticket 09 is the first to start
a break with it.

**Long break after**:
How many focus sessions run before the break becomes a long one.
_Avoid_: cycle length, interval

**Preset**:
A named session length — Short, Classic, Deep. Not a fourth setting, and not a mode: a
preset is one value the session length can hold, reachable in one tap. The custom control
can reach the same value, and does not disagree with the chip when it does.

**Ambient sound**:
The setting. Which of six — Rain, Forest, Ocean, Café, White Noise or Silence — the user
has chosen to hear under a focus session. Silence is one of the six rather than the
absence of the other five: a user who wants nothing has chosen something, and it is
stored and defaulted like any other value. Unlike the session length it is not frozen when
a session begins — changing it changes what is playing, there and then.
_Avoid_: background sound, soundscape, audio setting

**Bed**:
What an ambient sound actually is while it plays: one loop, under everything, for as long
as the session runs. A session has a bed or it does not; a break never has one, and
neither does an idle timer. The word is for the thing playing, where "ambient sound" is
for the thing chosen.
_Avoid_: track, loop (a loop is the *file*), background music

**Ambience**:
The machinery that puts a bed under a session: the port, the players behind it, and the
thing keeping the two in step with the timer. Not a fourth word for the sound — a user
chooses an *ambient sound*, hears a *bed*, and never meets this one. It is the name of the
part of the app, which is why `lib/src/ambience/` is called that and nothing on screen is.

**End sound**:
The setting. Which of six — Wind Chime, Soft Bell, Birdsong, Singing Bowl, Ocean Wave or
None — the user has chosen to hear at the moment a focus session or a break runs out. None
is one of the six rather than the absence of the other five, on the same terms Silence is:
a user who wants nothing has chosen something, and there is no separate switch beside the
choice. Unlike the ambient sound it is not reachable from the timer — the moment it matters
is the moment the session ends, which is too late to choose.
_Avoid_: completion sound, alert, chime (a chime is the thing playing), notification sound

**Chime**:
What an end sound actually is while it plays: one short sound, once, at the moment
something finishes. The word is for the thing heard, where "end sound" is for the thing
chosen — the same two-sided distinction *bed* and *ambient sound* make, and it is worth
having for the same reason: a session has a bed under it for half an hour and is chimed at
once. The wind chime is a chime; so is the birdsong, which is what makes this a role
rather than a description of a sound.
_Avoid_: ding, alert, ping

**End sound player**:
The machinery that makes a chime: the port, the `just_audio` player behind it, and the two
platform copies of every file. Not a third word for the sound — a user chooses an *end
sound*, hears a *chime*, and never meets this one. Named for what it does because
`EndSound` is the choice, and the pair reads the way *ambient sound* and *ambience* do.

**Micro-sound**:
One of the four short sounds the app makes in answer to something the user is looking at:
the soil settling as a seed lands, the shimmer as a plant reaches a stage, the tap under a
button that starts or ends something, and the unlock when a milestone is celebrated. §9.2
names all four — §5.4 specs the first two — and there is no fifth — a closed set, unlike the sounds the user chooses
between, because nobody chooses these and nobody is meant to notice them individually.
They are the only sounds in the app with no setting of any kind behind them: what turns a
micro-sound down is the phone's own volume, and what silences it is the phone's own silent
switch. Distinguished from a *chime*, which announces something that has finished, by
what it is for — a micro-sound accompanies, and never announces.

The machinery has no separate word, and that is the one place this set breaks the habit
*ambient sound* / *bed* / *ambience* sets. It is one port named for the sounds themselves —
`MicroSounds`, in `lib/src/feedback/` — because there is no third idea here to name: nobody
chooses a micro-sound, so there is no choosing half to tell apart from a playing half, and
a second noun would be a word for the same thing said twice.
_Avoid_: UI sound, effect, SFX, blip, click (a click is a fault in a waveform)

**Quiet mode**:
The phone going quiet for the length of a focus session. One word for one idea, and
deliberately not "Do Not Disturb" or "Focus" — those are the two platforms' names for
their own machinery, and only one of them can be driven from an app at all. What a user
turns on is quiet mode; what happens underneath is the platform's business.
_Avoid_: DND, Focus mode, silent mode

**Access**:
What the phone will let the app do about quiet mode, asked of it rather than assumed:
granted, denied, wired up by the user themselves, or nothing doing. The one place the two
platforms' asymmetry lives — every screen and every rule above it reads an access, and
none of them asks which phone it is on.
_Avoid_: permission (it is one on Android and not a thing at all on iOS), capability

**Deadline**:
The instant quiet mode lifts by itself, handed to the platform when the silence starts.
Not when the session ends — the session ending is what *ordinarily* ends quiet mode — but
the promise that it ends anyway, with the app killed and nothing of it running. A phone
left silent by an app nobody opens again is what the deadline exists to prevent.
_Avoid_: timeout, expiry

### Onboarding

**Onboarding**:
The first launch: three steps that end in the user's first session, and the three coach
marks over it. One thing with a beginning and an end, shown once per install and left
behind by any route out of it — a user who skipped it has been through it. Not a tutorial
mode the app is in and not a screen: it is a layer over the app, which is already running
underneath.
_Avoid_: tutorial, walkthrough, intro, first-time experience

**Step**:
One of the three screens of the flow, in order: welcome, session length, start. Three is
the count, not a maximum somebody is working towards — the third step starts the session,
so there is no fourth for a later ticket to add. Every step can be skipped, and skipping
any of them skips all of them.
_Avoid_: page, slide, screen

**Coach mark**:
One thing worth knowing, said over the live app rather than in a slideshow: the timer, the
garden, the journal. Three of them, one on screen at a time, each put away on its own and
none of them able to stop the session underneath — a coach mark points at a real widget
and takes only the taps that land on its own card.
_Avoid_: tooltip, hint (ticket 11's quiet-mode hint is a different thing), popover, tour step

**Preview garden**:
The flourishing garden on the welcome step. Made up, and drawn by the real painter over the
real sprites — a first-run user's own garden is bare soil, and showing them that would be
showing them the reward as an empty field. Nothing in it is stored and nothing in it can be
tapped.
_Avoid_: sample garden, demo, mock

### Free

**Free**:
What this app costs, and the whole of the vocabulary that used to be here. There is no
premium, no entitlement, no product, no store, no purchase and no paywall — nine words
that named a feature this app no longer has, removed with it rather than left in the
glossary for somebody to write code against. Every feature is every user's.
_Avoid_: free tier, free version, freemium, unlocked (all four imply a paid half)

### Analytics

**Event**:
One thing worth knowing about how the app is used, as a value rather than as a name and a
bag of parameters. PRD §7.1's table, typed: a call site builds `SessionStarted(…)` and
cannot misspell it, omit a parameter or put a species where a stage goes. Recorded, never
"sent" — there is nowhere for it to go.
_Avoid_: metric, telemetry, tracking, hit, log line

**Analytics**:
The one port every event is recorded through. One method, no future on it: recording
returns at once and never throws, so no user action ever waits on the log or can be failed
by it. The seam a real sink would arrive at, and the reason no call site would have to
change if one ever did.
_Avoid_: tracker, logger, provider (that word is Riverpod's here), SDK

**Event log**:
Where the events are kept: a table in the same SQLite file the sessions are in, on this
device, and nowhere else. Bounded — the oldest rows go as new ones arrive — because
nothing in it is a history the user is entitled to. Cleared by a *reset*, along with
everything else the app remembers about a garden the user asked it to forget.
_Avoid_: analytics database, history, audit trail

**Recorded**:
What the app does with an event: writes it down here. The word is deliberately not
*collected*, *reported* or *sent* — PRD §7.2's promise is that nothing leaves the device,
and the Apple privacy labels and the Play Data Safety form both say so in public.
_Avoid_: collect, report, send, upload, track

### Starting again

**Reset**:
Everything the app remembers *about a garden*, forgotten at once: the plants, the sessions
behind them, the arrangement over them and the event log beside them — four tables, in one
transaction, because a garden half-cleared is a state no user could have reached. What it
leaves is everything that is not a garden: the settings, and the purchase. Asked for twice
and refused outright while a timer is in flight, because it is the one thing in this app
that destroys something.
_Avoid_: clear, wipe, erase, delete my data, factory reset

**Fresh start**:
What a reset leaves behind, and the reason the word is worth having: twelve plots of bare
soil, no streak, no milestone awarded, and a user who still has their session length at
fifty minutes and their garden in the theme they chose. Not a *new install* — the app has
not forgotten the person, only the garden — which is why onboarding does not come back.
_Avoid_: first run (that is a genuinely new install), blank slate

### Holding the numbers

**Sway**:
The one continuous motion in the app: a mature plant leaning two degrees on a four-second
loop, offset per plant so a garden moves like a garden rather than a heartbeat. Drawn two
completely different ways — one `CustomPaint` on the timer, one quad of a `drawAtlas`
batch in the garden — off one definition, because the plant a user watched grow has to
lean the same way when they go and find it. A garden with the sway in it is a screen that
never stops asking for frames, which is the whole of what it cost.
_Avoid_: wobble, wave, animation (there are several), idle animation

**Baked**:
What happens to the pictures once, so that nothing has to happen to them per frame: every
sprite is rendered into one texture, and a frame is then a batch of quads cut from it.
Baking is expensive and it is a one-off — on launch, and when the colours under it change.
A frame that bakes is a bug, and it is the one this project has a counter for.
_Avoid_: render, cache, generate, preload

**Budget**:
A number from PRD §4.4 that the app has to come in under, as opposed to a number it
happens to hit. The distinction matters because most of them cannot be measured here: a
budget with no reading against it is still a budget, and `docs/performance-record.md` is
where each one's reading, or the absence of it, is written down.
_Avoid_: benchmark (that is how a reading is taken), limit, target

**Still owed**:
The phrase for a criterion whose method is settled and whose measurement needs hardware
this project does not have. Not *failing* and not *unknown* — the work to do is named, and
the reason it has not been done is a phone rather than a decision.
_Avoid_: TODO, blocked, unverified, pending
