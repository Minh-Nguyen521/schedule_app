#!/bin/bash
#
# Rebuilds Schedule and reinstalls it on the iPhone over Wi-Fi, renewing the
# 7-day free-Apple-ID signature before the installed build stops launching.
#
# Designed to be run unattended by launchd every day. When the phone isn't
# reachable, or the current signature still has plenty of life, it does nothing
# and exits 0 — so a quiet failure to find the phone never looks like an error.
#
#   ./resign.sh            reinstall if the signature is running out
#   ./resign.sh --force    reinstall regardless
#   ./resign.sh --check    report status, change nothing
#
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEME="Schedule"
CONFIGURATION="Release"
BUNDLE_ID="com.dedestudio.schedule"
DEVICE_NAME="${SCHEDULE_DEVICE_NAME:-Gỏn}"
# Set SCHEDULE_DEVICE_ID to pin a device by identifier instead, which sidesteps
# any trouble matching a name with non-ASCII characters.
DEVICE_ID="${SCHEDULE_DEVICE_ID:-}"

# Rebuild once the signature has this many days left. Three gives the job
# several daily attempts to catch the phone on Wi-Fi before the app dies.
RENEW_AT_DAYS_LEFT="${SCHEDULE_RENEW_AT_DAYS_LEFT:-3}"

BUILD_DIR="$PROJECT_DIR/build"
DERIVED_DATA="$BUILD_DIR/DerivedData"
APP_PATH="$DERIVED_DATA/Build/Products/$CONFIGURATION-iphoneos/$SCHEME.app"
LOG_FILE="$BUILD_DIR/resign.log"
BUILD_LOG="$BUILD_DIR/last-build.log"

MODE="auto"
case "${1:-}" in
    --force) MODE="force" ;;
    --check) MODE="check" ;;
    "") ;;
    *) echo "usage: $(basename "$0") [--force|--check]" >&2; exit 2 ;;
esac

mkdir -p "$BUILD_DIR"

log() {
    printf '%s  %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG_FILE"
}

# Only used for things worth interrupting the user about: the automation has
# stopped being able to keep the app alive.
notify() {
    local title="$1" message="$2"
    /usr/bin/osascript -e "display notification \"${message//\"/\\\"}\" with title \"${title//\"/\\\"}\"" \
        >/dev/null 2>&1 || true
}

# ---------------------------------------------------------------- device ----

device_identifier() {
    if [ -n "$DEVICE_ID" ]; then
        echo "$DEVICE_ID"
        return
    fi
    xcrun devicectl list devices --json-output - 2>/dev/null \
        | jq -r --arg name "$DEVICE_NAME" '
            .result.devices[]
            | select(.deviceProperties.name == $name)
            | .identifier' \
        | head -1
}

device_is_reachable() {
    local identifier="$1"
    xcrun devicectl device info details --device "$identifier" --timeout 15 >/dev/null 2>&1
}

# ------------------------------------------------------------- signature ----

# Days until the locally built app's provisioning profile expires. The build we
# last installed carries the same profile, so this stands in for the expiry of
# what is actually on the phone.
signature_days_left() {
    local profile="$APP_PATH/embedded.mobileprovision"
    [ -f "$profile" ] || { echo "-1"; return; }

    local expiry
    expiry="$(security cms -D -i "$profile" 2>/dev/null \
        | plutil -extract ExpirationDate raw -o - - 2>/dev/null)" || { echo "-1"; return; }
    [ -n "$expiry" ] || { echo "-1"; return; }

    local expiry_epoch now_epoch
    expiry_epoch="$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$expiry" "+%s" 2>/dev/null)" || { echo "-1"; return; }
    now_epoch="$(date "+%s")"
    echo $(( (expiry_epoch - now_epoch) / 86400 ))
}

# ----------------------------------------------------------------- build ----

build_app() {
    log "Building $SCHEME ($CONFIGURATION)..."
    if ! xcodebuild \
            -project "$PROJECT_DIR/$SCHEME.xcodeproj" \
            -scheme "$SCHEME" \
            -configuration "$CONFIGURATION" \
            -destination 'generic/platform=iOS' \
            -derivedDataPath "$DERIVED_DATA" \
            -allowProvisioningUpdates \
            build > "$BUILD_LOG" 2>&1; then
        log "BUILD FAILED — see $BUILD_LOG"
        # Signing is the failure that needs a human: the Apple ID session has
        # lapsed and only an interactive Xcode sign-in can restore it.
        if grep -qiE "requires a development team|no signing certificate|Your session has expired|no profiles for" "$BUILD_LOG"; then
            log "Cause looks like signing. Open Xcode > Settings > Accounts and sign in again."
            notify "Schedule: signing needs you" "Open Xcode > Settings > Accounts and sign in, then rerun scripts/resign.sh."
        else
            notify "Schedule: build failed" "See build/last-build.log"
        fi
        return 1
    fi
    log "Build OK."
}

install_app() {
    local identifier="$1" days_left="$2"
    log "Installing to '$DEVICE_NAME'..."
    if ! xcrun devicectl device install app --device "$identifier" "$APP_PATH" >> "$BUILD_LOG" 2>&1; then
        # A locked phone cannot mount the developer disk image. That is the
        # normal state of a phone in a pocket, so it is a "come back later",
        # not a failure — the frequent schedule will catch it unlocked soon.
        # "Unable to locate a device" means it dropped off the network between
        # the reachability probe and the install — same situation as a locked
        # phone: wait and try again, don't cry failure.
        if grep -qE "DeviceLocked|unable to locate a device" "$BUILD_LOG"; then
            if grep -q "unable to locate a device" "$BUILD_LOG"; then
                log "Phone went offline mid-install; will retry. ($days_left day(s) of signature left.)"
            else
                log "Phone is locked; will retry. ($days_left day(s) of signature left.)"
            fi
            if [ "$days_left" -ge 0 ] && [ "$days_left" -le 1 ]; then
                notify "Schedule: unlock your phone" "Unlock '$DEVICE_NAME' so the app can be reinstalled before it expires."
            fi
            return 0
        fi
        log "INSTALL FAILED — see $BUILD_LOG"
        notify "Schedule: install failed" "Could not install to $DEVICE_NAME. See build/last-build.log"
        return 1
    fi
    log "Installed. Signature good for $(signature_days_left) more days."
}

# ------------------------------------------------------------------ main ----

main() {
    local identifier days_left
    days_left="$(signature_days_left)"

    # Most runs land here. Staying silent keeps the log to things that matter.
    if [ "$MODE" = "auto" ] && [ "$days_left" -gt "$RENEW_AT_DAYS_LEFT" ]; then
        exit 0
    fi

    identifier="$(device_identifier)"
    if [ -z "$identifier" ]; then
        log "Device '$DEVICE_NAME' is not paired with this Mac. Pair it in Xcode > Window > Devices."
        [ "$MODE" = "check" ] && exit 0
        # Not an error worth a notification on every run: the phone may simply
        # be elsewhere. Only shout once the app is about to die.
        if [ "$days_left" -ge 0 ] && [ "$days_left" -le 1 ]; then
            notify "Schedule expires tomorrow" "Connect '$DEVICE_NAME' to this Wi-Fi so it can be reinstalled."
        fi
        exit 0
    fi

    if [ "$MODE" = "check" ]; then
        log "Device '$DEVICE_NAME' ($identifier)"
        if [ "$days_left" -lt 0 ]; then
            log "No local build yet — run ./resign.sh --force to make one."
        else
            log "Signature has $days_left day(s) left; renews at $RENEW_AT_DAYS_LEFT."
        fi
        device_is_reachable "$identifier" \
            && log "Phone is reachable." \
            || log "Phone is not reachable right now."
        exit 0
    fi

    if ! device_is_reachable "$identifier"; then
        log "Phone not reachable; will try again next run. ($days_left day(s) of signature left.)"
        if [ "$days_left" -ge 0 ] && [ "$days_left" -le 1 ]; then
            notify "Schedule expires tomorrow" "Unlock '$DEVICE_NAME' on this Wi-Fi so it can be reinstalled."
        fi
        exit 0
    fi

    build_app || exit 1
    install_app "$identifier" "$days_left" || exit 1
    log "Done."
}

main
