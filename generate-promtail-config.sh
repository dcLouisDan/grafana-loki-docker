#!/bin/bash

# Promtail Configuration Generator Script

set -e

echo "🔧 Promtail Configuration Generator"
echo ""

# Function to show usage
show_usage() {
    echo "Usage: $0 <server-name> <loki-server-ip>"
    echo ""
    echo "Example: $0 web-server-01 192.168.1.100"
    echo ""
    exit 1
}

# Check arguments
if [ $# -ne 2 ]; then
    show_usage
fi

SERVER_NAME="$1"
LOKI_SERVER_IP="$2"

# Create configuration directory
mkdir -p promtail-configs

CONFIG_FILE="promtail-configs/promtail-config-${SERVER_NAME}.yml"

echo "📝 Generating Promtail configuration for server: $SERVER_NAME"
echo "🎯 Loki server IP: $LOKI_SERVER_IP"

# Generate the configuration file
cat > "$CONFIG_FILE" << EOF
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://${LOKI_SERVER_IP}:3100/loki/api/v1/push

scrape_configs:
  - job_name: system
    static_configs:
      - targets:
          - localhost
        labels:
          job: varlogs
          __path__: /var/log/*log
          host: ${SERVER_NAME}

  - job_name: syslog
    static_configs:
      - targets:
          - localhost
        labels:
          job: syslog
          __path__: /var/log/syslog
          host: ${SERVER_NAME}

  - job_name: auth
    static_configs:
      - targets:
          - localhost
        labels:
          job: auth
          __path__: /var/log/auth.log
          host: ${SERVER_NAME}

  - job_name: kernel
    static_configs:
      - targets:
          - localhost
        labels:
          job: kernel
          __path__: /var/log/kern.log
          host: ${SERVER_NAME}

  - job_name: docker
    static_configs:
      - targets:
          - localhost
        labels:
          job: docker
          __path__: /var/lib/docker/containers/*/*log
          host: ${SERVER_NAME}

    pipeline_stages:
      - json:
          expressions:
            output: log
            stream: stream
            attrs:
      - json:
          expressions:
            tag: attrs.tag
          source: attrs
      - regex:
          expression: (?P<container_name>(?:[^|]*))?
          source: tag
      - timestamp:
          format: RFC3339Nano
          source: time
      - labels:
          stream:
          container_name:
      - output:
          source: output

  - job_name: nginx
    static_configs:
      - targets:
          - localhost
        labels:
          job: nginx
          __path__: /var/log/nginx/*log
          host: ${SERVER_NAME}

  - job_name: apache
    static_configs:
      - targets:
          - localhost
        labels:
          job: apache
          __path__: /var/log/apache2/*log
          host: ${SERVER_NAME}
EOF

echo "✅ Configuration file created: $CONFIG_FILE"
echo ""
echo "📋 Next steps for $SERVER_NAME:"
echo ""
echo "1. Copy the configuration to your server:"
echo "   scp $CONFIG_FILE user@${SERVER_NAME}:/opt/promtail/config.yml"
echo ""
echo "2. Create required directories on the server:"
echo "   ssh user@${SERVER_NAME} 'sudo mkdir -p /opt/promtail'"
echo ""
echo "3. Deploy Promtail using Docker:"
echo "   ssh user@${SERVER_NAME} 'docker run -d \\"
echo "     --name promtail \\"
echo "     -v /var/log:/var/log:ro \\"
echo "     -v /var/lib/docker/containers:/var/lib/docker/containers:ro \\"
echo "     -v /opt/promtail/config.yml:/etc/promtail/config.yml:ro \\"
echo "     --restart unless-stopped \\"
echo "     grafana/promtail:2.9.0 \\"
echo "     -config.file=/etc/promtail/config.yml'"
echo ""
echo "4. Verify Promtail is running:"
echo "   ssh user@${SERVER_NAME} 'docker logs promtail'"
echo ""

# Generate a deployment script for this specific server
DEPLOY_SCRIPT="promtail-configs/deploy-${SERVER_NAME}.sh"

cat > "$DEPLOY_SCRIPT" << EOF
#!/bin/bash

# Promtail Deployment Script for ${SERVER_NAME}
# Generated on $(date)

set -e

echo "🚀 Deploying Promtail on ${SERVER_NAME}"

# Create configuration directory
sudo mkdir -p /opt/promtail

# Stop existing Promtail if running
echo "🛑 Stopping existing Promtail container..."
docker stop promtail 2>/dev/null || true
docker rm promtail 2>/dev/null || true

# Deploy new Promtail
echo "📦 Starting Promtail container..."
docker run -d \\
  --name promtail \\
  -v /var/log:/var/log:ro \\
  -v /var/lib/docker/containers:/var/lib/docker/containers:ro \\
  -v /opt/promtail/config.yml:/etc/promtail/config.yml:ro \\
  --restart unless-stopped \\
  grafana/promtail:2.9.0 \\
  -config.file=/etc/promtail/config.yml

# Wait a moment for startup
sleep 5

# Check status
echo "🔍 Checking Promtail status..."
if docker ps | grep -q promtail; then
    echo "✅ Promtail is running successfully"
    echo ""
    echo "📊 Container status:"
    docker ps | grep promtail
    echo ""
    echo "📝 Recent logs:"
    docker logs --tail 20 promtail
else
    echo "❌ Promtail failed to start"
    echo "📝 Error logs:"
    docker logs promtail
    exit 1
fi

echo ""
echo "🎉 Promtail deployment completed for ${SERVER_NAME}!"
echo "🔗 Logs are now being sent to Loki at ${LOKI_SERVER_IP}:3100"
EOF

chmod +x "$DEPLOY_SCRIPT"

echo "📋 Also created deployment script: $DEPLOY_SCRIPT"
echo "   This script can be copied to $SERVER_NAME and executed to deploy Promtail"
echo ""
echo "💡 Tip: Run './generate-promtail-config.sh' with different server names to create configs for multiple servers"
