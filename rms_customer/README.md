# RMS Customer

Browse a restaurant's menu, order, and follow it to the door.

Built on `packages/rms_core` — the same API client (with working token refresh),
session, money, catalogue, theme and sign-in journey as the other three apps.

## The journey

Sign in → choose a restaurant → menu → basket → place → follow it.

## Things worth knowing before changing it

**The basket is priced with the waiter's arithmetic.** `computeDraftTotals` in
`rms_core` is the same function the till uses. A guest quoted one figure here
and charged another at the counter has been misled, and two implementations of
the same tax and rounding rules would drift within a release. It is still only a
prediction — the restaurant re-prices every line when it accepts the order, and
the screen says so.

**Ordering twice is the failure to design against.** Placing an order is three
calls (create, add items, place) on a phone that can be locked, backgrounded or
killed between any two of them. The idempotency key is minted once, persisted,
and reused by every attempt, and the stage reached is recorded — so tapping
"Place order" again after losing signal continues the attempt rather than buying
a second dinner. If the flow is interrupted, the screen says the restaurant *may*
already have part of the order, because claiming otherwise would be a guess the
kitchen could contradict.

**The delivery address is honest about an unverified field.**
`POST /restaurant/orders` was only ever observed taking `channel`, `guestCount`
and `branchId`; whether it accepts an `address` is **unverified**. The app this
replaces collected an address and silently dropped it — a customer who typed
where they live and got food nowhere. So the address is sent; if the server
refuses the request because of it, the order is retried without and the tracking
screen tells the customer to expect a call, with the address kept on screen to
read out. Degrading loudly beats degrading silently. Worth fixing server-side.

**The backend's status names never reach the screen.** `CONFIRMED` means
something precise to a kitchen and nothing to a guest. `OrderProgress` is the
single place that translates, and it is a pure function of (order status,
delivery status) so every combination can be pinned down by test — this is the
screen a hungry person stares at, and a step that lights up early is somebody
standing at a door for nothing.

**A delivery is only "delivered" when the rider says so.** A settled bill means
paid, not arrived. Telling someone their dinner has been delivered while it is
still on a bike is the worst thing this screen could do.

**Delivery and collection are different ladders.** A collection order has no
"on the way" step: to someone standing in the restaurant, "ready" and "ready to
collect" are the same fact, and a step that can never light up makes the rest
look stalled.

## Running it

```bash
flutter pub get
flutter run --dart-define=RMS_ENV=development
```

`RMS_ENV` is `development` | `staging` | `production` (default). The server
address can also be set per build with `--dart-define=RMS_API_BASE=…`, or from
the sign-in screen's **Server settings**.

## Tests

```bash
flutter test
```

37 tests: the basket (pricing, merging, persistence, per-restaurant scoping,
staleness), checkout (call order, resume, no double order, key reuse), the
address fallback driven through a real `ApiClient` over a mocked socket, and
every rung of the tracking ladder for both channels.
