#!/bin/bash
#
# Resilio Sync Health Check Script
# Run this periodically via cron or systemd timer to monitor rslsync
#

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
HOSTNAME=$(hostname)

# Base directory (where this script is located)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

LOG_FILE="$SCRIPT_DIR/rslsync-health.log"

# Check if service is active
if ! systemctl --user is-active --quiet rslsync.service; then
    echo "[$TIMESTAMP] ERROR: rslsync.service is not active" >> "$LOG_FILE"
    
    # Send notification
    NOTIFIED=false
    
    # KDE Plasma - use kdialog
    if [ -n "$DISPLAY" ] && command -v kdialog &> /dev/null; then
        kdialog --title "Resilio Sync Down" \
                --error "🚨 Resilio Sync is NOT running!

Your files are NOT syncing.

Action: systemctl --user start rslsync.service" 2>/dev/null && NOTIFIED=true
    fi
    
    # Fallback to notify-send
    if [ "$NOTIFIED" = false ] && [ -n "$DISPLAY" ] && command -v notify-send &> /dev/null; then
        notify-send -u critical \
            "🚨 Resilio Sync Down" \
            "Resilio Sync is not running! Your files are NOT syncing.\n\nAction: Restart with: systemctl --user start rslsync.service" && NOTIFIED=true
    fi
    
    # Try to find DBUS session for notification
    if [ "$NOTIFIED" = false ]; then
        USER_UID=$(id -u)
        
        # Try kdialog with DBUS
        if command -v kdialog &> /dev/null; then
            for session in /run/user/$USER_UID/bus; do
                if [ -S "$session" ]; then
                    DBUS_SESSION_BUS_ADDRESS="unix:path=$session" \
                    kdialog --title "Resilio Sync Down" \
                            --error "🚨 Resilio Sync is NOT running!" 2>/dev/null && NOTIFIED=true && break
                fi
            done
        fi
        
        # Try notify-send with DBUS
        if [ "$NOTIFIED" = false ] && command -v notify-send &> /dev/null; then
            for session in /run/user/$USER_UID/bus; do
                if [ -S "$session" ]; then
                    DBUS_SESSION_BUS_ADDRESS="unix:path=$session" \
                    notify-send -u critical \
                        "🚨 Resilio Sync Down" \
                        "Resilio Sync is not running!" 2>/dev/null && NOTIFIED=true && break
                fi
            done
        fi
    fi
    
    # Create warning flag
    echo "⚠️  RESILIO SYNC IS NOT RUNNING ⚠️
Last checked: $TIMESTAMP
Your files are NOT syncing!

To restart:
systemctl --user start rslsync.service

To check status:
systemctl --user status rslsync.service
journalctl --user -u rslsync.service -n 20
" > "$SCRIPT_DIR/.RSLSYNC-DOWN-WARNING.txt"
    
    exit 1
fi

# Check if process is actually running
if ! pgrep -f "rslsync" > /dev/null; then
    echo "[$TIMESTAMP] WARNING: Service active but no rslsync process found" >> "$LOG_FILE"
    
    # KDE Plasma notification
    if [ -n "$DISPLAY" ] && command -v kdialog &> /dev/null; then
        kdialog --title "Resilio Sync Issue" \
                --sorry "⚠️ Service is active but process not found. Restarting..." 2>/dev/null
    elif [ -n "$DISPLAY" ] && command -v notify-send &> /dev/null; then
        notify-send -u critical \
            "⚠️ Resilio Sync Issue" \
            "Service is active but process not found. Restarting..."
    fi
    
    # Try to restart
    systemctl --user restart rslsync.service
    exit 1
fi

# All checks passed - service is healthy
# Remove warning flags if they exist
[ -f "$SCRIPT_DIR/.RSLSYNC-DOWN-WARNING.txt" ] && rm -f "$SCRIPT_DIR/.RSLSYNC-DOWN-WARNING.txt"
[ -f "$SCRIPT_DIR/.rslsync-failed" ] && rm -f "$SCRIPT_DIR/.rslsync-failed"

# Log success (optional - comment out if you don't want verbose logging)
# echo "[$TIMESTAMP] OK: rslsync is running" >> "$LOG_FILE"

exit 0

