#!/bin/bash
#
# Resilio Sync Failure Notification Script
# This script is called when rslsync.service fails
#

SERVICE_NAME="${1:-rslsync.service}"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
HOSTNAME=$(hostname)

# Base directory (where this script is located)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Log file for tracking failures
LOG_FILE="$SCRIPT_DIR/rslsync-failures.log"

# Get failure reason from systemd
FAILURE_REASON=$(systemctl --user status "$SERVICE_NAME" 2>&1 | tail -20)

# Log the failure
echo "[$TIMESTAMP] Resilio Sync failed to start" >> "$LOG_FILE"
echo "$FAILURE_REASON" >> "$LOG_FILE"
echo "----------------------------------------" >> "$LOG_FILE"

# Desktop notification
NOTIFICATION_SENT=false

# KDE Plasma - use kdialog (native KDE notification)
if [ -n "$DISPLAY" ] && command -v kdialog &> /dev/null; then
    kdialog --title "Resilio Sync Failed" \
            --error "⚠️ Resilio Sync failed to start at $TIMESTAMP

File synchronization is NOT working!

Check logs with:
journalctl --user -u rslsync.service" 2>/dev/null && NOTIFICATION_SENT=true
fi

# Fallback to notify-send (works on most desktops)
if [ "$NOTIFICATION_SENT" = false ] && [ -n "$DISPLAY" ] && command -v notify-send &> /dev/null; then
    notify-send -u critical \
        "⚠️ Resilio Sync Failed" \
        "Resilio Sync failed to start at $TIMESTAMP\nCheck logs: journalctl --user -u rslsync.service" && NOTIFICATION_SENT=true
fi

# Try to find the DBUS session for notification (even if not in active session)
# This is useful for boot-time failures
if [ "$NOTIFICATION_SENT" = false ]; then
    # Get the user's UID
    USER_UID=$(id -u)
    
    # Try kdialog with DBUS
    if command -v kdialog &> /dev/null; then
        for session in /run/user/$USER_UID/bus; do
            if [ -S "$session" ]; then
                DBUS_SESSION_BUS_ADDRESS="unix:path=$session" \
                kdialog --title "Resilio Sync Failed" \
                        --error "⚠️ Resilio Sync failed to start at $TIMESTAMP" 2>/dev/null && NOTIFICATION_SENT=true && break
            fi
        done
    fi
    
    # Try notify-send with DBUS
    if [ "$NOTIFICATION_SENT" = false ] && command -v notify-send &> /dev/null; then
        for session in /run/user/$USER_UID/bus; do
            if [ -S "$session" ]; then
                DBUS_SESSION_BUS_ADDRESS="unix:path=$session" \
                notify-send -u critical \
                    "⚠️ Resilio Sync Failed" \
                    "Resilio Sync failed to start at $TIMESTAMP" 2>/dev/null && NOTIFICATION_SENT=true && break
            fi
        done
    fi
fi

# Create a visible flag file
FLAG_FILE="$SCRIPT_DIR/.rslsync-failed"
echo "Resilio Sync failed at $TIMESTAMP" > "$FLAG_FILE"
echo "Check: journalctl --user -u rslsync.service" >> "$FLAG_FILE"

exit 0

