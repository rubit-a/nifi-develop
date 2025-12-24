#!/bin/bash
set -e

# 스크립트 디렉토리를 먼저 저장 (cd 명령 전에)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

NIFI_VERSION="2.5.0"
INSTALL_USER="ec2-user"
JAVA_PACKAGE="java-21-amazon-corretto"

echo "========================================="
echo " Apache NiFi CLEAN Final Install Script"
echo "========================================="

#################################
# 1. Java
#################################
echo "[1/6] Checking Java..."

if ! java -version &>/dev/null; then
  sudo dnf install -y ${JAVA_PACKAGE}
fi

JAVA_HOME_PATH=$(dirname "$(dirname "$(readlink -f "$(which java)")")")
export JAVA_HOME="${JAVA_HOME_PATH}"
export PATH="$JAVA_HOME/bin:$PATH"

#################################
# 2. Download & Install NiFi
#################################
echo "[2/6] Installing NiFi..."

cd /opt

if [ ! -d "nifi" ]; then
  if [ ! -f "nifi-${NIFI_VERSION}-bin.zip" ]; then
    sudo wget https://archive.apache.org/dist/nifi/${NIFI_VERSION}/nifi-${NIFI_VERSION}-bin.zip
  fi

  sudo unzip -q nifi-${NIFI_VERSION}-bin.zip
  sudo mv nifi-${NIFI_VERSION} nifi
  sudo chown -R ${INSTALL_USER}:${INSTALL_USER} /opt/nifi
fi

#################################
# 3. bootstrap.conf (JAVA)
#################################
echo "[3/6] Configuring bootstrap.conf..."

BOOTSTRAP="/opt/nifi/conf/bootstrap.conf"

sed -i "/^java.home=/d" ${BOOTSTRAP}
sed -i "1ijava.home=${JAVA_HOME_PATH}" ${BOOTSTRAP}

#################################
# 4. JVM memory
#################################
echo "[4/6] Configuring JVM memory..."

sed -i 's/java.arg.2=.*/java.arg.2=-Xms256m/' ${BOOTSTRAP}
sed -i 's/java.arg.3=.*/java.arg.3=-Xmx512m/' ${BOOTSTRAP}

#################################
# 5. nifi.properties 설정
#################################
echo "[5/6] Configuring nifi.properties..."

NIFI_PROP="/opt/nifi/conf/nifi.properties"

# Remote Input 설정
sed -i 's|nifi.remote.input.socket.port=.*|nifi.remote.input.socket.port=|' ${NIFI_PROP}
sed -i 's|nifi.remote.input.secure=.*|nifi.remote.input.secure=false|' ${NIFI_PROP}

# Web UI 설정
sed -i 's|nifi.web.http.port=.*|nifi.web.http.port=8080|' ${NIFI_PROP}
sed -i 's|# nifi.web.http.host=.*|nifi.web.http.host=0.0.0.0|' ${NIFI_PROP}
sed -i 's|nifi.web.http.host=.*|nifi.web.http.host=0.0.0.0|' ${NIFI_PROP}

# HTTPS 비활성화 (빈 값으로 설정)
sed -i 's|^# *nifi.web.https.port=.*|nifi.web.https.port=|' ${NIFI_PROP}
sed -i 's|^nifi.web.https.port=.*|nifi.web.https.port=|' ${NIFI_PROP}
sed -i 's|^# *nifi.web.https.host=.*|nifi.web.https.host=|' ${NIFI_PROP}
sed -i 's|^nifi.web.https.host=.*|nifi.web.https.host=|' ${NIFI_PROP}
sed -i 's|^nifi.security.keystore=.*|# nifi.security.keystore=|' ${NIFI_PROP}
sed -i 's|^nifi.security.keystoreType=.*|# nifi.security.keystoreType=|' ${NIFI_PROP}
sed -i 's|^nifi.security.truststore=.*|# nifi.security.truststore=|' ${NIFI_PROP}
sed -i 's|^nifi.security.truststoreType=.*|# nifi.security.truststoreType=|' ${NIFI_PROP}
sed -i 's|^nifi.security.keystorePasswd=.*|nifi.security.keystorePasswd=|' ${NIFI_PROP}
sed -i 's|^nifi.security.keyPasswd=.*|nifi.security.keyPasswd=|' ${NIFI_PROP}
sed -i 's|^nifi.security.truststorePasswd=.*|nifi.security.truststorePasswd=|' ${NIFI_PROP}
sed -i 's|^nifi.security.allow.anonymous.authentication=.*|# nifi.security.allow.anonymous.authentication=|' ${NIFI_PROP}
sed -i 's|^nifi.security.user.authorizer=.*|# nifi.security.user.authorizer=|' ${NIFI_PROP}
sed -i 's|^nifi.security.user.login.identity.provider=.*|# nifi.security.user.login.identity.provider=|' ${NIFI_PROP}
sed -i 's|^nifi.security.user.jws.key.rotation.period=.*|# nifi.security.user.jws.key.rotation.period=|' ${NIFI_PROP}

echo ""
echo "========================================="
echo " NiFi installation and configuration completed."
echo "========================================="

#################################
# 6. Auto-start 설정 및 NiFi 시작
#################################
echo ""
echo "[6/6] Configuring auto-start and starting NiFi..."
echo ""

# enable-autostart.sh 스크립트 실행
if [ -f "${SCRIPT_DIR}/enable-autostart.sh" ]; then
  "${SCRIPT_DIR}/enable-autostart.sh"
else
  echo "Error: enable-autostart.sh not found in ${SCRIPT_DIR}"
  echo ""
  echo "To manually enable auto-start and start NiFi:"
  echo "  ./enable-autostart.sh"
  exit 1
fi
