FROM openresty/openresty:1.19.9.1-5-bullseye-fat

ENV APP_ROOT="/var/app" \
    LUA_LIBS_PATH="/usr/local/openresty/site/lualib" \
    OPENRESTY_LUA_LIBS_PATH="/usr/local/openresty/lualib" \
    NGINX_CONF_DIR_PATH="/usr/local/openresty/nginx/conf" \
    USER=nobody \
    GROUP=nogroup \
    PORT=8080 \
    USER_ID=65534

WORKDIR ${APP_ROOT}

ADD https://raw.githubusercontent.com/openresty/lua-resty-redis/master/lib/resty/redis.lua ${LUA_LIBS_PATH}/resty/redis.lua
ADD https://raw.githubusercontent.com/openresty/lua-resty-redis/master/lib/resty/redis.lua ${OPENRESTY_LUA_LIBS_PATH}/resty/redis.lua

RUN true && \
    apt update -y && \
    apt install -y git && \
    opm remove SkyLothar/lua-resty-jwt || true && \
    opm get cdbattags/lua-resty-jwt>=0.2.0 && \
    opm get knyar/nginx-lua-prometheus && \
    chown -R ${USER}:${GROUP} /usr/local/openresty/nginx/ && \
    chmod +r ${LUA_LIBS_PATH}/resty/redis.lua && \
    chmod +r ${OPENRESTY_LUA_LIBS_PATH}/resty/redis.lua && \
    git clone https://github.com/trezorg/lua-nginx-guard-jwt.git /tmp/lua-nginx-guard-jwt && \
    cp -v /tmp/lua-nginx-guard-jwt/lib/guardjwt.lua ${LUA_LIBS_PATH}/ && \
    apt purge -y git && \
    rm -rf rm -rf /var/lib/apt/lists/*

# COPY lua/vendor ${LUA_LIBS_PATH}
COPY lua/* ${LUA_LIBS_PATH}/
COPY scripts/subst_nginx.sh ${APP_ROOT}/scripts/
COPY scripts/nginx.conf.template ${APP_ROOT}/scripts/
COPY scripts/nginx.configure-logs-format.conf ${NGINX_CONF_DIR_PATH}/
COPY scripts/nginx.configure-proxy.conf ${NGINX_CONF_DIR_PATH}/
COPY scripts/nginx.configure-metrics.conf ${NGINX_CONF_DIR_PATH}/
COPY scripts/nginx.configure-proxy-websockets.conf ${NGINX_CONF_DIR_PATH}/
COPY scripts/nginx.configure-connection-map.conf ${NGINX_CONF_DIR_PATH}/

USER ${USER_ID}
EXPOSE ${PORT}

CMD ["/usr/bin/openresty", "-g", "daemon off;"]
