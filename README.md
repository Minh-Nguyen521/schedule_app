# Schedule

A habit tick-off app for iPhone. One screen of things to do today, one tap per
thing, and a month calendar per habit showing what you actually did.

Built for personal use on a free Apple ID, which means the installed build is
signed for only 7 days — see **[docs/SIGNING.md](docs/SIGNING.md)** for how the
reinstall job keeps it alive without a cable.

## Getting started

```sh
brew install xcodegen          # once
xcodegen generate              # regenerate Schedule.xcodeproj after editing project.yml
open Schedule.xcodeproj
```

`Schedule.xcodeproj` is generated from `project.yml` and is not the source of
truth — edit `project.yml` and regenerate.

Run the tests:

```sh
xcodebuild -project Schedule.xcodeproj -scheme Schedule \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

To see populated screens in the simulator, launch with `-seedSampleData`
(DEBUG builds only).

## Putting it on the phone

```sh
./scripts/resign.sh --check     # status: days of signature left, phone reachable?
./scripts/resign.sh --force     # build and install now
./scripts/install-launchd.sh    # then let it maintain itself
```

The phone must be **unlocked** for a wireless install.

## Layout

```
project.yml                     project definition (XcodeGen)
Sources/Schedule/
  ScheduleApp.swift             entry point, root navigation, reminder refresh
  Models/
    DayKey.swift                timezone-safe calendar-day identity
    Habit.swift                 Habit + CheckIn (SwiftData)
    StreakEngine.swift          streak and completion maths (pure, tested)
    MonthGrid.swift             calendar layout maths (pure, tested)
  Views/
    TodayView.swift             the main screen
    HabitDetailView.swift       month calendar and stats
    HabitEditView.swift         create/edit
    SettingsView.swift          notifications, signature expiry, backup
    AppTheme.swift              light/dark preference
    WeekStrip.swift             the week selector
    HabitRow.swift              one habit on one day
    Theme.swift                 colours, emoji palette, weekday formatting
  Services/
    HabitStore.swift            every mutation, in one place
    NotificationService.swift   local daily reminders
    BuildExpiry.swift           reads the embedded profile's expiry date
    ExportService.swift         JSON backup
    Haptics.swift
    SampleData.swift            DEBUG fixtures
Tests/ScheduleTests/            28 tests over the date and streak logic
scripts/
  resign.sh                     rebuild + reinstall over Wi-Fi
  install-launchd.sh            the job that runs it
docs/SIGNING.md                 expiry, setup, and what can still go wrong
```

## Design notes

**Days are integers, not dates.** A tick is stored as `20260930`, not a
`Date`. Storing an instant means a habit done at 11pm shows on the wrong day
after a flight or a DST change; a `yyyyMMdd` key has no time component to
drift. All the arithmetic still goes through `Calendar`, so month, year, and
DST boundaries behave.

**A habit's schedule decides what counts as a miss.** A Mon–Fri habit skips
the weekend rather than breaking its streak, and a tick on an unscheduled day
is credited as a bonus without entering the streak maths.

**Any past day can be ticked.** The month calendar lets you fill in days you
forgot, including days before you created the habit — adding "Gym" today and
recording that you also went on Monday is normal use. Backfilling past the
habit's start date moves that date back, so the completion percentage measures
the range you actually tracked instead of writing those days off as bonuses.
Only the future is off limits.

**Today gets grace.** An unticked habit does not break your streak until the
day is over — otherwise every streak reads as broken each morning.

**Dark mode is built in.** Every colour is either semantic (`.primary`,
`.secondary`) or a habit tint that reads on both backgrounds, so the app follows
iOS automatically. Settings → Appearance can also pin it to Light or Dark
regardless of the system setting; sheets apply the preference explicitly, since
they get their own environment and don't inherit it reliably.

**The streak and calendar maths live outside the views** (`StreakEngine`,
`MonthGrid`) so they can be tested directly instead of eyeballed.

## Known limits

- **No Home Screen widget.** A widget needs an App Group to read the app's
  database, and Xcode does not allow App Groups on a free Personal Team. The
  target is scaffolded and commented out in `project.yml`; it needs the $99/yr
  Developer Program.
- **Emoji render as empty boxes in the simulator** on some runtimes that ship
  without the emoji font. They are fine on a real device.
- Reminders stop arriving once the signature expires, since the app can no
  longer launch.
