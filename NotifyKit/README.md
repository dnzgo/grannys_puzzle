# NotifyKit

Local reminders for our games ("your treat jar is ready, dear"), with the
rules that keep them welcome built in.

- **Asking at the right moment.** The game asks in its own words first;
  only a yes shows iOS's prompt, which can be shown once per install.
  "Not now" waits two weeks, and after the second one the game stops asking.
- **No nagging.** At most one reminder a day, only between 10:00 and 20:00
  local time (one due outside moves to 10:00 or 19:00 the same day), and
  none after a week away. `ReminderRules` holds the numbers.
- **No repeats.** `line(from:kind:)` rotates each kind's lines with a shuffle
  bag: every line once before any repeats, never twice in a row, remembered
  across launches.
- **A player's switch** (`isEnabled`) separate from iOS's permission.

Local only for now: everything is scheduled on the phone, from the game's
own state, with no server. Push notifications would come as a second target.

## Using it in an app

```swift
// In the App's init, so a tap that launches the app isn't missed:
let tapRelay = ReminderTapRelay()
tapRelay.onTap = { kind in /* analytics: which reminders bring players back */ }

let reminders = Reminders(scheduler: SystemReminderScheduler())

// Re-plan whenever the app becomes active, inactive or backgrounded (and
// right after permission is granted). Not only on background: a player who
// swipes the app away from the app switcher never reaches background.
// While the app is open iOS doesn't show them, and each re-plan replaces
// the last, so the schedule is always fresh.
await reminders.refreshPermission()
if let body = reminders.line(from: jarLines, kind: "jar") {
    await reminders.schedule([
        Reminder(kind: "jar", fireDate: tomorrow, title: "Granny", body: body, priority: 1),
    ])
}

// The soft ask, at a happy moment:
if reminders.canOfferSoftAsk() { /* show your card; yes → */ await reminders.requestPermission() }
                                  /* "not now" → */ reminders.declineSoftAsk()
```

Apple's App Review guidelines don't allow notifications for promotions or
marketing unless players have clearly opted in. Reminders about a player's
own progress (their jar, their streak) are the safe kind.
