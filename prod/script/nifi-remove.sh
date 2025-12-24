#!/bin/bash
set -euo pipefail

FORCE="false"

for arg in "$@"; do
  case "${arg}" in
    -f|--force)
      FORCE="true"
      shift
      ;;
    *)
      ;;
  esac
done

echo "========================================="
echo " Apache NiFi Remove Script"
echo "========================================="
echo ""
echo "This will stop NiFi, disable systemd service,"
echo "and remove /opt/nifi and downloaded archives."
echo ""

if [ "${FORCE}" != "true" ]; then
  read -r -p "Type DELETE to proceed: " CONFIRM
  if [ "${CONFIRM}" != "DELETE" ]; then
    echo "Aborted."
    exit 0
  fi
fi

if systemctl list-unit-files | grep -q '^nifi.service'; then
  sudo systemctl stop nifi || true
  sudo systemctl disable nifi || true
  sudo rm -f /etc/systemd/system/nifi.service /usr/lib/systemd/system/nifi.service
  sudo systemctl daemon-reload
fi

sudo rm -rf /opt/nifi
sudo rm -f /opt/nifi-*-bin.zip

echo "✅ NiFi removed."
