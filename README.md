# multi-registry-cache


Inspired by [obeone/multi-registry-cache](https://github.com/obeone/multi-registry-cache) and [archef2000/rathole-docker](https://github.com/archef2000/rathole-docker/blob/main/entrypoint.sh)

## feature

- multi-registry
- all in one container(supervisord run 1)
- run user 1000
- volume persistence /data
- built-in redis
- built-in distribution <https://github.com/distribution/distribution>


see [Dockerfile](https://github.com/dyrnq/mrc/blob/main/Dockerfile)

## usage

eg.

```bash
mkdir -p $HOME/mrc_data
REG_ENV="HTTP_PROXY=\"http://192.168.1.100:9119\",HTTPS_PROXY=\"http://192.168.1.100:9119\",NO_PROXY=\"127.0.0.1,localhost\""
docker run -d \
--name mrc \
--restart always \
--env REG_NAME_0="docker.io" \
--env REG_PORT_0="5000" \
--env REG_PROXY_REMOTEURL_0="https://registry-1.docker.io" \
--env REG_REDIS_ADDR_0="127.0.0.1:6379" \
--env REG_REDIS_DB_0="0" \
--env REG_ENV_0="${REG_ENV}" \
--env REG_NAME_1="registry.k8s.io" \
--env REG_PORT_1="5001" \
--env REG_PROXY_REMOTEURL_1="https://registry.k8s.io" \
--env REG_REDIS_ADDR_1="127.0.0.1:6379" \
--env REG_REDIS_DB_1="1" \
--env REG_ENV_1="${REG_ENV}" \
--env REG_NAME_2="k8s.gcr.io" \
--env REG_PORT_2="5002" \
--env REG_PROXY_REMOTEURL_2="https://k8s.gcr.io" \
--env REG_REDIS_ADDR_2="127.0.0.1:6379" \
--env REG_REDIS_DB_2="2" \
--env REG_ENV_2="${REG_ENV}" \
--env REG_NAME_3="gcr.io" \
--env REG_PORT_3="5003" \
--env REG_PROXY_REMOTEURL_3="https://gcr.io" \
--env REG_REDIS_ADDR_3="127.0.0.1:6379" \
--env REG_REDIS_DB_3="3" \
--env REG_ENV_3="${REG_ENV}" \
-p 5000:5000 \
-p 5001:5001 \
-p 5002:5002 \
-p 5003:5003 \
-v $HOME/mrc_data:/data \
dyrnq/mrc:latest


## docker pull registry.k8s.io/kube-apiserver:v1.29.0
docker pull 127.0.0.1:5001/kube-apiserver:v1.29.0

## docker pull k8s.gcr.io/pause:3.3
docker pull 127.0.0.1:5002/pause:3.3

## docker pull gcr.io/cadvisor/cadvisor
docker pull 127.0.0.1:5003/cadvisor/cadvisor

```

```bash
pstree -lsa
supervisord /usr/bin/supervisord --nodaemon --configuration /etc/supervisord.conf
  ├─redis-server
  │   └─5*[{redis-server}]
  ├─registry serve /etc/distribution/docker.io/config.yml
  │   └─8*[{registry}]
  ├─registry serve /etc/distribution/k8s.gcr.io/config.yml
  │   └─9*[{registry}]
  └─registry serve /etc/distribution/registry.k8s.io/config.yml
      └─10*[{registry}]


root@34b4b2dec8a3:/# tree -L 2 /data/
/data/
├── redis
│   ├── data
│   ├── log
│   └── redis.conf
└── registry
    ├── docker.io
    ├── k8s.gcr.io
    └── registry.k8s.io

root@34b4b2dec8a3:/# tree /etc/supervisor/conf.d/
/etc/supervisor/conf.d/
├── redis-server.ini
├── reg-docker.io.ini
├── reg-k8s.gcr.io.ini
└── reg-registry.k8s.io.ini

1 directory, 4 files
```

envs description

0~15 because redis defaults to 16 databases, use `REDIS_DATABASES` env , eg. `--env REDIS_DATABASES=32`.

| name                           | description       | default            | required |
|--------------------------------|-------------------|--------------------|----------|
| REG_NAME_                      | name              |                    | y        |
| REG_PORT_                      | port              |                    | y        |
| REG_PROXY_REMOTEURL_           | proxy remoteurl   |                    | y        |
| REG_PROXY_USERNAME_            | proxy username    |                    | n        |
| REG_PROXY_PASSWORD_            | proxy password    |                    | n        |
| REG_PROXY_TTL_                 | proxy ttl         | 168h               | n        |
| REG_REDIS_ADDR_                | redis addr        |                    | y        |
| REG_REDIS_PASSWORD_            | redis password    |                    | n        |
| REG_LOG_LEVEL_                 | log level         | info               | n        |
| REG_ENV_                       | distribution env  |                    | n        |
| REG_STORAGE_                   | storage           | filesystem         | y        |
| REG_STORAGE_S3_ACCESSKEY_      | s3 accesskey      |                    | y(s3)    |
| REG_STORAGE_S3_SECRETKEY_      | s3 secretkey      |                    | y(s3)    |
| REG_STORAGE_S3_REGIONENDPOINT_ | s3 regionendpoint |                    | y(s3)    |
| REG_STORAGE_S3_REGION_         | s3 region         | us-east-1          | n(s3)    |
| REG_STORAGE_S3_BUCKET_         | s3 bucket         |                    | y(s3)    |
| REG_STORAGE_S3_ROOTDIRECTORY_  | s3 rootdirectory  | /registry/${!name} | n(s3)    |
| REDIS_DATABASES                | redis databases   | 16                 | n        |



## mirrors

### docker

```bash
cat /etc/docker/daemon.json 
{    
    "registry-mirrors": [ "http://127.0.0.1:5000" ]
}

```

ref

- <https://docs.docker.com/docker-hub/mirror/#configure-the-docker-daemon>

### containerd

```bash
mkdir -p /etc/containerd/certs.d/registry.k8s.io
cat > /etc/containerd/certs.d/registry.k8s.io/hosts.toml<<EOF
server = "https://registry.k8s.io"
[host."http://127.0.0.1:5001"]
  capabilities = ["pull","resolve"]
  skip_verify = true
[host."https://k8s.m.daocloud.io"]
  capabilities = ["pull","resolve"]
[host."https://registry.k8s.io"]
  capabilities = ["pull","resolve","push"]
EOF
```

ref

- <https://github.com/containerd/containerd/blob/main/docs/cri/config.md#registry-configuration>
- <https://github.com/containerd/containerd/blob/main/docs/hosts.md>
- <https://github.com/containerd/containerd/blob/main/docs/cri/registry.md>

## ref

- <https://github.com/distribution/distribution>
- <https://github.com/dyrnq/mrc>