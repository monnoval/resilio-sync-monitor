#!/bin/bash
#
# Install Resilio Sync systemd services
# Run this script to set up and configure the services
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load configuration
if [ -f "$SCRIPT_DIR/config.sh" ]; then
    source "$SCRIPT_DIR/config.sh"
    echo "✓ Loaded configuration from config.sh"
else
    echo "⚠️  No config.sh found, using defaults"
    RESILIO_BASE_DIR="%h/Apps/resilio"
    HEALTH_CHECK_INTERVAL="5min"
    HEALTH_CHECK_BOOT_DELAY="2min"
fi

# Systemd user directory (respects XDG_CONFIG_HOME)
SYSTEMD_USER_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"

echo ""
echo "Installing Resilio Sync systemd services..."
echo "  Base directory: $RESILIO_BASE_DIR"
echo "  Health check interval: $HEALTH_CHECK_INTERVAL"
echo ""

# Create systemd user directory if it doesn't exist
mkdir -p "$SYSTEMD_USER_DIR"

# Remove old symlinks/files if they exist
echo "Cleaning up old service files..."
rm -f "$SYSTEMD_USER_DIR/rslsync.service"
rm -f "$SYSTEMD_USER_DIR/rslsync-failure-notify@.service"
rm -f "$SYSTEMD_USER_DIR/rslsync-healthcheck.service"
rm -f "$SYSTEMD_USER_DIR/rslsync-healthcheck.timer"

# Generate service files with configured paths
echo "Generating service files from templates..."

# rslsync.service
sed "s|%RESILIO_BASE_DIR%|$RESILIO_BASE_DIR|g" "$SCRIPT_DIR/rslsync.service" > "$SYSTEMD_USER_DIR/rslsync.service"

# rslsync-failure-notify@.service  
sed "s|%RESILIO_BASE_DIR%|$RESILIO_BASE_DIR|g" "$SCRIPT_DIR/rslsync-failure-notify@.service" > "$SYSTEMD_USER_DIR/rslsync-failure-notify@.service"

# rslsync-healthcheck.service
sed "s|%RESILIO_BASE_DIR%|$RESILIO_BASE_DIR|g" "$SCRIPT_DIR/rslsync-healthcheck.service" > "$SYSTEMD_USER_DIR/rslsync-healthcheck.service"

# rslsync-healthcheck.timer
sed -e "s|%HEALTH_CHECK_INTERVAL%|$HEALTH_CHECK_INTERVAL|g" \
    -e "s|%HEALTH_CHECK_BOOT_DELAY%|$HEALTH_CHECK_BOOT_DELAY|g" \
    "$SCRIPT_DIR/rslsync-healthcheck.timer" > "$SYSTEMD_USER_DIR/rslsync-healthcheck.timer"

echo "✓ Service files generated"
echo ""

# Make scripts executable
echo "Making scripts executable..."
chmod +x "$SCRIPT_DIR/check-rslsync-health.sh"
chmod +x "$SCRIPT_DIR/notify-rslsync-failure.sh"
echo "✓ Scripts are executable"
echo ""

# Reload systemd
echo "Reloading systemd..."
systemctl --user daemon-reload
echo "✓ Systemd reloaded"
echo ""

# Enable and start services
echo "Enabling services..."
systemctl --user enable rslsync.service
systemctl --user enable rslsync-healthcheck.timer
echo "✓ Services enabled"
echo ""

# Start services
echo "Starting services..."
systemctl --user start rslsync.service
systemctl --user start rslsync-healthcheck.timer
echo "✓ Services started"
echo ""

# Show status
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Installation complete! Status:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
systemctl --user status rslsync.service --no-pager | head -10
echo ""
systemctl --user list-timers rslsync-healthcheck.timer --no-pager
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Installation complete!"
echo ""
echo "Your Resilio Sync is now monitored with:"
echo "  • Automatic restart on failure"
echo "  • Instant failure notifications"
echo "  • Health checks every $HEALTH_CHECK_INTERVAL"
echo ""

# Check for lingering
LINGER_STATUS=$(loginctl show-user $USER 2>/dev/null | grep "Linger=" | cut -d= -f2)
if [ "$LINGER_STATUS" != "yes" ]; then
    echo "⚠️  IMPORTANT: User lingering is NOT enabled!"
    echo "   Your services will STOP when you log out."
    echo ""
    echo "   To keep sync running when logged out, run:"
    echo "   sudo loginctl enable-linger $USER"
    echo ""
    echo "   Or run: $SCRIPT_DIR/enable-monitoring.sh"
    echo ""
fi

echo "Configuration: $SCRIPT_DIR/config.sh"
echo "Documentation: $SCRIPT_DIR/README.md"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
