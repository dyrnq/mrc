#!/bin/bash
set -eo pipefail
shopt -s nullglob


function create_valid_reg() {

name="REG_NAME_${1}"
port="REG_PORT_${1}"
log_level="REG_LOG_LEVEL_${1}"
proxy_remoteurl="REG_PROXY_REMOTEURL_${1}"
proxy_username="REG_PROXY_USERNAME_${1}"
proxy_password="REG_PROXY_PASSWORD_${1}"
proxy_ttl="REG_PROXY_TTL_${1}"
redis_addr="REG_REDIS_ADDR_${1}"
redis_password="REG_REDIS_PASSWORD_${1}"
redis_db="REG_REDIS_DB_${1}"
env="REG_ENV_${1}"

mkdir -p --verbose /etc/distribution/"${!name}"
rootdirectory="${DIST_HOME}"/registry/"${!name}"
mkdir -p --verbose "${rootdirectory}"
chown -R dist:dist "${rootdirectory}"

cat >/etc/distribution/"${!name}"/config.yml<<EOF
# https://github.com/distribution/distribution
# https://distribution.github.io/distribution/about/configuration/#list-of-configuration-options
version: 0.1
log:
  accesslog:
    disabled: true
  level: ${!log_level:-info}
  formatter: text
  fields:
    service: registry
    environment: staging
storage:
  cache:
    #blobdescriptor: inmemory
    blobdescriptor: redis
  filesystem:
    rootdirectory: ${rootdirectory}
http:
  addr: 0.0.0.0:${!port}
  secret: asecretforlocaldevelopment
  headers:
    Access-Control-Expose-Headers: ['Docker-Content-Digest']
    Access-Control-Allow-Methods: ['HEAD', 'GET', 'OPTIONS', 'DELETE']
    Access-Control-Allow-Origin: ['*']
    X-Content-Type-Options: [nosniff]
proxy:
  remoteurl: ${!proxy_remoteurl}
  username: ${!proxy_username}
  password: ${!proxy_password}
  ttl: ${!proxy_ttl:-168h}
redis:
  addr: ${!redis_addr}
  password: ${!redis_password}
  db: ${!redis_db}
  dialtimeout: 2ms
  readtimeout: 2ms
  writetimeout: 2ms
  pool:
    maxidle: 16
    maxactive: 64
    idletimeout: 300s
  tls:
    enabled: false
EOF


cat >/etc/supervisor/conf.d/reg-"${!name}".ini<<EOF
[program:${!name}]
environment = ${!env}
command = gosu dist registry serve /etc/distribution/${!name}/config.yml
autostart = true
redirect_stderr = true
stopasgroup = true
killasgroup = true
EOF

}


create_redis() {

redis_databases="${1}"
redis_data="${DIST_HOME}"/redis/data
redis_log="${DIST_HOME}"/redis/log
redis_conf="${DIST_HOME}"/redis/redis.conf
mkdir -p "${redis_data}"
mkdir -p "${redis_log}"
chown -R dist:dist "${redis_data}"
chown -R dist:dist "${redis_log}"
if [ ! -f "${redis_conf}" ]; then
  cp --verbose --force /etc/redis/redis.conf "${redis_conf}"
  sed -i -e '/^dir/d' -e '/^logfile/d' -e "s|^databases.*|databases ${redis_databases}|g" "${redis_conf}"
  chown -R dist:dist "${redis_conf}"
fi


cat >/etc/supervisor/conf.d/redis-server.ini<<EOF
[program:redis-server]
command = gosu dist redis-server "${redis_conf}" --daemonize no --protected-mode no --appendonly yes --bind "* -::*" --dir ${redis_data} --logfile "${redis_log}/redis-server.log"
autostart = true
# stdout_logfile = /dev/stdout
redirect_stderr = true
stopasgroup = true
killasgroup = true
EOF

}

_main() {
redis_databases="${REDIS_DATABASES:-16}"
create_redis "${redis_databases}"
for reg_counter in $(seq 0 $((redis_databases-1))); do
  reg_name="REG_NAME_${reg_counter}"
  if [[ -z "${!reg_name}" ]]; then
    continue;
  fi
  create_valid_reg "${reg_counter}"
done


echo_supervisord_conf | grep -v -e '^\s*;' -e '^\s*$' >/etc/supervisord.conf;
sed -i -e "s@/tmp/supervisor.sock@/var/run/supervisor.sock@g" -e "s@/tmp/supervisord.pid@/var/run/supervisord.pid@g" /etc/supervisord.conf
echo "[include]" >> /etc/supervisord.conf; \
echo "files = /etc/supervisor/conf.d/*.ini" >> /etc/supervisord.conf;

chown -R dist:dist "${DIST_HOME}"
exec supervisord --nodaemon --configuration /etc/supervisord.conf
}


_main "$@"
