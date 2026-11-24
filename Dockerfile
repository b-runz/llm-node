# Self-built dev workspace: opencode (coding/chat agent), Ghidra (reverse engineering),
# Lightpanda + Playwright/Chromium (web tools), Python/uv, Node, git.
# Tools installed by the user persist because npm, uv and pip user installs go to $HOME,
# which is the PVC. System packages (apt) do not persist across an undeploy.
FROM ubuntu:24.04

ARG GHIDRA_VERSION=12.2
ARG GHIDRA_DATE=20261016
ARG GHIDRA_SHA256=2c2cd776db3c1f6a097ba418922378ac3649cadd5e844a6f5f088ae628a7be67
ARG OPENCODE_VERSION=1.19.6
ARG LIGHTPANDA_VERSION=1.0.5
ARG LIGHTPANDA_SHA256=7527391c479f323eb9111b834b012d91a89057528c28ef027741b21739b12299
ARG ANYFETCH_VERSION=0.8.4
ARG ANYFETCH_SHA256=4e056f3b71de21689a90bdb2da4515b653e95ccd5f29971db002c40754e86473

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    PLAYWRIGHT_BROWSERS_PATH=/opt/ms-playwright \
    JAVA_HOME=/usr/lib/jvm/java-25-openjdk-arm64

# Base tools, sudo, JDK 25 (Ghidra 12.2 requires it), Python.
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl git openssh-client tmux less jq ripgrep unzip xz-utils sudo \
      build-essential python3 python3-pip python3-venv openjdk-25-jdk-headless \
    && rm -rf /var/lib/apt/lists/*

# Node 22 (opencode and npm tools).
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# opencode, pinned.
RUN npm install -g opencode-ai@${OPENCODE_VERSION} && npm cache clean --force

# Ghidra, checksum-verified against the GitHub release digest. JDK override for its launcher.
RUN curl -fsSL -o /tmp/ghidra.zip \
      "https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_${GHIDRA_VERSION}_build/ghidra_${GHIDRA_VERSION}_PUBLIC_${GHIDRA_DATE}.zip" \
    && echo "${GHIDRA_SHA256}  /tmp/ghidra.zip" | sha256sum -c - \
    && unzip -q /tmp/ghidra.zip -d /opt \
    && mv /opt/ghidra_${GHIDRA_VERSION}_PUBLIC /opt/ghidra \
    && ln -s /opt/ghidra/support/analyzeHeadless /usr/local/bin/analyzeHeadless \
    && sed -i 's|^JAVA_HOME_OVERRIDE=.*|JAVA_HOME_OVERRIDE=/usr/lib/jvm/java-25-openjdk-arm64|' /opt/ghidra/support/launch.properties \
    && rm /tmp/ghidra.zip

# Lightpanda headless browser, checksum-verified.
RUN curl -fsSL -o /usr/local/bin/lightpanda \
      "https://github.com/lightpanda-io/browser/releases/download/${LIGHTPANDA_VERSION}/lightpanda-aarch64-linux" \
    && echo "${LIGHTPANDA_SHA256}  /usr/local/bin/lightpanda" | sha256sum -c - \
    && chmod 755 /usr/local/bin/lightpanda

# anyfetch: web search and fetch (MCP server for opencode), checksum-verified.
RUN curl -fsSL -o /tmp/anyfetch.tar.xz \n      "https://github.com/aliasmode/anyfetch/releases/download/v${ANYFETCH_VERSION}/anyfetch-aarch64-unknown-linux-gnu.tar.xz" \n    && echo "${ANYFETCH_SHA256}  /tmp/anyfetch.tar.xz" | sha256sum -c - \n    && mkdir -p /tmp/anyfetch && tar -xJf /tmp/anyfetch.tar.xz -C /tmp/anyfetch \n    && install -m 755 "$(find /tmp/anyfetch -name anyfetch -type f | head -1)" /usr/local/bin/anyfetch \n    && rm -rf /tmp/anyfetch /tmp/anyfetch.tar.xz

# Python tooling and Playwright with Chromium (system deps included).
RUN python3 -m pip install --break-system-packages --no-cache-dir playwright uv \
    && python3 -m playwright install --with-deps chromium \
    && rm -rf /var/lib/apt/lists/*

# apt: wrapper records installs for restore on start; apt cache moves to the persistent home.
COPY apt/apt-wrapper.sh /usr/local/bin/apt-wrapper.sh
RUN install -m 755 /usr/local/bin/apt-wrapper.sh /usr/local/bin/apt     && install -m 755 /usr/local/bin/apt-wrapper.sh /usr/local/bin/apt-get     && rm /usr/local/bin/apt-wrapper.sh     && mkdir -p /home/dev/.cache/apt-archives/partial     && echo 'Dir::Cache::Archives "/home/dev/.cache/apt-archives/";' > /etc/apt/apt.conf.d/99devws

# Image defaults (copied into the persistent home by entrypoint.sh).
COPY defaults/opencode.json /opt/devws/defaults/opencode.json
COPY skills/ /opt/devws/skills/
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 755 /usr/local/bin/entrypoint.sh

# Non-root user with passwordless sudo (sandbox). Home is the PVC mount point.
RUN userdel -r ubuntu 2>/dev/null; useradd -m -u 1000 -s /bin/bash dev \
    && echo "dev ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/dev && chmod 440 /etc/sudoers.d/dev \
    && chown dev:dev /home/dev && chown -R dev:dev /home/dev/.cache
USER dev
WORKDIR /home/dev/work

# User-level installs land in $HOME (persistent): npm globals, uv tools, pip --user.
ENV HOME=/home/dev \
    NPM_CONFIG_PREFIX=/home/dev/.npm-global \
    UV_CACHE_DIR=/home/dev/.cache/uv \
    UV_TOOL_DIR=/home/dev/.local/share/uv/tools \
    UV_TOOL_BIN_DIR=/home/dev/.local/bin \
    PYTHONUSERBASE=/home/dev/.local \
    PIP_BREAK_SYSTEM_PACKAGES=1 \
    PATH=/home/dev/.local/bin:/home/dev/.npm-global/bin:/usr/local/bin:/usr/bin:/bin

EXPOSE 4096
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
# opencode server; reached only through the tailnet ingress at the tailnet ingress host.
CMD ["opencode", "serve", "--hostname", "0.0.0.0", "--port", "4096"]
