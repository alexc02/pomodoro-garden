# The garden has a plot for every plant it can hold

REQ-018 sets the garden's capacity: twelve plots to start, four more per ten completed
sessions, two hundred at most. REQ-017 says a new plant goes into "the nearest available
plot slot". Read together and taken literally, the two say a plant is dropped once the
plots run out — and they run out much sooner than the wording suggests.

A session earns one plant. Ten sessions earn four plots. So plants arrive two and a half
times faster than plots do, and the two curves cross at the **twenty-first** completed
session: twenty-one plants, twenty plots. A user hits that in a fortnight of ordinary
use, four hundred and fifty sessions before the two-hundred cap is anywhere in sight.

So the literal reading cannot be the intended one. Taken literally, the reward for
finishing a session is that the app tells you it has no room for what you grew.

## The decision

**The unlock count is a floor, not a ceiling.** It is how much *empty soil* the garden
puts in front of the user, and nothing else. The garden's actual size is

```
plots = clamp(max(unlockedAfter(completedSessions), plantsInTheGround), 12, 200)
```

which is `GardenLayout.of`, and the whole of it.

Before the twenty-first session that is REQ-018 exactly: the schedule is larger than the
garden and the difference is bare plots to fill, which is the progression the requirement
is describing and the reason it exists. After it, the schedule is smaller than the garden
and stops being visible — a full garden simply grows by one plot for each plant, which is
what a garden does.

`GardenPlots.unlockedAfter` implements REQ-018 unchanged and is tested against its exact
numbers, so the requirement is still written down somewhere it can be checked. The
reconciliation is one line above it rather than hidden inside it.

## What happens to the 201st plant

At two hundred plots the floor stops rising and the garden stops growing. The ticket asks
for this case to be decided rather than crashed on, and the decision is:

**The plant is recorded. It is not given a plot, and it is not drawn.** `plot` is null on
its row, `GardenLayout.unplaced` collects it, and the garden screen says how many are
being held.

Capacity bounds what the garden *shows*, never what the app *remembers*. The alternatives
were all worse:

- **Refuse to plant it.** The user sat through the session. Losing the record loses it
  from ticket 15's journal, ticket 17's statistics and ticket 21's export too, none of
  which have a two-hundred limit or any reason to.
- **Replace the oldest plant.** The garden is the record of the work, and the oldest
  plants are the ones the user has kept longest. Deleting history to make room is the one
  thing this product must not do.
- **Reuse a plot, stacking two plants in it.** The nearer one hides the further one, so
  it is losing a plant with extra steps, and it breaks ticket 12's hit-testing, which
  assumes one plant per plot.

Reaching this at all takes two hundred completed sessions. Anyone who does deserves a
better answer than a counter, and ticket 22's reset is the only one available today —
so the count is surfaced rather than swallowed, which is what puts the question in front
of whoever picks up ticket 20's decor placement or a second garden.

## Consequence for the placement rule

Because the garden is never smaller than what is planted in it, `GardenPlots.nextFree`
searches the full two hundred plots rather than only the unlocked ones. A plant never
waits for an unlock; it takes the nearest free plot and the garden grows to include it.
That is also what keeps the rule stable under deletion: a garden with a hole in the
middle grows back into the hole rather than continuing outwards.
