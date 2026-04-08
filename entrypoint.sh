#!/usr/bin/env bash
set -euo pipefail

PUID=${PUID:-1000}
PGID=${PGID:-1000}
TZ=${TZ:-Europe/Bucharest}

# Ensure appuser exists with the configured UID/GID.
if getent group appuser >/dev/null 2>&1; then
  current_gid=$(getent group appuser | cut -d: -f3)
  if [ "$current_gid" != "$PGID" ]; then
    if getent group "$PGID" >/dev/null 2>&1; then
      echo "Warning: GID $PGID already exists, keeping existing group." >&2
    else
      groupmod -g "$PGID" appuser
    fi
  fi
else
  groupadd -g "$PGID" appuser
fi

if id -u appuser >/dev/null 2>&1; then
  current_uid=$(id -u appuser)
  if [ "$current_uid" != "$PUID" ]; then
    usermod -u "$PUID" appuser
  fi
  usermod -g "$PGID" appuser
else
  useradd -u "$PUID" -g "$PGID" -m appuser
fi

# Ensure required directories exist and are writable by appuser.
for dir in /config/qbittorrent /config/qbittorrent/BT_backup /config/prowlarr /config/sonarr /config/radarr /config/cross-seed /tor/downloads /tor/media/tv /tor/media/movies /tor/cross-seed-links /caches /caches/cross-seed; do
  mkdir -p "$dir"
  chown -R "$PUID:$PGID" "$dir"
done

# Set timezone for the container.
if [ -n "$TZ" ] && [ -f "/usr/share/zoneinfo/$TZ" ]; then
  ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime
  echo "$TZ" > /etc/timezone
fi

exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
