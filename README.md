# db-backuper

Database backup and restore tool supporting PostgreSQL, MariaDB, Valkey/Redis, ClickHouse, and CouchDB with S3-compatible storage and optional AES-256 encryption.

Designed to run as a container job — reads configuration from environment variables, performs one backup or restore operation, then exits.

## Usage

```bash
docker run --rm \
  -e OPERATION=backup \
  -e DATABASE_URL=postgres://user:password@host:5432/mydb \
  -e S3_ENDPOINT=https://minio.example.com \
  -e S3_BUCKET=backups \
  -e S3_KEY=mydb/2026-03-12.dump \
  -e S3_ACCESS_KEY=minioadmin \
  -e S3_SECRET_KEY=minioadmin \
  ghcr.io/eyevinn/db-backuper:latest
```

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `OPERATION` | Yes | `backup` or `restore` |
| `DATABASE_URL` | Yes | Connection URL (see supported schemes below) |
| `S3_ENDPOINT` | Yes | S3-compatible storage endpoint |
| `S3_BUCKET` | Yes | S3 bucket name |
| `S3_KEY` | Yes | S3 object key (path within bucket) |
| `S3_ACCESS_KEY` | Yes | S3 access key |
| `S3_SECRET_KEY` | Yes | S3 secret key |
| `ENCRYPTION_KEY` | No | AES-256-CBC encryption key |

## Supported Database URL Schemes

The `DATABASE_URL` scheme determines which database client tool to use:

| Scheme | Database | Backup Tool | Default Port |
|--------|----------|-------------|-------------|
| `postgres://` or `postgresql://` | PostgreSQL | pg_dump / pg_restore | 5432 |
| `mariadb://` or `mysql://` | MariaDB/MySQL | mysqldump / mysql | 3306 |
| `valkey://` or `redis://` | Valkey/Redis | redis-cli | 6379 |
| `clickhouse://` | ClickHouse | clickhouse-client | 9000 |
| `couchdb://` | CouchDB | HTTP API (curl) | 5984 |

### URL Format

```
scheme://[user:password@]host[:port][/database]
```

Examples:
- `postgres://admin:secret@db.example.com:5432/myapp`
- `mariadb://root:pass@10.0.0.5/orders`
- `valkey://redis.local:6379`
- `clickhouse://default:pass@ch.local:9000/analytics`
- `couchdb://admin:admin@couch.local:5984/documents`

## Encryption

When `ENCRYPTION_KEY` is set, backups are encrypted with AES-256-CBC before uploading to S3, and decrypted after downloading during restore. ClickHouse backups use the native S3 backup engine and do not support client-side encryption.

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Invalid arguments or unsupported database type |
| 2 | Database operation failed (dump/connect) |
| 3 | S3 operation failed (upload/download) |
| 4 | Encryption/decryption failed |
| 5 | Restore operation failed |

## OSC Integration

This project is designed to be used as an [Eyevinn Open Source Cloud](https://www.osaas.io) job service. When imported into the OSC catalog, the platform auto-generates an orchestrator that manages job creation, status tracking, and log retrieval via REST API.

## License

MIT
