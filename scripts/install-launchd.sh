#!/bin/bash
#
# Installs (or removes) the launchd job that keeps Schedule alive on the phone.
#
# The job runs resign.sh every 30 minutes. That sounds aggressive, but a run
# with a healthy signature exits immediately without touching the phone — the
# frequency exists because a wireless install needs the phone both on Wi-Fi and
# *unlocked*, and half-hourly attempts reliably catch such a moment during the
# three days before the signature runs out.
#
#   ./install-launchd.sh            install and start
#   ./install-launchd.sh --remove   stop and remove
#   ./install-launchd.sh --status   show whether it is loaded
#
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LABEL="com.dedestudio.schedule.resign"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
INTERVAL_SECONDS="${SCHEDULE_RESIGN_INTERVAL:-1800}"

case "${1:-}" in
    --remove)
        launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
        rm -f "$PLIST"
        echo "Removed $LABEL."
        exit 0
        ;;
    --status)
        if launchctl print "gui/$(id -u)/$LABEL" >/dev/null 2>&1; then
            echo "$LABEL is loaded."
            launchctl print "gui/$(id -u)/$LABEL" | grep -E "state|last exit code|runs" || true
        else
            echo "$LABEL is not loaded."
        fi
        exit 0
        ;;
    "") ;;
    *) echo "usage: $(basename "$0") [--remove|--status]" >&2; exit 2 ;;
esac

mkdir -p "$HOME/Library/LaunchAgents" "$PROJECT_DIR/build"

cat > "$PLIST" <<PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$PROJECT_DIR/scripts/resign.sh</string>
    </array>
    <key>StartInterval</key>
    <integer>$INTERVAL_SECONDS</integer>
    <key>WorkingDirectory</key>
    <string>$PROJECT_DIR</string>
    <key>StandardOutPath</key>
    <string>$PROJECT_DIR/build/launchd.out.log</string>
    <key>StandardErrorPath</key>
    <string>$PROJECT_DIR/build/launchd.err.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin</string>
    </dict>
    <!-- Catch up straight away when the Mac wakes or you log in. -->
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
PLIST_EOF

# bootout first so re-running this script reloads a changed plist rather than
# silently keeping the old schedule.
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"

echo "Installed $LABEL — runs every $((INTERVAL_SECONDS / 60)) minutes."
echo "Logs: $PROJECT_DIR/build/resign.log"
echo
echo "Check it any time with:  ./scripts/resign.sh --check"
