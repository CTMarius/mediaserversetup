# Media Stack – Single Container Docker Setup

Automated TV/movie downloading & cross-seeding pipeline in a single container.

```
Sonarr/Radarr ──▶ Prowlarr (search) ──▶ qBittorrent (download)
                                              │
                                              ▼
                                    /tor/downloads/
                                              │
                          Sonarr/Radarr ◀─────┘
                          (hardlink to /tor/media/tv  or  /tor/media/movies)
                                              │
                          Cross-seed ◀────────┘
                          (scan & match via Prowlarr → inject into qBittorrent)
```

## Prerequisites

- **Docker Engine** (v20.10+) and **Docker Compose** (v2+) installed on the host
- **mergerfs** installed on the host (see [mergerfs section](#mergerfs-host-level) below)
- A Linux host (Debian/Ubuntu recommended) — hardlinks require all containers to share the same underlying filesystem
- Sufficient disk space on your mergerfs pool for downloads + seeding

### Install Docker (if not already installed)

```bash
# Debian / Ubuntu
sudo apt update
sudo apt install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add your user to the docker group (so you don't need sudo)
sudo usermod -aG docker $USER
newgrp docker
```

### Verify Docker is working

```bash
docker --version          # e.g. Docker version 27.x
docker compose version    # e.g. Docker Compose version v2.x
```

## Quickstart setup for new users

1. Open a terminal and go to this repository folder:

```bash
cd /workspaces/mediaserversetup
```

2. Create the required host directories:

   **Why create these manually?** These directories are mounted as Docker volumes from your host system into the container. Docker does not automatically create directories on the host; they must exist before starting the container to avoid permission issues. The container's entrypoint script creates directories inside the container, but not on the host.

```bash
sudo mkdir -p /srv/mergerfs/rust/tor/{downloads,media/tv,media/movies,cross-seed-links}
sudo mkdir -p /srv/mergerfs/rust/caches/tor/cross-seed
sudo mkdir -p /docker/compose/{qbittorrent,sonarr,radarr,prowlarr,cross-seed}/config
```

3. Set the host ownership so the container user can write files:

```bash
sudo chown -R $(id -u):$(id -g) /srv/mergerfs/rust /docker/compose
```

4. Copy the sample cross-seed config into place:

```bash
cp config.js /docker/compose/cross-seed/config/config.js
```

5. If your host user has a different UID/GID than `1000`, export them before starting:

```bash
export PUID=$(id -u)
export PGID=$(id -g)
```

6. Build and start the container stack:

```bash
docker compose up -d --build
```

### Container Startup Process

The `entrypoint.sh` script is automatically executed when the Docker container starts (defined in the Dockerfile as the CMD). It handles:

- Creating the `appuser` with the specified `PUID`/`PGID`
- Setting up necessary directories inside the container
- Configuring permissions
- Starting supervisord to manage all services (qBittorrent, Prowlarr, Sonarr, Radarr, cross-seed)

You do not need to call `entrypoint.sh` manually.

7. Confirm the service is running:

```bash
docker compose ps
```

8. Open the web interfaces in your browser:
- qBittorrent: `http://localhost:8080`
- Sonarr: `http://localhost:8989`
- Radarr: `http://localhost:7878`
- Prowlarr: `http://localhost:9696`

9. If you change config files later or want to restart the stack, run:

```bash
docker compose restart media-stack
```

10. To stop the service completely:

```bash
docker compose down
```

## What does `docker compose up -d` actually do?

You do **not** manually install qBittorrent, Sonarr, Radarr, Prowlarr, or Cross-seed. Docker builds a custom image with everything:

1. **Reads `docker-compose.yml`** — the file defines 1 service that builds from the local `Dockerfile`
2. **Builds the image** — installs all applications (qBittorrent, Prowlarr, Sonarr, Radarr, Cross-seed) into one Ubuntu-based container
3. **Creates the container** from the built image — an isolated environment with all applications pre-installed and configured
4. **Mounts volumes** — your host directories (`/docker/compose/*/config`, `/srv/mergerfs/rust/tor`, etc.) are mapped into the container so data persists across restarts
5. **Sets up networking** — exposes ports for external access
6. **Starts the service** — supervisord launches all applications within the container

### Environment variables explained

The service uses these environment variables:

| Variable | Value | Purpose |
|---|---|---|
| `PUID` | `1000` | Run the apps as this user ID (should match your host user — check with `id -u`) |
| `PGID` | `1000` | Run the apps as this group ID (check with `id -g`) |
| `TZ` | `Europe/Bucharest` | Timezone for logs and scheduling |

> **Important:** The container startup script adapts the internal app user to the supplied `PUID`/`PGID` and fixes mount ownership at startup.
> If your host user ID is different, keep `PUID`/`PGID` in `docker-compose.yml` aligned with `id -u` / `id -g` on the host.

### What the entrypoint does

The container uses `entrypoint.sh` as its startup script. On each container launch it:

- reads the runtime `PUID` / `PGID` values
- creates or updates the internal `appuser` account to match those IDs
- creates missing config and data directories under `/config`, `/tor`, and `/caches`
- ensures those directories are owned by the configured `appuser`
- applies the timezone from `TZ`
- then starts `supervisord`, which runs qBittorrent, Prowlarr, Sonarr, Radarr, and Cross-seed

This makes the stack easier to run on different hosts without manual UID/GID fiddling.

## Directory layout

| Host path | Container path | Purpose |
|---|---|---|
| `/srv/mergerfs/rust/tor` | `/tor` | Root data dir (downloads, media, links) |
| `/srv/mergerfs/rust/caches/tor` | `/caches` | Cache / temp / cross-seed output |
| `/docker/compose/qbittorrent/config` | `/config/qbittorrent` | qBittorrent persistent config |
| `/docker/compose/prowlarr/config` | `/config/prowlarr` | Prowlarr persistent config |
| `/docker/compose/sonarr/config` | `/config/sonarr` | Sonarr persistent config |
| `/docker/compose/radarr/config` | `/config/radarr` | Radarr persistent config |
| `/docker/compose/cross-seed/config` | `/config/cross-seed` | Cross-seed persistent config |

Create the folder structure on the host before starting:

```bash
mkdir -p /srv/mergerfs/rust/tor/{downloads,media/tv,media/movies,cross-seed-links}
mkdir -p /srv/mergerfs/rust/caches/tor/cross-seed
mkdir -p /docker/compose/{qbittorrent,sonarr,radarr,prowlarr,cross-seed}/config

# Make sure the mounted directories are writable by the host UID/GID used by the container
sudo chown -R $(id -u):$(id -g) /srv/mergerfs/rust /docker/compose
```

## 1. Build and start the stack

```bash
docker compose up -d --build
```

## 2. Configure services (order matters)

### 2a. qBittorrent (`http://<host>:8080`)

1. **Downloads → Default Save Path**: `/tor/downloads`
2. **Downloads → Keep incomplete torrents in**: `/caches/incomplete` (optional)
3. **Downloads → Copy .torrent files to**: leave default or set to `/config/qbittorrent/BT_backup`
4. **BitTorrent → Seeding Limits**: set per your preference
5. Under **Web UI**, change the default password

### 2b. Prowlarr (`http://<host>:9696`)

1. **Settings → Indexers**: add your trackers / indexers
2. **Settings → Apps**: add Sonarr and Radarr as applications (use `localhost` as host, e.g. `http://localhost:8989` for Sonarr)
3. Note your **API Key** (Settings → General) — needed for cross-seed

### 2c. Sonarr (`http://<host>:8989`)

1. **Settings → Media Management**:
   - **Use Hardlinks instead of Copy**: ✅ Enabled
   - **Root Folder**: `/tor/media/tv`
2. **Settings → Download Clients**: add qBittorrent
   - Host: `localhost`, Port: `8080`
   - Category: `tv` (so downloads go to `/tor/downloads/tv`)
   - **Remove Completed**: ❌ Disabled (keep seeding!)
3. **Settings → Indexers**: these should auto-sync from Prowlarr
4. Add a series → Sonarr monitors it, waits for the release date, then searches Prowlarr automatically

### 2d. Radarr (`http://<host>:7878`)

Same pattern as Sonarr but:
- Root Folder: `/tor/media/movies`
- qBittorrent category: `movies`

### 2e. Cross-seed

1. Copy the sample config into the cross-seed config volume:
   ```bash
   cp config.js /docker/compose/cross-seed/config/config.js
   ```
2. Edit `/docker/compose/cross-seed/config/config.js`:
   - Fill in the `torznab` array with your Prowlarr Torznab URLs + API key (e.g., `"http://localhost:9696/1/api?apikey=YOUR_API_KEY"`)
   - Ensure `qbittorrentUrl` is `http://localhost:8080`
   - Ensure `torrentDir` is `/config/qbittorrent/BT_backup`
   - Adjust `matchMode` (`"partial" or "safe"`) as desired
3. Restart: `docker compose restart media-stack`

## 3. The complete flow

1. **You add a series** in Sonarr (or movie in Radarr)
2. Sonarr **monitors** it and waits for the air/release date
3. On release, Sonarr **searches Prowlarr** for matching torrents
4. If a torrent passes quality/size filters, Sonarr **sends it to qBittorrent**
5. qBittorrent **downloads** to `/tor/downloads/tv/<release>/`
6. Sonarr detects the completed download and **hardlinks** the files into `/tor/media/tv/Show Name/Season XX/` — the original files in `/tor/downloads/` stay intact for seeding
7. **Cross-seed daemon** periodically scans `/tor/downloads/`, matches against Prowlarr indexers, and if it finds a 100% or partial hit on another tracker, it **injects** that torrent into qBittorrent pointing at the same data (via hardlinks in `/tor/cross-seed-links/`) so you seed on multiple trackers without duplicating disk space

## mergerfs (host-level)

mergerfs is a union filesystem that runs on the **host**, not inside Docker. Example fstab entry:

```
/mnt/disk1:/mnt/disk2 /srv/mergerfs/rust fuse.mergerfs defaults,allow_other,use_ino,cache.files=partial,dropcacheonclose=true,category.create=mfs,fsname=mergerfs 0 0
```

Install on the host:
```bash
# Debian/Ubuntu
apt install mergerfs
# or download from https://github.com/trapexit/mergerfs/releases
```

## Ports summary

| Service | Port |
|---|---|
| qBittorrent WebUI | 8080 |
| Sonarr | 8989 |
| Radarr | 7878 |
| Prowlarr | 9696 |
| Cross-seed API | 2468 |
