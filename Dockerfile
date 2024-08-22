FROM debian:bookworm

ARG DISTRIBUTION_VERSION
ARG user=dist
ARG group=dist
ARG uid=1000
ARG gid=1000
ARG GOSU_VERSION

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.utf8 \
    DIST_HOME=${DIST_HOME:-/data} \
    GOSU_VERSION=${GOSU_VERSION:-1.17} \
    DISTRIBUTION_VERSION=${DISTRIBUTION_VERSION:-2.8.3}

RUN set -eux; \
    apt-get clean && \
    apt-get update && \
    apt-get -y upgrade && \
    apt-get install -yq \
    locales \
    ca-certificates \
    curl \
    openssh-client \
    psmisc \
    procps \
    iproute2 \
    tree \
    libfreetype6-dev \
    fontconfig \
    unzip \
    less \
    xz-utils \
    p7zip-full \
    zip \
    jq \
    supervisor \
    redis-server \
    && \
    localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8 && \
    groupadd -g ${gid} ${group} && useradd -d "$DIST_HOME" -u ${uid} -g ${gid} -m -s /bin/bash ${user} && rm -rf /var/lib/apt/lists/*;

RUN set -eux; \
    ARCH="$(uname -m)"; \
    case "${ARCH}" in \
       aarch64|arm64) \
         distributionArch="arm64"; \
         gosuArch="arm64"; \
         ;; \
       armhf|armv7l) \
         distributionArch="armv7"; \
         gosuArch="armhf"; \
         ;; \
       ppc64el|ppc64le) \
         distributionArch="ppc64le"; \
         gosuArch="ppc64el"; \
         ;; \
       amd64|x86_64) \
         distributionArch="amd64"; \
         gosuArch="amd64"; \
         ;; \
       *) \
         echo "Unsupported arch: ${ARCH}"; \
         exit 1; \
         ;; \
    esac; \
    curl --retry 3 -fsSL https://github.com/distribution/distribution/releases/download/v${DISTRIBUTION_VERSION}/registry_${DISTRIBUTION_VERSION}_linux_${distributionArch}.tar.gz | tar -xvz -C /usr/local/bin/ registry; \    
    curl --retry 3 -fsSL -o /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$gosuArch"; \
    chmod +x /usr/local/bin/registry; \
    registry --version; \
    chmod +x /usr/local/bin/gosu; \
    gosu --version;

VOLUME "${DIST_HOME}"

COPY rootfs /
ENTRYPOINT ["docker-entrypoint.sh"]