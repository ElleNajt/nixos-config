FROM node:20

# NOTE: If using Nix on macOS, you must add /nix to Docker Desktop's file sharing settings:
# Docker Desktop → Settings → Resources → File Sharing → Add /nix
# This is required for mounting Nix store paths into the container.

ARG TZ
ENV TZ="$TZ"

ARG CLAUDE_CODE_VERSION=latest

# Install basic development tools and iptables/ipset
RUN apt-get update && apt-get install -y --no-install-recommends \
  less \
  git \
  procps \
  rsync \
  sudo \
  fzf \
  zsh \
  man-db \
  unzip \
  gnupg2 \
  gh \
  iptables \
  iputils-ping \
  ipset \
  iproute2 \
  dnsutils \
  aggregate \
  jq \
  nano \
  vim \
  emacs \
  fuse-overlayfs \
  python3 \
  python3-pip \
  python3-venv \
  build-essential \
  curl \
  sshfs \
  golang \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Ensure default node user has access to /usr/local/share
RUN mkdir -p /usr/local/share/npm-global && \
  chown -R node:node /usr/local/share

ARG USERNAME=node

# Persist bash history.
RUN SNIPPET="export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
  && mkdir /commandhistory \
  && touch /commandhistory/.bash_history \
  && chown -R $USERNAME /commandhistory

# Set `DEVCONTAINER` environment variable to help with orientation
ENV DEVCONTAINER=true

# Create workspace and config directories and set permissions
RUN mkdir -p /workspace /home/node/.claude /tmp/ClaudeWorkingDir && \
  chown -R node:node /workspace /home/node/.claude /tmp/ClaudeWorkingDir

WORKDIR /workspace

ARG GIT_DELTA_VERSION=0.18.2
RUN ARCH=$(dpkg --print-architecture) && \
  wget "https://github.com/dandavison/delta/releases/download/${GIT_DELTA_VERSION}/git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" && \
  sudo dpkg -i "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" && \
  rm "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb"

# Set up non-root user
USER node

# Install global packages
ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global
ENV PATH=$PATH:/usr/local/share/npm-global/bin

# Set the default shell to zsh rather than sh
ENV SHELL=/bin/zsh

# Default powerline10k theme
ARG ZSH_IN_DOCKER_VERSION=1.2.0
RUN sh -c "$(wget -O- https://github.com/deluan/zsh-in-docker/releases/download/v${ZSH_IN_DOCKER_VERSION}/zsh-in-docker.sh)" -- \
  -p git \
  -p fzf \
  -a "source /usr/share/doc/fzf/examples/key-bindings.zsh" \
  -a "source /usr/share/doc/fzf/examples/completion.zsh" \
  -a "export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
  -x

# Install Claude
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}

# Install ACP
RUN npm install -g @zed-industries/claude-code-acp

# Install beads
RUN npm install -g @beads/bd

COPY firewall/init-firewall.sh /usr/local/bin/
USER root
RUN chmod +x /usr/local/bin/init-firewall.sh && \
  echo "node ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh" > /etc/sudoers.d/node-firewall && \
  chmod 0440 /etc/sudoers.d/node-firewall

# Copy Claude Code hook wrapper
COPY emacs/claude-code-hook-wrapper.sh /usr/local/bin/claude-code-hook-wrapper
RUN chmod +x /usr/local/bin/claude-code-hook-wrapper

# Copy fallback checker hook
COPY emacs/check-fallbacks.py /usr/local/bin/check-fallbacks.py
COPY emacs/check-fallbacks.sh /usr/local/bin/check-fallbacks.sh
RUN chmod +x /usr/local/bin/check-fallbacks.py /usr/local/bin/check-fallbacks.sh

# Install uv (fast Python package manager) - system-wide
# RUN curl -LsSf https://astral.sh/uv/install.sh | env INSTALLER_NO_MODIFY_PATH=1 sh && \
#   mv /root/.cargo/bin/uv /usr/local/bin/ && \
#   mv /root/.cargo/bin/uvx /usr/local/bin/

# Copy runpod script and install Python dependencies
COPY runpod/runpod.py /usr/local/bin/runpod
RUN chmod +x /usr/local/bin/runpod && \
  pip3 install --no-cache-dir boto3 requests python-dotenv matplotlib pandas numpy scipy scikit-learn pillow seaborn tensorboard --break-system-packages && \
  ln -s /usr/bin/python3 /usr/bin/python

# Copy agent-compile wrapper scripts
COPY agent-compile/agent-compile.sh /usr/local/bin/agent-compile
COPY agent-compile/agent-decompile.sh /usr/local/bin/agent-decompile
RUN chmod +x /usr/local/bin/agent-compile /usr/local/bin/agent-decompile

USER node

# Configure pip to default to --user installs for the node user
RUN mkdir -p /home/node/.config/pip && \
  echo "[install]" > /home/node/.config/pip/pip.conf && \
  echo "user = true" >> /home/node/.config/pip/pip.conf && \
  mkdir -p /home/node/.local/bin

# Add user's local bin to PATH
ENV PATH="/home/node/.local/bin:${PATH}"
