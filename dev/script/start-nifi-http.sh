#!/bin/sh -e

scripts_dir='/opt/nifi/scripts'

# Load common functions
[ -f "${scripts_dir}/common.sh" ] && . "${scripts_dir}/common.sh"

# Setup Python
uncomment "nifi.python.command" ${nifi_props_file}
prop_replace 'nifi.python.extensions.source.directory.default'  "${NIFI_HOME}/python_extensions"
prop_replace 'nifi.nar.library.autoload.directory'  "${NIFI_HOME}/nar_extensions"

# HTTP 활성화 및 HTTPS 비활성화
prop_replace 'nifi.web.http.host'   '0.0.0.0'
prop_replace 'nifi.web.http.port'   '8080'
prop_replace 'nifi.web.https.host'  ''
prop_replace 'nifi.web.https.port'  ''

# 기본 설정
prop_replace 'nifi.remote.input.host'           "${NIFI_REMOTE_INPUT_HOST:-$HOSTNAME}"
prop_replace 'nifi.remote.input.socket.port'    "${NIFI_REMOTE_INPUT_SOCKET_PORT:-10000}"
prop_replace 'nifi.remote.input.secure'         'false'

# 보안 비활성화
prop_replace 'nifi.security.keystore'  ''
prop_replace 'nifi.security.keystoreType'  ''
prop_replace 'nifi.security.keystorePasswd'  ''
prop_replace 'nifi.security.keyPasswd'  ''
prop_replace 'nifi.security.truststore'  ''
prop_replace 'nifi.security.truststoreType'  ''
prop_replace 'nifi.security.truststorePasswd'  ''
prop_replace 'nifi.security.user.login.identity.provider'  ''
prop_replace 'nifi.security.user.authorizer'  ''
prop_replace 'nifi.security.allow.anonymous.authentication'  'true'

# NiFi 시작
"${NIFI_HOME}/bin/nifi.sh" run &
nifi_pid="$!"
tail -F --pid=${nifi_pid} "${NIFI_HOME}/logs/nifi-app.log" &

trap 'echo Received trapped signal, beginning shutdown...;./bin/nifi.sh stop;exit 0;' TERM HUP INT;
trap ":" EXIT

echo NiFi running with PID ${nifi_pid}.
wait ${nifi_pid}