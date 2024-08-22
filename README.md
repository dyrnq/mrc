# multi-registry-cache


Inspired by <https://github.com/obeone/multi-registry-cache> and <https://github.com/archef2000/rathole-docker/blob/main/entrypoint.sh>

## feature

- multi-registry
- all in one container(supervisord run 1)
- run user 1000
- volume persistence /data
- built-in redis
- built-in distribution <https://github.com/distribution/distribution>

## usage

eg.

```bash
mkdir -p $HOME/mrc_data
docker run -d \
--name mrc \
--restart always \
--env REG_NAME_0="docker.io" \
--env REG_PORT_0="5000" \
--env REG_PROXY_REMOTEURL_0="https://registry-1.docker.io" \
--env REG_REDIS_ADDR_0="127.0.0.1:6379" \
--env REG_REDIS_DB_0="0" \
--env REG_ENV_0="HTTP_PROXY=\"http://192.168.1.100:9119\",HTTPS_PROXY=\"http://192.168.1.100:9119\",NO_PROXY=\"127.0.0.1,localhost\"" \
--env REG_NAME_1="registry.k8s.io" \
--env REG_PORT_1="5001" \
--env REG_PROXY_REMOTEURL_1="https://registry.k8s.io" \
--env REG_REDIS_ADDR_1="127.0.0.1:6379" \
--env REG_REDIS_DB_1="1" \
--env REG_ENV_1="HTTP_PROXY=\"http://192.168.1.100:9119\",HTTPS_PROXY=\"http://192.168.1.100:9119\",NO_PROXY=\"127.0.0.1,localhost\"" \
--env REG_NAME_2="k8s.gcr.io" \
--env REG_PORT_2="5002" \
--env REG_PROXY_REMOTEURL_2="https://k8s.gcr.io" \
--env REG_REDIS_ADDR_2="127.0.0.1:6379" \
--env REG_REDIS_DB_2="2" \
--env REG_ENV_2="HTTP_PROXY=\"http://192.168.1.100:9119\",HTTPS_PROXY=\"http://192.168.1.100:9119\",NO_PROXY=\"127.0.0.1,localhost\"" \
-p 5000:5000 \
-p 5001:5001 \
-p 5003:5003 \
-v $HOME/mrc_data:/data \
dyrnq/mrc:latest


docker pull registry.k8s.io/kube-apiserver:v1.29.0

docker pull 127.0.0.1:5001/kube-apiserver:v1.29.0


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
```

envs description


0~15 because redis defaults to 16 databases


| name                 | description      | default | required |
|----------------------|------------------|---------|----------|
| REG_NAME_            | name             |         | y        |
| REG_PORT_            | port             |         | y        |
| REG_PROXY_REMOTEURL_ | proxy remoteurl  |         | y        |
| REG_PROXY_USERNAME_  | proxy username   |         | n        |
| REG_PROXY_PASSWORD_  | proxy password   |         | n        |
| REG_REDIS_ADDR_      | redis addr       |         | y        |
| REG_REDIS_PASSWORD_  | redis password   |         | n        |
| REG_ENV_             | distribution env |         | n        |


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