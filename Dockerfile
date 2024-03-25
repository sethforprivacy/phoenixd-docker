# Much credit for the base of this image goes to @pm47: 
# https://github.com/ACINQ/phoenixd/issues/1#issuecomment-2016584446

# Create builder image using Ubuntu 18.04
# Ubuntu 18.04 is a necessarily older version of Ubuntu to support the build process for phoenixd and its dependencies
FROM ubuntu:18.04 as builder

# Pin phoenixd, lightning-kmp, and libcurl versions
ARG PHOENIXD_BRANCH=v0.1.1
ARG PHOENIXD_COMMIT_HASH=4e42a462e6cc7d0a09fb224820071991ac1a0eca
ARG LIGHTNING_KMP_BRANCH=v1.6.2-FEECREDIT-4
ARG LIGHTNING_KMP_COMMIT_HASH=eba5a5bf7d7d77bd59cb8e38ecd20ec72d288672
ARG CURL_VERSION=7.88.1

# Upgrade all packages and install dependencies
RUN apt-get update \
    && apt-get upgrade -y
RUN apt-get install -y --no-install-recommends \
        ca-certificates \
        openjdk-17-jdk \
        openssh-client \
        libgnutls28-dev \
        libsqlite3-dev  \
        build-essential \
        git \
        wget \
    && apt clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Set necessary args and environment variables for building phoenixd
ARG PHOENIXD_BRANCH
ARG PHOENIXD_COMMIT_HASH
ARG LIGHTNING_KMP_BRANCH
ARG LIGHTNING_KMP_COMMIT_HASH

# Build dependencies
WORKDIR /lightning-kmp
RUN git clone --recursive --branch ${LIGHTNING_KMP_BRANCH} \
    https://github.com/ACINQ/lightning-kmp . \
    && test `git rev-parse HEAD` = ${LIGHTNING_KMP_COMMIT_HASH} || exit 1 \
    && ./gradlew publishToMavenLocal -x dokkaHtml

WORKDIR /curl
RUN wget https://curl.se/download/curl-${CURL_VERSION}.tar.bz2 \
    && tar -xjvf curl-${CURL_VERSION}.tar.bz2 \
    && cd curl-${CURL_VERSION} \
    && ./configure --with-gnutls=/lib/x86_64-linux-gnu/ \
    && make \
    && make install \
    && ldconfig

# Git pull phoenixd source at specified tag/branch and compile phoenixd binary
WORKDIR /phoenixd
RUN git clone --recursive --branch ${PHOENIXD_BRANCH} \
    https://github.com/ACINQ/phoenixd . \
    && test `git rev-parse HEAD` = ${PHOENIXD_COMMIT_HASH} || exit 1 \
    && ./gradlew packageLinuxX64

# Begin final image build
# Select Ubuntu 18.04 for the base image
# Ubuntu 18.04 is a necessarily older version of Ubuntu to support the build process for phoenixd and its dependencies
FROM ubuntu:18.04 as final

ARG CURL_VERSION=7.88.1

# Upgrade all packages and install dependencies
RUN DEBIAN_FRONTEND=noninteractive apt-get update \
    && apt-get upgrade -y
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        libgnutls28-dev \
        libsqlite3-dev  \
        wget \
    && apt clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Build and install necessary libcurl dependency, and then cleanup
WORKDIR /curl
RUN wget https://curl.se/download/curl-${CURL_VERSION}.tar.bz2 \
    && tar -xjvf curl-${CURL_VERSION}.tar.bz2 \
    && cd curl-${CURL_VERSION} \
    && ./configure --with-gnutls=/lib/x86_64-linux-gnu/ \
    && make \
    && make install \
    && ldconfig \
    && rm -rf /curl \
    && DEBIAN_FRONTEND=noninteractive apt purge -y build-essential wget \
    && apt autoremove -y

# Set phoenix user and group with static IDs
ARG GROUP_ID=1000
ARG USER_ID=1000
RUN groupadd -g ${GROUP_ID} phoenix \
    && useradd -u ${USER_ID} -g phoenix -d /phoenix phoenix

# Switch to home directory and install newly built phoenixd binary
WORKDIR /phoenix
COPY --chown=phoenix:phoenix --from=builder /phoenixd/build/bin/linuxX64/phoenixdReleaseExecutable/phoenixd.kexe /usr/local/bin/phoenixd

# Indicate that the container listens on port 9740
EXPOSE 9740

# Expose default phoenixd storage location
VOLUME ["/phoenix/.phoenix"]

# Run the daemon
ENTRYPOINT ["phoenixd", "--http-bind-ip", "0.0.0.0"]