#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2026 community-scripts ORG
# Author: locallegend
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://sabre.io/baikal/ | https://www.inf-it.com/open-source/clients/infcloud/

APP="Baikal-InfCloud"
var_tags="${var_tags:-caldav;carddav}"
var_cpu="${var_cpu:-1}"
var_ram="${var_ram:-256}"
var_disk="${var_disk:-2}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -d /opt/baikal ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  if check_for_gh_release "baikal" "sabre-io/Baikal"; then
    msg_info "Stopping Service"
    systemctl stop nginx
    msg_ok "Stopped Service"

    msg_info "Backing up data"
    mv /opt/baikal /opt/baikal-backup
    msg_ok "Backed up data"

    fetch_and_deploy_gh_release "baikal" "sabre-io/Baikal" "tarball"

    msg_info "Restoring configuration"
    cp -r /opt/baikal-backup/config/baikal.yaml /opt/baikal/config/
    cp -r /opt/baikal-backup/Specific/ /opt/baikal/
    chown -R www-data:www-data /opt/baikal/
    chmod -R 755 /opt/baikal/
    cd /opt/baikal
    $STD composer install
    rm -rf /opt/baikal-backup
    msg_ok "Restored configuration"

    msg_info "Starting Service"
    systemctl start nginx
    msg_ok "Started Service"
    msg_ok "Updated successfully!"
  fi
  exit
}

start
build_container
description

msg_ok "Completed successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URLs (configure your central Caddy to proxy these):${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP} (Baikal - CalDAV/CardDAV + Admin)${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:81 (InfCloud Web UI)${CL}"
