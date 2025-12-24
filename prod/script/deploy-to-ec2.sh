#!/bin/bash
set -e

# EC2 배포 스크립트
# 사용법: ./deploy-to-ec2.sh <EC2_HOST> [EC2_USER] [SSH_KEY]
#
# 예시:
#   ./deploy-to-ec2.sh ec2-xx-xx-xx-xx.compute.amazonaws.com
#   ./deploy-to-ec2.sh ec2-xx-xx-xx-xx.compute.amazonaws.com ec2-user ~/.ssh/ruby-jenkins.pem

# 스크립트 디렉토리
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# 인자 확인
if [ $# -lt 1 ]; then
    echo "Usage: $0 <EC2_HOST> [EC2_USER] [SSH_KEY]"
    echo ""
    echo "Examples:"
    echo "  $0 ec2-xx-xx-xx-xx.compute.amazonaws.com"
    echo "  $0 ec2-xx-xx-xx-xx.compute.amazonaws.com ec2-user ~/.ssh/ruby-jenkins.pem"
    echo ""
    exit 1
fi

EC2_HOST="$1"
EC2_USER="${2:-ec2-user}"  # 기본값: ec2-user
SSH_KEY="${3:-${PROJECT_ROOT}/rubit.pem}"  # 기본값: 프로젝트의 rubit.pem
NAR_FILE="${PROJECT_ROOT}/prod/nar/nifi-custom-nar-1.0.0.nar"

# SSH 키 경로 확장 및 정규화
SSH_KEY_EXPANDED="${SSH_KEY/#\~/$HOME}"  # ~ 확장
SSH_KEY_PATH="$(cd "$(dirname "${SSH_KEY_EXPANDED}")" 2>/dev/null && pwd)/$(basename "${SSH_KEY_EXPANDED}")"

# SSH 키 존재 확인
if [ ! -f "${SSH_KEY_PATH}" ]; then
    echo "❌ Error: SSH key not found at ${SSH_KEY_PATH}"
    exit 1
fi

# SSH 키 권한 확인 및 설정
KEY_PERMS=$(stat -f "%Lp" "${SSH_KEY_PATH}" 2>/dev/null || stat -c "%a" "${SSH_KEY_PATH}" 2>/dev/null)
if [ "${KEY_PERMS}" != "400" ] && [ "${KEY_PERMS}" != "600" ]; then
    echo "⚠️  SSH key permissions are too open. Fixing..."
    chmod 400 "${SSH_KEY_PATH}"
fi

echo "========================================="
echo " Deploy to EC2"
echo "========================================="
echo "EC2 Host: ${EC2_HOST}"
echo "EC2 User: ${EC2_USER}"
echo "SSH Key: ${SSH_KEY_PATH}"
echo "NAR File: ${NAR_FILE}"
echo ""

# NAR 파일 존재 확인
if [ ! -f "${NAR_FILE}" ]; then
    echo "❌ Error: NAR file not found at ${NAR_FILE}"
    echo ""
    echo "Please build the NAR first:"
    echo "  cd ${PROJECT_ROOT}"
    echo "  ./dev/script/build-nar.sh"
    echo ""
    exit 1
fi

# 배포 확인
read -p "Deploy to ${EC2_HOST}? (y/N) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

echo ""
echo "[1/2] Uploading NAR to EC2..."

# NAR 파일을 EC2로 전송
scp -i "${SSH_KEY_PATH}" "${NAR_FILE}" "${EC2_USER}@${EC2_HOST}:/tmp/"

echo "[2/2] Installing NAR on EC2..."

# EC2에서 배포 스크립트 실행
# shellcheck disable=SC2087
ssh -i "${SSH_KEY_PATH}" "${EC2_USER}@${EC2_HOST}" << 'ENDSSH'
set -e

echo "[Step 1/4] Stopping NiFi..."
sudo systemctl stop nifi || true

echo "[Step 2/4] Backing up existing NAR..."
NAR_DIR="/opt/nifi/lib"
BACKUP_DIR="/opt/nifi/lib/backup-$(date +%Y%m%d-%H%M%S)"

if [ -f "${NAR_DIR}/nifi-custom-nar-1.0.0.nar" ]; then
    sudo mkdir -p ${BACKUP_DIR}
    sudo mv ${NAR_DIR}/nifi-custom-nar-*.nar ${BACKUP_DIR}/ 2>/dev/null || true
    echo "✓ Previous NAR backed up to ${BACKUP_DIR}"
fi

echo "[Step 3/4] Installing new NAR..."
sudo mv /tmp/nifi-custom-nar-1.0.0.nar ${NAR_DIR}/
sudo chown ec2-user:ec2-user ${NAR_DIR}/nifi-custom-nar-1.0.0.nar
echo "✓ New NAR installed"

echo "[Step 4/4] Starting NiFi..."
sudo systemctl start nifi

echo ""
echo "========================================="
echo " Deployment completed successfully!"
echo "========================================="
echo ""
echo "NiFi Status:"
sudo systemctl status nifi --no-pager | head -n 10

echo ""
echo "NiFi will be available at:"
echo "  http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080/nifi"
ENDSSH

echo ""
echo "✅ Deployment completed!"