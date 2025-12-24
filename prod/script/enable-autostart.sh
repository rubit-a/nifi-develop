#!/bin/bash
set -e

echo "========================================="
echo " NiFi Auto-start Configuration"
echo "========================================="

# 스크립트 디렉토리 확인
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# nifi-start.sh 스크립트를 NiFi bin 디렉토리에 복사
echo "[1/5] Copying nifi-start.sh to /opt/nifi/bin/..."
sudo cp "${SCRIPT_DIR}/nifi-start.sh" /opt/nifi/bin/
sudo chmod +x /opt/nifi/bin/nifi-start.sh
sudo chown ec2-user:ec2-user /opt/nifi/bin/nifi-start.sh

# systemd 서비스 파일 복사
echo "[2/5] Copying systemd service file..."
sudo cp "${SCRIPT_DIR}/nifi.service" /etc/systemd/system/

# systemd 데몬 리로드
echo "[3/5] Reloading systemd daemon..."
sudo systemctl daemon-reload

# NiFi 서비스 활성화 (부팅 시 자동 시작)
echo "[4/5] Enabling NiFi service..."
sudo systemctl enable nifi.service

# NiFi 서비스 즉시 시작
echo "[5/5] Starting NiFi service..."
sudo systemctl start nifi.service

echo ""
echo "========================================="
echo " Configuration and startup completed!"
echo ""
echo " Access URL:"
echo "   http://<EC2_PUBLIC_IP>:8080/nifi"
echo ""
echo " Useful commands:"
echo "   Stop:    sudo systemctl stop nifi"
echo "   Restart: sudo systemctl restart nifi"
echo "   Status:  sudo systemctl status nifi"
echo "   Logs:    sudo journalctl -u nifi -f"
echo ""
echo " NiFi is now running and will automatically"
echo " start on system boot."
echo ""
echo " Note: NiFi may take 1-2 minutes to fully start."
echo "========================================="