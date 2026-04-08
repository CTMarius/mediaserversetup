// cross-seed configuration – /config/config.js inside the container
// Docs: https://www.cross-seed.org/docs/basics/options

module.exports = {
  // ── qBittorrent connection ────────────────────
  qbittorrentUrl: "http://qbittorrent:8080",

  // ── Torznab feeds (Prowlarr indexers) ─────────
  // After adding indexers in Prowlarr, grab the Torznab URLs
  // Format: http://prowlarr:9696/1/api?apikey=YOUR_PROWLARR_API_KEY
  torznab: [
    // "http://prowlarr:9696/1/api?apikey=PROWLARR_API_KEY",
    // "http://prowlarr:9696/2/api?apikey=PROWLARR_API_KEY",
  ],

  // ── Paths ─────────────────────────────────────
  // Where qBittorrent saves completed downloads
  dataDirs: ["/tor/downloads"],

  // Where cross-seed puts .torrent files for injection
  outputDir: "/caches/cross-seed",

  // Folder where qBittorrent stores .torrent files (fastresume)
  torrentDir: "/config/qBittorrent/BT_backup",

  // ── Matching behaviour ────────────────────────
  // "partial" allows data-based partial matching in addition to
  // risky=false full matches; set to "safe" for 100%-only matches
  matchMode: "partial",

  // Skip recheck – qBittorrent will verify pieces itself
  skipRecheck: false,

  // ── Linking ───────────────────────────────────
  // Use hardlinks so the same data serves both torrents
  linkType: "hardlink",
  linkDir: "/tor/cross-seed-links",

  // ── Timing ────────────────────────────────────
  // How often (ms) the daemon rescans for new downloads
  searchCadence: "1d",

  // Delay between API calls to avoid hammering indexers
  delay: 30,

  // ── Daemon / API ──────────────────────────────
  port: 2468,

  // ── Actions ───────────────────────────────────
  action: "inject",   // inject matched torrents straight into qBittorrent
};
