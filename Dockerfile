# Ubuntu image for building, for compatibility with macOS arm64
FROM eclipse-temurin:21-jdk-jammy AS build

# Set necessary args and environment variables for building phoenixd
# Including pinning commit hash
ARG PHOENIXD_BRANCH=v0.6.0
ARG PHOENIXD_COMMIT_HASH=fa318d9cd600aff45df132b7c01cbb959e66caa4

# Upgrade all packages and install dependencies
RUN DEBIAN_FRONTEND=noninteractive apt-get update \
    && apt-get upgrade -y
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    bash \
    git \
    && apt clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Git pull phoenixd source at specified tag/branch and compile phoenixd
WORKDIR /phoenixd
RUN git clone --recursive --single-branch --branch ${PHOENIXD_BRANCH} -c advice.detachedHead=false \
    https://github.com/ACINQ/phoenixd . \
    && test `git rev-parse HEAD` = ${PHOENIXD_COMMIT_HASH} || exit 1 \
    && ./gradlew jvmDistTar

# Use JRE Ubuntu image as final base image temporarily to resolve https://github.com/sethforprivacy/phoenixd-docker/issues/13
FROM eclipse-temurin:21-jre-jammy AS final

# Upgrade all packages and install dependencies
RUN DEBIAN_FRONTEND=noninteractive apt-get update \
    && apt-get upgrade -y
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    && apt clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Create a phoenix group and user
RUN addgroup --system phoenix --gid 1000 \
    && adduser --system phoenix --ingroup phoenix --uid 1000 --home /phoenix
USER phoenix:phoenix

# Unpack the release
WORKDIR /phoenix
COPY --chown=phoenix:phoenix --from=BUILD /phoenixd/build/distributions/phoenixd-*-jvm.tar .
RUN tar --strip-components=1 -xvf phoenixd-*-jvm.tar

# Indicate that the container listens on port 9740
EXPOSE 9740

# Expose default data directory as VOLUME
VOLUME [ "/phoenix" ]

# Run the daemon with necessary flags for a detacted daemon mode
ENTRYPOINT ["/phoenix/bin/phoenixd", "--agree-to-terms-of-service", "--http-bind-ip", "0.0.0.0"]
