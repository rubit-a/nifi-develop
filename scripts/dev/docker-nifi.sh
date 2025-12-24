#!/bin/bash
set -e

# 스크립트 디렉토리 경로
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Docker Compose 명령어 감지 (v1: docker-compose, v2: docker compose)
if command -v docker-compose &> /dev/null; then
  DOCKER_COMPOSE="docker-compose -f ${SCRIPT_DIR}/docker-compose.yml"
elif docker compose version &> /dev/null; then
  DOCKER_COMPOSE="docker compose -f ${SCRIPT_DIR}/docker-compose.yml"
else
  echo "Error: Docker Compose is not installed"
  echo ""
  echo "Please install Docker Desktop:"
  echo "  macOS: https://www.docker.com/products/docker-desktop/"
  echo "  Windows: https://www.docker.com/products/docker-desktop/"
  echo "  Linux: https://docs.docker.com/compose/install/"
  exit 1
fi

COMMAND=${1:-help}

case $COMMAND in
  start)
    echo "========================================="
    echo " Starting NiFi Docker Container"
    echo "========================================="
    echo ""

    # NAR 빌드 여부 확인
    if [ ! -f "${SCRIPT_DIR}/../../nifi-kiba-nar/target/nifi-kiba-nar-1.0.0.nar" ]; then
      echo "⚠️  NAR file not found. Building first..."
      "${SCRIPT_DIR}/build-nar.sh"
    fi

    echo "Starting Docker containers..."
    $DOCKER_COMPOSE up -d

    echo ""
    echo "========================================="
    echo " NiFi is starting..."
    echo "========================================="
    echo ""
    echo "Web UI will be available at:"
    echo "  https://localhost:8443/nifi"
    echo ""
    echo "Credentials:"
    echo "  Username: admin"
    echo "  Password: ctsBtRBKHRAx69EqUghvvgEvjnaLjFEB"
    echo ""
    echo "⏳ NiFi may take 1-2 minutes to fully start."
    echo ""
    echo "Useful commands:"
    echo "  Check logs:   ./docker-nifi.sh logs"
    echo "  Stop:         ./docker-nifi.sh stop"
    echo "  Restart:      ./docker-nifi.sh restart"
    echo "  Rebuild NAR:  ./docker-nifi.sh reload"
    echo ""
    ;;

  stop)
    echo "Stopping NiFi Docker container..."
    $DOCKER_COMPOSE down
    echo "✅ NiFi stopped"
    ;;

  restart)
    echo "Restarting NiFi Docker container..."
    $DOCKER_COMPOSE restart
    echo "✅ NiFi restarted"
    echo ""
    echo "Web UI: https://localhost:8443/nifi"
    ;;

  reload)
    echo "========================================="
    echo " Rebuilding NAR and Reloading NiFi"
    echo "========================================="
    echo ""

    # NAR 빌드
    echo "[1/2] Building NAR..."
    "${SCRIPT_DIR}/build-nar.sh"

    # NiFi 재시작
    echo ""
    echo "[2/2] Restarting NiFi..."
    $DOCKER_COMPOSE restart

    echo ""
    echo "✅ NAR rebuilt and NiFi restarted"
    echo "⏳ Wait 30-60 seconds for NiFi to reload"
    echo ""
    echo "Web UI: https://localhost:8443/nifi"
    ;;

  logs)
    echo "Showing NiFi logs (Ctrl+C to exit)..."
    $DOCKER_COMPOSE logs -f nifi
    ;;

  clean)
    echo "⚠️  This will remove all NiFi data and volumes."
    read -p "Are you sure? (yes/no): " confirm
    if [ "$confirm" = "yes" ]; then
      echo "Stopping and removing containers and volumes..."
      $DOCKER_COMPOSE down -v
      echo "✅ All NiFi data cleaned"
    else
      echo "Cancelled"
    fi
    ;;

  status)
    echo "NiFi Docker container status:"
    $DOCKER_COMPOSE ps
    echo ""
    echo "To check if NiFi is ready:"
    echo "  curl -k https://localhost:8443/nifi"
    ;;

  shell)
    echo "Opening shell in NiFi container..."
    $DOCKER_COMPOSE exec nifi bash
    ;;

  help|*)
    echo "Usage: ./docker-nifi.sh [command]"
    echo ""
    echo "Commands:"
    echo "  start    - Start NiFi Docker container"
    echo "  stop     - Stop NiFi Docker container"
    echo "  restart  - Restart NiFi Docker container"
    echo "  reload   - Rebuild NAR and restart NiFi"
    echo "  logs     - Show NiFi logs"
    echo "  status   - Show container status"
    echo "  shell    - Open shell in NiFi container"
    echo "  clean    - Remove all containers and volumes"
    echo "  help     - Show this help message"
    echo ""
    echo "Examples:"
    echo "  ./docker-nifi.sh start"
    echo "  ./docker-nifi.sh reload"
    echo ""
    ;;
esac
