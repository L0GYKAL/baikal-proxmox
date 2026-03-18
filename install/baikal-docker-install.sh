#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: locallegend
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://sabre.io/baikal/ | https://www.inf-it.com/open-source/clients/infcloud/

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing dependencies"
$STD apt-get install -y \
  ca-certificates \
  curl \
  gnupg
msg_ok "Installed dependencies"

msg_info "Installing Docker"
$STD install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list
$STD apt-get update
$STD apt-get install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-compose-plugin
msg_ok "Installed Docker"

msg_info "Deploying Baikal + InfCloud"
mkdir -p /opt/baikal-docker
cat <<'EOF' >/opt/baikal-docker/docker-compose.yml
services:
  baikal:
    image: ckulka/baikal:nginx
    container_name: baikal
    restart: unless-stopped
    ports:
      - "80:80"
    volumes:
      - baikal-config:/var/www/baikal/config
      - baikal-data:/var/www/baikal/Specific

  infcloud:
    image: alekna/infcloud
    container_name: infcloud
    restart: unless-stopped
    ports:
      - "81:80"

volumes:
  baikal-config:
  baikal-data:
EOF

cd /opt/baikal-docker
$STD docker compose up -d
msg_ok "Deployed Baikal + InfCloud"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
