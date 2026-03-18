#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2026 community-scripts ORG
# Author: locallegend
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://sabre.io/baikal/ | https://www.inf-it.com/open-source/clients/infcloud/

APP="Baikal-Docker"
var_tags="${var_tags:-caldav;carddav;docker}"
var_cpu="${var_cpu:-1}"
var_ram="${var_ram:-512}"
var_disk="${var_disk:-4}"
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

  if [[ ! -f /opt/baikal-docker/docker-compose.yml ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  msg_info "Pulling latest images"
  cd /opt/baikal-docker
  $STD docker compose pull
  msg_ok "Pulled latest images"

  msg_info "Restarting containers"
  $STD docker compose up -d
  msg_ok "Restarted containers"

  exit
}

start
build_container
description

msg_ok "Completed successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URLs (configure your central Caddy to proxy these):${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:80 (Baikal - CalDAV/CardDAV + Admin)${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:81 (InfCloud Web UI)${CL}"
