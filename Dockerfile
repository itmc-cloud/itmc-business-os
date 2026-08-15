syntax=docker/dockerfile:1

# Reproducible build image for this project's Android release (.aab) builds.
# Not used for day-to-day development (use a native Flutter install for that —
# hot reload/emulators don't work well in a container). This image exists so
# "build the release artifact" behaves identically on any machine and in CI,
# regardless of what's installed on the host.
#
# Usage:
#   docker build -t itmc-estimator-builder .
#   docker run --rm -v "$(pwd):/workspace" itmc-estimator-builder \
#     flutter build appbundle --release
#
# For a signed build, mount your keystore and android/key.properties as well
# (see docs/PUBLISHING.md) — they are git-ignored and must be supplied at
# build time, either as a local file mount or CI secrets.

FROM eclipse-temurin:17-jdk-jammy

ARG FLUTTER_VERSION=3.47.0
ARG ANDROID_CMDLINE_TOOLS_VERSION=11076708
ARG ANDROID_PLATFORM=android-35
ARG ANDROID_BUILD_TOOLS=35.0.0

ENV DEBIAN_FRONTEND=noninteractive \
    ANDROID_HOME=/opt/android-sdk \
    ANDROID_SDK_ROOT=/opt/android-sdk \
    FLUTTER_HOME=/opt/flutter \
    PATH=/opt/flutter/bin:/opt/android-sdk/cmdline-tools/latest/bin:/opt/android-sdk/platform-tools:$PATH

RUN apt-get update && apt-get install -y --no-install-recommends \
        curl \
        git \
        unzip \
        xz-utils \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# --- Android SDK command-line tools ---
RUN mkdir -p ${ANDROID_HOME}/cmdline-tools \
    && curl -sSL -o /tmp/cmdline-tools.zip \
        "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS_VERSION}_latest.zip" \
    && unzip -q /tmp/cmdline-tools.zip -d ${ANDROID_HOME}/cmdline-tools \
    && mv ${ANDROID_HOME}/cmdline-tools/cmdline-tools ${ANDROID_HOME}/cmdline-tools/latest \
    && rm /tmp/cmdline-tools.zip

RUN yes | sdkmanager --licenses >/dev/null \
    && sdkmanager --install \
        "platform-tools" \
        "platforms;${ANDROID_PLATFORM}" \
        "build-tools;${ANDROID_BUILD_TOOLS}"

# --- Flutter SDK ---
RUN git clone --depth 1 -b stable https://github.com/flutter/flutter.git ${FLUTTER_HOME} \
    && git -C ${FLUTTER_HOME} checkout ${FLUTTER_VERSION} \
    && flutter config --no-analytics \
    && flutter precache --android \
    && flutter doctor -v

WORKDIR /workspace

# Warm the pub cache with just the pubspec first, so dependency downloads are
# cached in a Docker layer separate from source-code changes.
COPY pubspec.yaml pubspec.lock* ./
RUN flutter pub get

COPY . .

CMD ["flutter", "build", "appbundle", "--release"]
