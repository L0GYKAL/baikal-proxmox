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

msg_info "Downloading InfCloud"
INFCLOUD_VERSION="0.13.1"
mkdir -p /opt/baikal-docker/infcloud
curl -fsSL "https://www.inf-it.com/InfCloud_${INFCLOUD_VERSION}.zip" -o /tmp/infcloud.zip
$STD apt-get install -y unzip
unzip -qo /tmp/infcloud.zip -d /opt/baikal-docker/infcloud
rm /tmp/infcloud.zip
msg_ok "Downloaded InfCloud ${INFCLOUD_VERSION}"

msg_info "Deploying Baikal + InfCloud"
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
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE

  infcloud:
    image: nginx:alpine
    container_name: infcloud
    restart: unless-stopped
    ports:
      - "81:80"
    volumes:
      - ./infcloud:/usr/share/nginx/html:ro
    read_only: true
    tmpfs:
      - /var/cache/nginx
      - /var/run
      - /tmp
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    networks: []

volumes:
  baikal-config:
  baikal-data:
EOF

# Configure InfCloud to connect to Baikal through the central Caddy
cat <<'JSEOF' >/opt/baikal-docker/infcloud/config.js
var defined_var = 'config.js';

var globalNetworkCheckSettings = {
	href: location.protocol + '//' + location.hostname +
		(location.port ? ':' + location.port : '') +
		'/dav.php/principals/',
	timeOut: 90000,
	lockTimeOut: 10000,
	settingsAccount: true,
	checkContentType: true,
	delegation: true,
	additionalResources: [],
	hrefLabel: null,
	forceReadOnly: null,
	withCredentials: false,
	crossDomain: null
};

var globalDatepickerFirstDayOfWeek = 1;
var globalHideInfoMessageAfter = 1800;
var globalEditorFadeAnimation = 300;
var globalInterfaceLanguage = 'en_US';
var globalInterfaceCustomLanguages = [];
var globalSortAlphabet = ' 0123456789AÀÁÂÃÄÅÆBCÇDĎEÈÉÊËFGHIÌÍÎÏJKLMNÑOÒÓÔÕÖØPQRŘSŠTUÙÚÛÜVWXYÝZŽaàáâãäåæbcçdďeèéêëfghiìíîïjklmnñoòóôõöøpqrřsštťuùúûüvwxyýzž';
var globalSearchTransformAlphabet = {
	'[ÀàÁáÂâÃãÄäÅåÆæ]': 'a', '[ÇçĆćČč]': 'c', '[Ďď]': 'd',
	'[ÈèÉéÊêËë]': 'e', '[ÌìÍíÎîÏï]': 'i', '[Ññ]': 'n',
	'[ÒòÓóÔôÕõÖöØø]': 'o', '[Řř]': 'r', '[Šš]': 's', '[Ťť]': 't',
	'[ÙùÚúÛûÜü]': 'u', '[Ýý]': 'y', '[Žž]': 'z'
};
var globalResourceAlphabetSorting = true;
var globalNewContactRecreate = false;
JSEOF

cd /opt/baikal-docker
$STD docker compose up -d
msg_ok "Deployed Baikal + InfCloud"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
