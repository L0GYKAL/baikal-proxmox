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

msg_info "Installing Dependencies"
$STD apt-get install -y \
  nginx \
  unzip \
  git
msg_ok "Installed Dependencies"

PHP_FPM="YES" PHP_VERSION="8.2" setup_php
setup_composer
fetch_and_deploy_gh_release "baikal" "sabre-io/Baikal" "tarball"

msg_info "Configuring Baikal"
cd /opt/baikal
$STD composer install
chown -R www-data:www-data /opt/baikal/
chmod -R 755 /opt/baikal/
msg_ok "Configured Baikal"

msg_info "Downloading InfCloud"
INFCLOUD_VERSION="0.13.1"
curl -fsSL "https://www.inf-it.com/InfCloud_${INFCLOUD_VERSION}.zip" -o /tmp/infcloud.zip
unzip -qo /tmp/infcloud.zip -d /tmp/infcloud-extract
mv /tmp/infcloud-extract/infcloud /opt/infcloud
rm -rf /tmp/infcloud.zip /tmp/infcloud-extract

# Configure InfCloud to connect to Baikal through the central Caddy
cat <<'JSEOF' >/opt/infcloud/config.js
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

chown -R www-data:www-data /opt/infcloud/
msg_ok "Downloaded InfCloud ${INFCLOUD_VERSION}"

msg_info "Configuring Nginx"
cat <<'EOF' >/etc/nginx/sites-available/baikal
server {
    listen 80;
    server_name _;

    root /opt/baikal/html;
    index index.php;

    # CalDAV/CardDAV autodiscovery
    rewrite ^/.well-known/caldav  /dav.php redirect;
    rewrite ^/.well-known/carddav /dav.php redirect;

    location / {
        try_files $uri $uri/ /index.php$is_args$args;
    }

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_pass unix:/run/php/php-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    }

    # Block access to sensitive files
    location ~ \.(ht|sqlite|yaml)$ {
        deny all;
    }
}

server {
    listen 81;
    server_name _;

    root /opt/infcloud;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }

    # Only serve static files
    location ~ \.php$ {
        deny all;
    }
}
EOF

rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/baikal /etc/nginx/sites-enabled/baikal
$STD nginx -t
$STD systemctl restart nginx
$STD systemctl enable nginx
msg_ok "Configured Nginx"

motd_ssh
customize
cleanup_lxc
