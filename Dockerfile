FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    jq \
    openssl \
    ca-certificates \
    gzip \
    gnupg \
    lsb-release \
    && rm -rf /var/lib/apt/lists/*

# PostgreSQL client (pg_dump, pg_restore)
RUN apt-get update && apt-get install -y --no-install-recommends \
    postgresql-client-15 \
    && rm -rf /var/lib/apt/lists/*

# MariaDB client (mysqldump, mysql)
RUN apt-get update && apt-get install -y --no-install-recommends \
    mariadb-client \
    && rm -rf /var/lib/apt/lists/*

# Valkey/Redis CLI
RUN apt-get update && apt-get install -y --no-install-recommends \
    redis-tools \
    && rm -rf /var/lib/apt/lists/*

# ClickHouse client (via official apt repo)
RUN curl -fsSL https://packages.clickhouse.com/rpm/lts/repodata/repomd.xml > /dev/null 2>&1 || true && \
    apt-get update && apt-get install -y --no-install-recommends apt-transport-https && \
    curl -fsSL 'https://packages.clickhouse.com/rpm/lts/repodata/repomd.xml' > /dev/null 2>&1 || true && \
    mkdir -p /usr/share/keyrings && \
    curl -fsSL https://packages.clickhouse.com/keys/GPG-KEY-CLICKHOUSE.gpg | gpg --dearmor -o /usr/share/keyrings/clickhouse-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/clickhouse-keyring.gpg] https://packages.clickhouse.com/deb stable main" > /etc/apt/sources.list.d/clickhouse.list && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends clickhouse-client clickhouse-common-static && \
    rm -rf /var/lib/apt/lists/*

# Minio client (mc) for S3 operations
RUN curl -fsSL https://dl.min.io/client/mc/release/linux-amd64/mc \
    -o /usr/local/bin/mc && chmod +x /usr/local/bin/mc

COPY scripts/ /opt/backup/
RUN chmod +x /opt/backup/*.sh

ENTRYPOINT ["/opt/backup/entrypoint.sh"]
