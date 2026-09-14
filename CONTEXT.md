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
One complete play from the first Finger landing to Results being shown or the Round being Aborted.
_Avoid_: Game, match, session

**Gathering**:
The phase in which Fingers join the screen. A Round stays in Gathering until at least two Fingers are present and the set of Fingers has been unchanged for three seconds.
_Avoid_: Waiting, lobby, setup

**Lock-in**:
The moment the set of Fingers becomes final and the Round leaves Gathering. From Lock-in until Results, any new Finger landing on the screen is ignored.
_Avoid_: Ready, start, arm

**Locked**:
The brief phase immediately after Lock-in, before the Countdown begins, in which the Fingers are announced as committed.

**Countdown**:
The phase between Lock-in and Go: five, four, three, two, one, spoken at a fixed one-second cadence.

**Go**:
The distinct cue one beat after the Countdown reaches one. It is the zero point for every Lift time in the Round.
_Avoid_: Start, zero, release

**Race**:
The phase after Go during which Fingers lift and earn Places.

**Results**:
The phase after the Race in which each Finger's Place and Lift time is displayed at the spot where it lifted. Any new Finger landing during Results begins a new Round.
_Avoid_: Scoreboard, summary, leaderboard

**Aborted**:
A Round torn down because the operating system cancelled every touch, either because the device's finger limit was exceeded or because the app lost focus. Returns to Gathering with an explanation on screen.
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
