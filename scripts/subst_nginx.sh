#!/usr/bin/env bash

TEMPLATES_PATH=${APP_ROOT}/scripts
NGINX_TEMPLATE="${TEMPLATES_PATH}/nginx.conf.template"
NGINX_CONFIG="/usr/local/openresty/nginx/conf/nginx.conf"

envsubst < ${NGINX_TEMPLATE} > ${NGINX_CONFIG}