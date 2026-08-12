# RMS Driver

The rider's app: pick up a run, share your position, hand over with the
customer's code.

Built on `packages/rms_core` — the same API client (with working token refresh),
session, money, theme and sign-in journey as the other three apps.

## What it does

| Screen | What it is for |
| --- | --- |
| Sign in | Shared with the other apps; named "Driver sign in" so a rider knows which device they picked up |
| Which kitchen? | Outlet selection. Every read is branch-scoped; without it a rider would see another kitchen's board |
| Runs | The outlet's delivery board, ordered by how close each job is to a waiting customer |
| Run | One job: address, coordinates, progress, location sharing, and a single large action |

## Things worth knowing before changing it

**One action at a time.** A rider reads this one-handed, outdoors, in a hurry.
The screen offers exactly the transition the job's current status permits, and
both the button and the request it sends come from
`DeliveryStatus.nextActionPath` — so they cannot disagree, and the app can never
ask for a transition the server will refuse.

**The OTP is the customer's.** The backend returns the delivery code only when
the job is created, so staff can pass it to the customer. The app never displays
or caches it: a rider who could read the code could close a job without ever
arriving, which is the entire point of the check.

**Location is real, and it is off by default.** The app this replaces posted a
hardcoded walk around F-7 Markaz as if it were the rider's position — a customer
watching that map was being lied to about where their food was. Sharing now uses
the device GPS, is started deliberately by the rider, throttled to one report
per 25 m and no more than one per 15 s, and stops the moment the run reaches a
terminal state. A ping that fails is dropped rather than queued: a map wants
where the rider *is*, and replaying a four-minute-old fix would put the bike
somewhere it has already left.

**The board is the outlet's, not the rider's.** No endpoint scopes deliveries to
the signed-in rider — the list is branch-scoped, and the JWT carries a user id
rather than the `driverEmployeeId` a job is assigned by. The screen says so
rather than filtering on a guess and hiding a job someone is waiting on.

**An aggregator's job is read-only.** Only `provider: OWN` runs are driven from
here; anything else is tracked through that platform, so no buttons are offered.

## Running it

```bash
flutter pub get
flutter run --dart-define=RMS_ENV=development
```

`RMS_ENV` is `development` | `staging` | `production` (default). The server
address can also be overridden per build with `--dart-define=RMS_API_BASE=…`, or
in the field from the sign-in screen's **Server settings**.

Location permissions are declared in `android/app/src/main/AndroidManifest.xml`
and `ios/Runner/Info.plist`. Both fine and coarse are requested on Android,
because Android 12+ lets a user grant only the approximate one — and an
approximate fix still tells a customer roughly where their food is.

## Tests

```bash
flutter test
```

22 tests covering the board's ordering, every delivery transition, the OTP
hand-off, and the location rules above (throttling, dropped pings, and sharing
stopping with the run).
