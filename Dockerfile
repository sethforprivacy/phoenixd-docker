# Ubuntu image for building, for compatibility with macOS arm64
FROM eclipse-temurin:21-jdk-jammy AS build

# Set necessary args and environment variables for building phoenixd
# Including pinning commit hash
ARG PHOENIXD_BRANCH=linux-arm-build-0.4.0
ARG PHOENIXD_COMMIT_HASH=b5cd95c54dd2d2073fbfd7945f98334077e12a57

# Upgrade all packages and install dependencies
RUN apt-get update \
    && apt-get upgrade -y
RUN apt-get install -y --no-install-recommends bash git \
    && apt clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Git pull phoenixd source at specified tag/branch and compile phoenixd
WORKDIR /phoenixd
RUN git clone --recursive --single-branch --branch ${PHOENIXD_BRANCH} -c advice.detachedHead=false \
    https://github.com/ACINQ/phoenixd . \
    && test `git rev-parse HEAD` = ${PHOENIXD_COMMIT_HASH} || exit 1 \
    && ./gradlew distTar

# Use Alpine imageas final base image to minimize final image size
FROM eclipse-temurin:21-jre-alpine AS final

# Upgrade all packages and install dependencies
RUN apk update \
    && apk upgrade --no-interactive
RUN apk add --update --no-cache bash

# Create a phoenix group and user
RUN addgroup -S phoenix -g 1000 \
    && adduser -S phoenix -G phoenix -u 1000 -h /phoenix
USER phoenix:phoenix

# Unpack the release
WORKDIR /phoenix
COPY --chown=phoenix:phoenix --from=BUILD /phoenixd/build/distributions/phoenix-*-jvm.tar .
RUN tar --strip-components=1 -xvf phoenix-*-jvm.tar

# Indicate that the container listens on port 9740
EXPOSE 9740

# Expose default data directory as VOLUME
VOLUME [ "/phoenix" ]

# Run the daemon with necessary flags for a detacted daemon mode
ENTRYPOINT ["/phoenix/bin/phoenixd", "--agree-to-terms-of-service", "--http-bind-ip", "0.0.0.0"]
