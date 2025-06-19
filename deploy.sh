#!/bin/bash

# Centralized Loki Stack Deployment Script

set -e

echo "🚀 Starting Centralized Loki Stack deployment..."

# Check if Docker and Docker Compose are installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Create directories if they don't exist
mkdir -p grafana/provisioning/datasources
mkdir -p grafana/provisioning/dashboards
mkdir -p promtail-configs

echo "📁 Directory structure verified"

# Check if configuration files exist
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ docker-compose.yml not found!"
    exit 1
fi

if [ ! -f "loki-config.yaml" ]; then
    echo "❌ loki-config.yaml not found!"
    exit 1
fi

echo "📋 Configuration files verified"

# Start the services
echo "🔄 Starting services..."
docker-compose up -d

# Wait for services to be ready
echo "⏳ Waiting for services to start..."
sleep 30

# Check service health
echo "🔍 Checking service health..."

# Check Loki
if curl -f http://localhost:3100/ready > /dev/null 2>&1; then
    echo "✅ Loki is ready"
else
    echo "❌ Loki is not responding"
    docker-compose logs loki
    exit 1
fi

# Check Grafana
if curl -f http://localhost:3000/api/health > /dev/null 2>&1; then
    echo "✅ Grafana is ready"
else
    echo "❌ Grafana is not responding"
    docker-compose logs grafana
    exit 1
fi

echo ""
echo "🎉 Deployment completed successfully!"
echo ""
echo "📊 Access Information:"
echo "   Grafana: http://localhost:3000 (admin/admin)"
echo "   Loki API: http://localhost:3100"
echo ""
echo "📝 Next Steps:"
echo "   1. Change the default Grafana password"
echo "   2. Configure Promtail on remote servers"
echo "   3. Update YOUR_LOKI_SERVER_IP in Promtail configs"
echo ""
echo "🔧 Useful Commands:"
echo "   docker-compose ps          # Check service status"
echo "   docker-compose logs loki   # View Loki logs"
echo "   docker-compose logs grafana # View Grafana logs"
echo "   docker-compose down        # Stop services"
echo ""

# Display current server IP for reference
echo "🌐 Server IP addresses:"
hostname -I | tr ' ' '\n' | grep -E '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$' | head -3
