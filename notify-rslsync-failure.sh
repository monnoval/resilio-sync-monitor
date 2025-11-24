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

# Wait a moment to see if it's just a restart
sleep 3

# Check if the service is actually down or just restarting
if systemctl --user is-active "$SERVICE_NAME" &> /dev/null; then
    # Service recovered, don't send notification
    echo "[$TIMESTAMP] Service had brief failure but recovered" >> "$LOG_FILE"
    exit 0
fi

# Get failure reason from systemd
FAILURE_REASON=$(systemctl --user status "$SERVICE_NAME" 2>&1 | tail -20)

# Log the failure
echo "[$TIMESTAMP] Resilio Sync failed to start" >> "$LOG_FILE"
echo "$FAILURE_REASON" >> "$LOG_FILE"
echo "----------------------------------------" >> "$LOG_FILE"

# Desktop notification
NOTIFICATION_SENT=false

# KDE Plasma - use kdialog passivepopup (native KDE notification)
if [ -n "$DISPLAY" ] && command -v kdialog &> /dev/null; then
    kdialog --title "Resilio Sync Down" \
            --passivepopup "⚠️ Resilio Sync is not running!\n\nFile synchronization is NOT working!\n\nCheck: journalctl --user -u rslsync.service" 20 2>/dev/null && NOTIFICATION_SENT=true
fi

# Fallback to notify-send (works on most desktops)
if [ "$NOTIFICATION_SENT" = false ] && [ -n "$DISPLAY" ] && command -v notify-send &> /dev/null; then
    notify-send -u critical -a "Resilio Sync Monitor" \
        "Resilio Sync Down" \
        "Resilio Sync is not running!\nCheck logs: journalctl --user -u rslsync.service" && NOTIFICATION_SENT=true
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
                kdialog --title "Resilio Sync Down" \
                        --passivepopup "⚠️ Resilio Sync is not running!" 20 2>/dev/null && NOTIFICATION_SENT=true && break
            fi
        done
    fi
    
    # Try notify-send with DBUS
    if [ "$NOTIFICATION_SENT" = false ] && command -v notify-send &> /dev/null; then
        for session in /run/user/$USER_UID/bus; do
            if [ -S "$session" ]; then
                DBUS_SESSION_BUS_ADDRESS="unix:path=$session" \
                notify-send -u critical -a "Resilio Sync Monitor" \
                    "Resilio Sync Down" \
                    "Resilio Sync is not running!" 2>/dev/null && NOTIFICATION_SENT=true && break
            fi
        done
    fi
fi

# Create a visible flag file
FLAG_FILE="$SCRIPT_DIR/.rslsync-failed"
echo "Resilio Sync failed at $TIMESTAMP" > "$FLAG_FILE"
echo "Check: journalctl --user -u rslsync.service" >> "$FLAG_FILE"

exit 0

