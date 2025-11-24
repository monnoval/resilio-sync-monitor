# Resilio Sync with Monitoring

Resilio Sync with automatic failure detection and KDE notifications - never miss when your files stop syncing.

## 🚀 Quick Start

```bash
# Clone or navigate to your resilio directory
cd /path/to/resilio

# Optional: Customize configuration first
cp config.sh.example config.sh
nano config.sh

# Install
./install.sh

# IMPORTANT: Enable lingering so services run when logged out
sudo loginctl enable-linger $USER
```

Done! You'll now get notifications if Resilio Sync fails.

## ⚙️ Configuration

Copy and edit the config file:
```bash
cp config.sh.example config.sh
nano config.sh
```

Available settings:
- `RESILIO_BASE_DIR` - Installation directory (use `%h` for home, e.g., `%h/path/to/resilio`)
- `HEALTH_CHECK_INTERVAL` - Check frequency (default: `5min`)
- `HEALTH_CHECK_BOOT_DELAY` - Delay after boot (default: `2min`)

The install script reads `config.sh` and generates service files with your settings.

### How It Works:
1. **Templates** (in repo) contain placeholders: `%RESILIO_BASE_DIR%`, `%HEALTH_CHECK_INTERVAL%`
2. **Install script** reads `config.sh` and replaces placeholders with actual values
3. **Generated files** are created in `~/.config/systemd/user/` with real paths

This makes the setup portable - just change paths in one config file!

## 🛡️ Protection Features

- **Auto-restart** - Up to 5 restart attempts on failure (10 second delay)
- **Health checks** - Every 5 minutes, alerts if service is down
- **Desktop notifications** - KDE passive popups when service is down
- **Fast shutdown** - 15 second timeout prevents system hang
- **Multiple notification methods** - kdialog (KDE) + notify-send (fallback)

## 📁 Files

**Configuration**
- `config.sh.example` - Configuration template (tracked in git)
- `config.sh` - Your config (gitignored, created from example)

**Service Templates** (install script generates actual files)
- `rslsync.service` - Main service with auto-restart
- `rslsync-healthcheck.service` - Health check
- `rslsync-healthcheck.timer` - Timer configuration

**Scripts**
- `check-rslsync-health.sh` - Health monitor
- `notify-rslsync-failure.sh` - Alert handler
- `install.sh` - Reads config, generates & installs services

**Generated/Runtime Files** (gitignored)
- `rslsync` - Binary (too large, download separately)
- `config.sh` - Your personal config (copy from config.sh.example)
- `rslsync-failures.log` - Failure history log
- `rslsync-health.log` - Health check log
- `.RSLSYNC-DOWN-WARNING.txt` - Warning flag when service is down
- `.rslsync-failed` - Flag file created on failure

## 📋 Daily Commands

```bash
# Check status
systemctl --user status rslsync.service

# View systemd logs
journalctl --user -u rslsync.service -f

# View monitoring logs (in your repo directory)
cat rslsync-failures.log    # Failure history
cat rslsync-health.log      # Health check history

# Check for active warnings
cat .RSLSYNC-DOWN-WARNING.txt 2>/dev/null

# Restart
systemctl --user restart rslsync.service

# Check when next health check runs
systemctl --user list-timers | grep rslsync

# Manual health check
./check-rslsync-health.sh
```

## 🧪 Test It

```bash
# Stop service (simulates failure)
systemctl --user stop rslsync.service

# Run health check manually
./check-rslsync-health.sh

# You should see a KDE error dialog!

# Restart
systemctl --user start rslsync.service
```

## 🔧 Customize Settings

Edit `config.sh` and re-run the installer:
```bash
nano config.sh

# Example: More frequent checks
# HEALTH_CHECK_INTERVAL="1min"

# Apply changes
./install.sh
```

## 🐛 Troubleshooting

**Services stop when you log out?**
```bash
# Enable lingering (services persist after logout)
sudo loginctl enable-linger $USER

# Verify it's enabled
loginctl show-user $USER | grep Linger
```

**Service won't start?**
```bash
journalctl --user -u rslsync.service -n 50
```

**No notifications?**
```bash
# Install notify-send (optional backup to kdialog)
sudo apt install libnotify-bin

# Test
kdialog --passivepopup "Test" 3
```

**Check if monitoring is active:**
```bash
systemctl --user is-active rslsync.service
systemctl --user is-active rslsync-healthcheck.timer

# Verify lingering is enabled (services persist after logout)
loginctl show-user $USER | grep Linger
```

## 🗑️ Uninstall

```bash
systemctl --user stop rslsync.service rslsync-healthcheck.timer
systemctl --user disable rslsync.service rslsync-healthcheck.timer
rm ~/.config/systemd/user/rslsync*.{service,timer}
systemctl --user daemon-reload
```
