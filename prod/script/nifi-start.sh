#!/bin/bash
set -e

echo "========================================="
echo " Starting Apache NiFi"
echo "========================================="

# JAVA_HOME 설정
if [ -z "$JAVA_HOME" ]; then
  JAVA_HOME_PATH=$(dirname "$(dirname "$(readlink -f "$(which java)")")")
  export JAVA_HOME="${JAVA_HOME_PATH}"
  export PATH="$JAVA_HOME/bin:$PATH"
fi

# NiFi 실행
echo "Starting NiFi service..."
cd /opt/nifi/bin
./nifi.sh start

echo ""
echo "========================================="
echo " NiFi startup initiated."
echo ""
echo " Access URL:"
echo "   http://<EC2_PUBLIC_IP>:8080/nifi"
echo ""
echo " Useful commands:"
echo "   Status: /opt/nifi/bin/nifi.sh status"
echo "   Logs:   tail -f /opt/nifi/logs/nifi-app.log"
echo "   Stop:   /opt/nifi/bin/nifi.sh stop"
echo ""
echo " Note: NiFi may take 1-2 minutes to fully start."
echo "========================================="