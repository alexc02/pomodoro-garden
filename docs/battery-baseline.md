# The backgrounded-session battery baseline

PRD §4.4 budgets **under 3% battery per 25-minute session**. Ticket 24 owns meeting
that number with everything switched on — ambient sound playing, the live surface
active, the screen off. This document owns the number *underneath* it: what a bare
backgrounded session costs, with neither of those features built yet.

**The baseline is unmeasured.** Ticket 06 built the design it describes but had no
device to drain — no iOS hardware, no Android hardware, no emulator. What follows is
the method, so that taking the reading is an afternoon rather than a design exercise.

## Why take it now rather than at ticket 24

Ticket 10's ambient audio and ticket 08's live surface will dominate the number once
they exist: one keeps an audio session alive for 25 minutes, the other keeps a
foreground service and a Live Activity up. Measured together, they are indivisible —
a reading over budget tells you nothing about which of the three to look at.

Measured now, the session mechanism has the field to itself, and the reading is a
check on a specific claim rather than a number for a table.

## The claim being checked

**A backgrounded session should cost approximately nothing.** Not "a little" —
nothing distinguishable from the device sitting idle with the app closed. The design
has no background execution, no polling and no wakelock; it is one alarm, set when the
app leaves the foreground, and a row already written to SQLite. Between START and the
chime there is nothing of this app scheduled to run.

So the baseline is falsifiable, and that is its value. A reading meaningfully above
idle means something is running that the design says is not, and the two candidates
worth suspecting first are:

- a Dart timer still ticking behind `paused` — Android leaves the engine alive for a
  while after the app goes behind, and the foreground second-ticker is the thing most
  likely to be found still going
- an OEM battery manager holding the process up rather than letting it be frozen

Both are Android-side. On iOS a suspended app is suspended.

## Measuring it

The target is a small delta against a device's idle drain, so **an idle control run is
part of the measurement, not an optional extra.** Same device, same battery level
band, same duration, app force-quit. Subtract. A session run reported alone is a
reading of the device, not of this app.

Battery percentage is quantised to 1% and drains non-linearly at the ends of the
range, so: start every run between 80% and 60%, and run **four consecutive
25-minute sessions** rather than one. A 3% budget over one session is 12% over four,
which is coarse instrumentation reading a signal it can actually see.

### Android

Attribution and percentage want different setups, because USB charges the device.

**Percentage — untethered.** Reset the stats, pull the cable, run, plug back in and
read:

```bash
adb shell dumpsys batterystats --reset
# unplug; start a session in the app; lock the screen; wait
adb shell dumpsys batterystats --charged com.pipgarden.pip_garden
```

**Attribution — tethered.** `dumpsys battery unplug` makes the framework account as
though it were on battery while the cable stays in, which keeps `adb` available. The
percentage from such a run is meaningless — the device is charging — but the rows that
matter are not:

```bash
adb shell dumpsys battery unplug
# run the session, then:
adb shell dumpsys batterystats --charged com.pipgarden.pip_garden
adb shell dumpsys battery reset   # hand the framework back its real state
```

What to read, in the app's uid section: **estimated power use (mAh)**, **wakelock**
time — which should be none — **alarm** wakeups, which should be one, and **CPU**
time. Feed the same output to [Battery Historian] for the timeline view if a number
looks wrong and you need to see when it happened.

**Also check Doze**, because delivery is the risk this design carries and Doze is where
it fails. Force the device down and confirm the alarm still lands:

```bash
adb shell dumpsys deviceidle force-idle
# ... the session's end should still chime
adb shell dumpsys deviceidle unforce
```

[Battery Historian]: https://developer.android.com/topic/performance/power/setup-battery-historian

### iOS

There is no per-app percentage for a 25-minute window. Instruments' Energy Log needs a
cable, which charges; Xcode Organizer's Energy reports aggregate over days from
TestFlight and App Store builds, which is field data rather than a bench reading.

So iOS gets the coarse method and only the coarse method: **battery percentage delta,
untethered, against an idle control**, over the four-session run. Settings → Battery →
the 24-hour breakdown gives a per-app cross-check, and its buckets are hourly, which is
why the run is long enough to fill one.

Ticket 24 should wire up **MetricKit** (`MXAppRunTimeMetric`, `MXCPUMetric`) for the
field numbers it needs across a fleet. That is the right tool for its criterion and the
wrong one for this baseline — it reports daily, aggregated, from real installs.

## What ticket 24 added to this method

The procedure above is unchanged and is still the one to follow. Ticket 24 took no
reading — this machine still has no phone — but three things have changed under it
since it was written, and whoever runs it should know them. The full account is in
`docs/performance-record.md` §3.

- **The criterion is now the full stack.** This document measures the *bare*
  backgrounded session, which was ticket 06's claim. §4.4's 3 % is the session with
  ambient sound playing and the live surface up, so the run to take is the same one
  with a bed selected and REQ-033's switch on. Take the bare reading first anyway:
  measured together the three are indivisible, and a reading over budget would not say
  which of them to look at.
- **The garden animates continuously now** — REQ-023's sway, ticket 24, ADR 0020. This
  does not touch the number above, because a backgrounded app gets no frames at all and
  `TickerMode` stops the sway behind another tab. It does mean there is a *foreground*
  drain worth measuring that §4.4 never budgeted: a user sitting looking at their
  garden. If you have the device out, take that reading too.
- **Reduce Motion is a real switch here**, not just an accessibility one: it stops the
  sway's controller rather than ignoring it, so a phone with it on is a phone not asking
  for those frames. Worth a control run if the foreground number turns out to matter.

## Record the readings here

Fill this in when a device exists. Note the model and OS version: the number is not
portable between them, and PRD §10 asks specifically for an aggressive-OEM Android
device (Xiaomi, Samsung or Huawei) alongside whatever is convenient.

| Device | OS | Idle control, 100 min | 4 sessions, 100 min | Delta | Per session |
|---|---|---|---|---|---|
| | | | | | |

Anything at or near zero confirms the design. Anything above roughly 1% per session
is a finding, and the two suspects above are where to look before ticket 24 inherits
it.
