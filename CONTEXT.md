# Stuzer

A shared-screen party app that decides who goes first in a board game. Everyone rests a finger on one phone or tablet, a countdown runs, and the fastest finger off the screen after the starting cue is the first player.

## Language

### Participants

**Finger**:
One touch the screen is tracking, from the moment it lands until it lifts. The app only ever knows fingers, never the people behind them.
_Avoid_: Player, touch, pointer, contestant

**Place**:
A Finger's rank in a finished Round, first through last. Earlier Lift after Go earns a better Place.
_Avoid_: Rank, position, standing

### Round lifecycle

**Round**:
One complete play from the first Finger landing to Results being shown or the Round being Aborted. The shell of a Round (Gathering, Lock-in, Results, Aborted) is the same in every Mode; what happens in between belongs to the Mode.
_Avoid_: Game, match, session

**Mode**:
One way of turning a locked set of Fingers into a Ranking. Race and Classic exist; a Mode is chosen while no Fingers are on the screen and remembered for next time.
_Avoid_: Game type, variant, rule set

**Ranking**:
The full ordering of Fingers a Mode produces, together with how many leading Places it actually decided. Undecided Places fall back to landing order and are not shown.
_Avoid_: Leaderboard, scores

**Gathering**:
The phase in which Fingers join the screen. A Round stays in Gathering until at least two Fingers are present and the set of Fingers has been unchanged for three seconds.
_Avoid_: Waiting, lobby, setup

**Lock-in**:
The moment the set of Fingers becomes final, the Round leaves Gathering, and the chosen Mode takes over. From Lock-in until Results, any new Finger landing on the screen is ignored.
_Avoid_: Ready, start, arm

**Locked**:
The brief beat immediately after Lock-in, in every Mode, in which the Fingers are announced as committed.

### Race Mode

**Race**:
The Mode in which Fingers lift after Go and are ranked by Lift time. Stuzer's default Mode.

**Countdown**:
The Race phase between Locked and Go: three, two, one, spoken at a fixed one-second cadence. If every Finger has lifted before "one" is spoken, the Round is Aborted; from "one" onward, everyone letting go is simply a False Start for all.

**Go**:
The distinct cue one beat after the Countdown reaches one. It is the zero point for every Lift time in the Round.
_Avoid_: Start, zero, release

**Racing**:
The Race phase after Go during which Fingers lift and earn Places.

### Classic Mode

**Classic**:
The Mode in which a Spotlight hops between held Fingers during a Suspense and stops on one at random. Only first Place is decided.

**Suspense**:
The Classic phase after Locked in which the Spotlight hops with slowing rhythm. A Finger that lifts during Suspense drops out of the draw.

**Spotlight**:
The single highlighted Finger during Suspense; where it stops is the Chosen Finger.
_Avoid_: Cursor, selector

**Chosen**:
The Finger the Spotlight stopped on: first player in Classic.
_Avoid_: Winner, picked

### Shared phases

**Results**:
The phase after a Mode finishes in which the Ranking is shown in that Mode's own way. Any new Finger landing during Results begins a new Round.
_Avoid_: Scoreboard, summary, leaderboard

**Aborted**:
A Round torn down before it could finish: the operating system cancelled every touch, the app lost focus, or every Finger let go before the Countdown reached "one". Returns to Gathering with an explanation on screen.
_Avoid_: Crashed, failed, reset

### Events

**Lift**:
The moment a Finger leaves the screen, including sliding off its edge. Its time relative to Go decides its Place.
_Avoid_: Release, remove, let go, up

**False Start**:
A Lift that happens after Lock-in but before Go. False Starters are placed behind every legitimate Finger, and among themselves the earliest Lift is placed last.
_Avoid_: Jump, early release, foul

**Straggler**:
A Finger still held on the screen well after Go. Stragglers are teased on screen and, if still held when the Race closes, placed behind every Finger that lifted.
_Avoid_: Holdout, late finger, DNF

**Tie**:
Two or more Fingers that would otherwise share a Place, including Stragglers that never lifted. Always broken in favour of the Finger that landed on the screen first.
