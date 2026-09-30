# Signing, expiry, and the reinstall job

## The constraint

This app is signed with a **free Apple ID (Personal Team)**. Apple gives those
provisioning profiles a **7-day lifetime** — you can see it in the profile
itself:

    TeamName     = Minh Nguyen
    TimeToLive   = 7

When the profile expires, the app stops launching. It does not warn you; it
just bounces back to the Home Screen.

**There is no way to sign once and keep it forever.** Every tier has an expiry:

| Tier | Per-install lifetime | Widget possible? |
|---|---|---|
| Free Apple ID (current) | 7 days | No |
| Apple Developer Program ($99/yr) | 1 year | Yes |
| TestFlight (needs the paid tier) | 90 days | Yes |

What *can* be removed is the manual work. `scripts/resign.sh` rebuilds and
reinstalls over Wi-Fi — no cable — and `scripts/install-launchd.sh` runs it
daily so you never think about it.

## Setting it up

1. **Refresh the signing certificate** (one-time, needs Xcode's UI because of
   two-factor auth):
   Xcode → Settings → Accounts → your Apple ID → Manage Certificates → **+** →
   Apple Development.

2. **Enable wireless installs** (one-time):
   Plug the iPhone in once, then Xcode → Window → Devices and Simulators →
   select the phone → tick **Connect via network**. After this the cable is
   never needed again.

3. **Install the job:**

   ```sh
   ./scripts/install-launchd.sh
   ```

   It runs `resign.sh` every 30 minutes. Override with
   `SCHEDULE_RESIGN_INTERVAL=900 ./scripts/install-launchd.sh`.

## Choosing the device

`resign.sh` targets the device named by `SCHEDULE_DEVICE_NAME` (default: `Gỏn`).
Pin by identifier instead if the name is awkward to match:

```sh
SCHEDULE_DEVICE_ID=927755D2-803F-59D2-ABB2-5DE64B64234F ./scripts/resign.sh
```

**A device running a newer iOS than your Xcode supports can still be installed
to.** Xcode 26.3 cannot *prepare* an iOS 27 device for debugging — that is the
`dyld_shared_cache_extract_dylibs failed` error, and it also needs several GB of
free disk for the extraction — but `devicectl device install app` does not need
any of that and works fine. You lose the debugger, not the app.

## Day to day

```sh
./scripts/resign.sh --check    # how many days are left, is the phone reachable
./scripts/resign.sh            # reinstall if the signature is running out
./scripts/resign.sh --force    # reinstall now regardless
./scripts/install-launchd.sh --status
./scripts/install-launchd.sh --remove
```

The app's own Settings screen shows the same expiry date, read out of its
embedded profile — so you can check from the phone whether the job is keeping
up.

## How the job behaves

- Rebuilds only when the signature has **3 days or fewer** left. With a healthy
  signature the run exits immediately without contacting the phone, which is why
  a half-hourly schedule costs nothing.
- **The phone must be unlocked** for the install — a wireless install mounts a
  developer disk image, and iOS refuses that on a locked device. This is the
  reason for the frequent schedule: it keeps trying until it catches the phone
  unlocked, rather than failing once a day and giving up.
- If the phone isn't reachable or is locked, it logs and exits **0**. A phone in
  your pocket is not a failure, and the next run tries again.
- It only sends you a Mac notification when something actually needs you:
  a failed build, a failed install, or an app that expires tomorrow with the
  phone still out of reach.
- Logs land in `build/resign.log`; the full xcodebuild output in
  `build/last-build.log`.

## Your data survives reinstalls

Installing over the existing app with the **same bundle id and same team**
is an upgrade, not a fresh install — the data container is kept, so your tick
history carries across. It would only be lost if the bundle id or the signing
team changed, or the app were deleted from the phone.

`Settings → Export backup` writes a JSON file with every habit and tick, which
is worth doing before any signing change.

## The one thing that can still stop it

Free-tier automatic signing depends on a valid Apple ID session in Xcode. That
session lapses occasionally and can only be restored interactively (two-factor
auth). When that happens the build fails with a signing error, `resign.sh`
recognises it and sends a Mac notification telling you to sign in again. It
cannot fix that one by itself.

## If you ever go paid

Joining the Developer Program ($99/yr) changes three things:

1. Profiles last a year, so the job becomes a yearly reinstall rather than a
   weekly one.
2. The App Groups capability becomes available, which is what the Home Screen
   widget needs to read the app's database. The widget target is scaffolded and
   commented out in `project.yml`.
3. You could push builds through TestFlight instead, installing from the phone
   itself with no Mac involved at all.

Only `DEVELOPMENT_TEAM` in `project.yml` needs to change.
