#!/usr/bin/env bash
# Copyright (c) 2021-2026 tteck | community-scripts ORG
# Original author: MickLesk (CanbiZ)
# Modifications Copyright (c) 2026 asenfter
# License: MIT
# Based on: https://github.com/community-scripts/ProxmoxVE/blob/main/install/github-runner-install.sh
# Sources:
# https://docs.github.com/en/actions/hosting-your-own-runners
# https://docs.docker.com/engine/install/debian/

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt install -y ca-certificates curl git gh
msg_ok "Installed Dependencies"

NODE_VERSION="24" setup_nodejs

msg_info "Installing Docker repository"
install -m 0755 -d /etc/apt/keyrings
$STD curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
. /etc/os-release
cat >/etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: ${VERSION_CODENAME}
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF
$STD apt update
msg_ok "Installed Docker repository"

msg_info "Installing Docker Engine and Compose"
$STD apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable -q --now docker
msg_ok "Installed Docker Engine and Compose"

msg_info "Creating runner user (no sudo)"
useradd -m -s /bin/bash runner
usermod -aG docker runner
msg_ok "Runner user ready"

fetch_and_deploy_gh_release "actions-runner" "actions/runner" "prebuild" "latest" "/opt/actions-runner" "actions-runner-linux-$(arch_resolve "x64" "arm64")-*.tar.gz"

# The prebuilt runner is .NET based and refuses to start without libicu.
# Runs as root, before the ownership handover below.
msg_info "Installing runner dependencies"
$STD /opt/actions-runner/bin/installdependencies.sh
msg_ok "Installed runner dependencies"

msg_info "Setting ownership for runner user"
chown -R runner:runner /opt/actions-runner
install -d -o runner -g runner -m 0755 /opt/homelab
msg_ok "Ownership set"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/actions-runner.service
[Unit]
Description=GitHub Actions self-hosted runner
Documentation=https://docs.github.com/en/actions/hosting-your-own-runners
After=network-online.target docker.service
Wants=network-online.target
Requires=docker.service
# run.sh exits non-zero until the runner is registered. Without this the
# enabled unit would restart every 10s from first boot until config.sh runs.
ConditionPathExists=/opt/actions-runner/.runner
StartLimitIntervalSec=300
StartLimitBurst=5

[Service]
Type=simple
User=runner
WorkingDirectory=/opt/actions-runner
ExecStart=/opt/actions-runner/run.sh
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q actions-runner
msg_ok "Created Service"

msg_info "Verifying Docker installation"
$STD docker version
$STD docker compose version
msg_ok "Verified Docker installation"

motd_ssh
customize
cleanup_lxc
