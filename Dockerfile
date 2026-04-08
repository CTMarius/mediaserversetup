# Use Ubuntu as base image
FROM ubuntu:22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Bucharest
ENV PUID=1000
ENV PGID=1000

# Install dependencies
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    gnupg \
    software-properties-common \
    qbittorrent-nox \
    supervisor \
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

# Install .NET for Prowlarr, Sonarr, Radarr
RUN wget https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb \
    && dpkg -i packages-microsoft-prod.deb \
    && rm packages-microsoft-prod.deb \
    && apt-get update && apt-get install -y dotnet-runtime-6.0 \
    && rm -rf /var/lib/apt/lists/*

# Create user with default UID/GID. Runtime entrypoint will adapt these values if needed.
ARG PUID=1000
ARG PGID=1000
ENV PUID=${PUID}
ENV PGID=${PGID}

RUN groupadd -g $PGID appuser && useradd -u $PUID -g appuser -m appuser

# Create directories
RUN mkdir -p /config/qbittorrent /config/prowlarr /config/sonarr /config/radarr /config/cross-seed /tor /caches

# Install Prowlarr
RUN mkdir -p /opt/prowlarr \
    && cd /opt/prowlarr \
    && wget -O prowlarr.tar.gz $(curl -s https://api.github.com/repos/Prowlarr/Prowlarr/releases/latest | grep "browser_download_url.*linux-core-x64.tar.gz" | cut -d '"' -f 4) \
    && tar -xzf prowlarr.tar.gz --strip-components=1 \
    && rm prowlarr.tar.gz \
    && chown -R appuser:appuser /opt/prowlarr

# Install Sonarr
RUN mkdir -p /opt/sonarr \
    && cd /opt/sonarr \
    && wget -O sonarr.tar.gz $(curl -s https://api.github.com/repos/Sonarr/Sonarr/releases/latest | grep "browser_download_url.*linux-x64.tar.gz" | cut -d '"' -f 4) \
    && tar -xzf sonarr.tar.gz --strip-components=1 \
    && rm sonarr.tar.gz \
    && chown -R appuser:appuser /opt/sonarr

# Install Radarr
RUN mkdir -p /opt/radarr \
    && cd /opt/radarr \
    && wget -O radarr.tar.gz $(curl -s https://api.github.com/repos/Radarr/Radarr/releases/latest | grep "browser_download_url.*linux-x64.tar.gz" | cut -d '"' -f 4) \
    && tar -xzf radarr.tar.gz --strip-components=1 \
    && rm radarr.tar.gz \
    && chown -R appuser:appuser /opt/radarr

# Install cross-seed
RUN npm install -g cross-seed

# Copy supervisord config and entrypoint
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Expose ports
EXPOSE 8080 9696 8989 7878 2468

# Set working directory
WORKDIR /config

# Start supervisord via the runtime entrypoint
CMD ["/usr/local/bin/entrypoint.sh"]