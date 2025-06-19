# Centralized Loki Logging Stack

This Docker Compose setup provides a centralized logging solution using Grafana Loki and Grafana, designed to receive logs from multiple Promtail instances deployed across different servers.

## Architecture

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Server 1  │    │   Server 2  │    │   Server N  │
│             │    │             │    │             │
│  Promtail   │    │  Promtail   │    │  Promtail   │
│     │       │    │     │       │    │     │       │
└─────┼───────┘    └─────┼───────┘    └─────┼───────┘
      │                  │                  │
      │                  │                  │
      └──────────────────┼──────────────────┘
                         │
                         ▼
              ┌─────────────────────┐
              │   Central Server    │
              │                     │
              │  ┌─────────────┐    │
              │  │    Loki     │    │
              │  │   :3100     │    │
              │  └─────────────┘    │
              │  ┌─────────────┐    │
              │  │   Grafana   │    │
              │  │   :3000     │    │
              │  └─────────────┘    │
              └─────────────────────┘
```

## Components

- **Loki**: Log aggregation system that stores and indexes logs
- **Grafana**: Web UI for querying and visualizing logs
- **Promtail**: Log collector (deployed on remote servers)

## Quick Start

### 1. Deploy the Central Loki Server

1. Clone this repository to your central server:
   ```bash
   git clone <repository-url>
   cd test-loki
   ```

2. Start the services:
   ```bash
   docker-compose up -d
   ```

3. Verify the services are running:
   ```bash
   docker-compose ps
   ```

4. Access Grafana at `http://your-server-ip:3000`
   - Username: `admin`
   - Password: `admin`

### 2. Configure Remote Promtail Instances

For each remote server where you want to collect logs:

1. Install Docker on the remote server

2. Copy the appropriate Promtail configuration:
   ```bash
   # Copy promtail-config-server1.yml to your remote server
   scp promtail-configs/promtail-config-server1.yml user@remote-server:/opt/promtail/
   ```

3. Edit the configuration file on the remote server:
   ```bash
   # Replace YOUR_LOKI_SERVER_IP with the actual IP of your central Loki server
   sed -i 's/YOUR_LOKI_SERVER_IP/192.168.1.100/g' /opt/promtail/promtail-config-server1.yml
   ```

4. Run Promtail on the remote server:
   ```bash
   docker run -d \
     --name promtail \
     -v /var/log:/var/log:ro \
     -v /var/lib/docker/containers:/var/lib/docker/containers:ro \
     -v /opt/promtail/promtail-config-server1.yml:/etc/promtail/config.yml:ro \
     --restart unless-stopped \
     grafana/promtail:2.9.0 \
     -config.file=/etc/promtail/config.yml
   ```

## Configuration Details

### Loki Configuration

The Loki configuration (`loki-config.yaml`) includes:
- **Storage**: Local filesystem storage with BoltDB indexer
- **Retention**: Configurable log retention (currently disabled)
- **Limits**: Query and ingestion limits for performance
- **Compaction**: Automatic log compaction for storage efficiency

### Grafana Configuration

- **Data Source**: Automatically provisioned Loki data source
- **Default Credentials**: admin/admin (change in production)
- **Persistent Storage**: Grafana data is stored in Docker volumes

### Promtail Configuration

Each Promtail instance collects:
- System logs (`/var/log/*log`)
- Syslog (`/var/log/syslog`)
- Docker container logs (`/var/lib/docker/containers/*/*log`)

## Network Requirements

### Ports

- **Loki**: 3100 (must be accessible from Promtail instances)
- **Grafana**: 3000 (web interface)

### Firewall Rules

Ensure the following ports are open on your central server:
```bash
# Allow Loki ingestion (from Promtail instances)
sudo ufw allow 3100/tcp

# Allow Grafana web interface
sudo ufw allow 3000/tcp
```

## Production Considerations

### Security

1. **Change default passwords**:
   ```bash
   # Edit docker-compose.yml and change:
   - GF_SECURITY_ADMIN_PASSWORD=your-secure-password
   ```

2. **Use HTTPS**: Configure a reverse proxy (nginx/traefik) with SSL certificates

3. **Network security**: Use VPN or private networks for Promtail-to-Loki communication

4. **Authentication**: Enable Grafana LDAP/OAuth integration

### Performance Tuning

1. **Resource limits**: Add resource constraints to Docker services
2. **Storage**: Use dedicated volumes or external storage for production
3. **Retention**: Configure appropriate log retention policies
4. **Monitoring**: Monitor Loki and Grafana resource usage

### Scaling

For high-volume environments:
- Use Loki in clustered mode
- Implement load balancing
- Use object storage (S3, GCS) instead of filesystem
- Consider Loki's microservices mode

## Troubleshooting

### Common Issues

1. **Promtail can't connect to Loki**:
   - Check network connectivity: `telnet loki-server-ip 3100`
   - Verify firewall rules
   - Check Promtail logs: `docker logs promtail`

2. **No logs appearing in Grafana**:
   - Verify Promtail is running: `docker ps`
   - Check Loki logs: `docker-compose logs loki`
   - Verify log paths in Promtail config

3. **Grafana can't connect to Loki**:
   - Check service health: `docker-compose ps`
   - Verify internal Docker network connectivity

### Useful Commands

```bash
# View service logs
docker-compose logs loki
docker-compose logs grafana

# Check service status
docker-compose ps

# Restart services
docker-compose restart

# View Promtail logs on remote server
docker logs promtail

# Test Loki API
curl http://localhost:3100/ready
```

## Log Queries

### Example LogQL Queries

```logql
# All logs from a specific host
{host="server1"}

# Docker logs from all hosts
{job="docker"}

# Error logs from syslog
{job="syslog"} |= "error"

# Logs from specific container
{job="docker", container_name="nginx"}

# Rate of log entries per minute
rate({job="syslog"}[1m])
```

## Backup and Recovery

### Backup

```bash
# Backup Loki data
docker run --rm -v test-loki_loki-data:/data -v $(pwd):/backup alpine tar czf /backup/loki-backup.tar.gz -C /data .

# Backup Grafana data
docker run --rm -v test-loki_grafana-data:/data -v $(pwd):/backup alpine tar czf /backup/grafana-backup.tar.gz -C /data .
```

### Recovery

```bash
# Restore Loki data
docker run --rm -v test-loki_loki-data:/data -v $(pwd):/backup alpine tar xzf /backup/loki-backup.tar.gz -C /data

# Restore Grafana data
docker run --rm -v test-loki_grafana-data:/data -v $(pwd):/backup alpine tar xzf /backup/grafana-backup.tar.gz -C /data
```

## Support

For issues and questions:
- [Grafana Loki Documentation](https://grafana.com/docs/loki/)
- [Grafana Documentation](https://grafana.com/docs/grafana/)
- [Promtail Documentation](https://grafana.com/docs/loki/latest/clients/promtail/)
