#!/usr/bin/env bash
_CS_DEFAULT_URL="https://raw.githubusercontent.com/asenfter/homelab-proxmox-scripts/main"
export COMMUNITY_SCRIPTS_URL="${COMMUNITY_SCRIPTS_URL:-$_CS_DEFAULT_URL}"
_cs_boot="${COMMUNITY_SCRIPTS_CORE_DIR:-$(dirname "${BASH_SOURCE[0]}")/../../core}/core/build.func"
source "$_cs_boot" 2>/dev/null || source <(curl -fsSL "${COMMUNITY_SCRIPTS_CORE_URL:-https://raw.githubusercontent.com/community-scripts/core/main}/core/build.func")

# Copyright (c) 2021-2026 tteck | community-scripts ORG
# Original author: MickLesk (CanbiZ)
# Modifications Copyright (c) 2026 asenfter
# License: MIT
# Based on: https://github.com/community-scripts/ProxmoxVE/blob/main/ct/github-runner.sh
# Source: https://github.com/actions/runner
#
# APP is load-bearing: Community Scripts derives the installer name from it.
APP="Docker-Runner"
var_tags="${var_tags:-ci;docker}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
# Docker image layers and the runner's _work checkouts share this disk.
var_disk="${var_disk:-20}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_arm64="${var_arm64:-yes}"
var_unprivileged="${var_unprivileged:-1}"
var_nesting="${var_nesting:-1}"
var_keyctl="${var_keyctl:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources
  if [[ ! -f /opt/actions-runner/run.sh ]]; then
    msg_error "No ${APP} Installation Found!"
    exit 1
  fi

  # update_script runs inside the LXC.
  run_os_update

  if check_for_gh_release "actions-runner" "actions/runner"; then
    msg_info "Stopping Service"
    systemctl stop actions-runner 2>/dev/null || true
    msg_ok "Service stopped if it was running"

    msg_info "Backing up runner configuration"
    BACKUP_DIR="/opt/actions-runner.backup"
    mkdir -p "$BACKUP_DIR"
    for f in .runner .credentials .credentials_rsaparams .env .path; do
      [[ -f /opt/actions-runner/$f ]] && cp -a /opt/actions-runner/$f "$BACKUP_DIR/"
    done
    msg_ok "Backed up configuration"

    CLEAN_INSTALL=1 fetch_and_deploy_gh_release "actions-runner" "actions/runner" "prebuild" "latest" "/opt/actions-runner" "actions-runner-linux-$(arch_resolve "x64" "arm64")-*.tar.gz"

    # A new runner release may pull in additional system dependencies.
    # Runs before the chown below, so the restored tree stays runner-owned.
    msg_info "Installing runner dependencies"
    $STD /opt/actions-runner/bin/installdependencies.sh
    msg_ok "Installed runner dependencies"

    msg_info "Restoring runner configuration"
    for f in .runner .credentials .credentials_rsaparams .env .path; do
      [[ -f "$BACKUP_DIR/$f" ]] && cp -a "$BACKUP_DIR/$f" /opt/actions-runner/
    done
    rm -rf "$BACKUP_DIR"
    chown -R runner:runner /opt/actions-runner
    msg_ok "Restored configuration"

    # The container may legitimately have been created but never registered,
    # in which case run.sh would fail and the unit condition never matched.
    if [[ -f /opt/actions-runner/.runner ]]; then
      msg_info "Starting Service"
      systemctl start actions-runner
      msg_ok "Started Service"
    else
      msg_ok "Runner is not registered yet - leaving actions-runner stopped"
    fi
  fi
  msg_ok "Updated successfully!"
  exit
}

start
build_container
description
msg_ok "Completed successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} After first boot, configure /opt/actions-runner as user 'runner' with your GitHub registration token and start actions-runner.service.${CL}"
echo -e "${INFO}${YW} Deployment checkout directory: /opt/homelab${CL}"
