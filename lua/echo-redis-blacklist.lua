local resty_redis = require "resty.redis"

local ngx = require "ngx"

local REDIS_CONNECTION_TIMEOUT = 5 * 1000 -- in milliseconds
local REDIS_CONNECTION_KEEPALIVE_TIMEOUT = 60 * 1000 -- in milliseconds
local REDIS_CONNECTION_KEEPALIVE_POOL_SIZE = 1024
local REDIS_POOL_SIZE = 5 -- default pool size
local REDIS_BACKLOG = 5 -- connections queue size

local _M = {}

local function isempty(s)
  return s == nil or s == ''
end

--@function connects to redist and prepare connection to use
--@param nginx NGINX object
--@return (connection or nil, error or nil)
local function get_redis_connection(nginx)
    local redis = resty_redis:new()
    redis:set_timeout(REDIS_CONNECTION_TIMEOUT)
    local redis_pool_size = os.getenv("REDIS_POOL_SIZE")
    local redis_ssl = os.getenv("REDIS_SSL")

    if isempty(redis_pool_size) then
        redis_pool_size = REDIS_POOL_SIZE
    end

    if not isempty(redis_ssl) and redis_ssl:lower() == "true" then
        redis_ssl = true
    else
        redis_ssl = false
    end

    local redis_host = os.getenv("REDIS_HOST")
    local options = {
        pool_size = tonumber(redis_pool_size),
        backlog = REDIS_BACKLOG,
        ssl = redis_ssl
    }

    local redis_port = os.getenv("REDIS_PORT")

    local ok, err = redis:connect(redis_host, redis_port, options)

    if not ok then
        nginx.log(nginx.ERR, "failed to connect to redis: ", err)
        return nil, err
    end

    local redis_password = os.getenv("REDIS_PASSWORD")
    local redis_db = os.getenv("REDIS_DB")

    if not isempty(redis_password) then
        local ok, err = redis:auth(redis_password)
        if not ok then
            nginx.log(nginx.ERR, "failed to authenticate: ", err)
            return nil, err
        end
    end

    if not isempty(redis_db) then
        local ok, err = redis:select(redis_db)
        if not ok then
            nginx.log(nginx.ERR, "failed to select db: ", redis_db, " ", err)
            return nil, err
        end
    end

    return redis, nil

end


--@function queries redis as key=token to get information is token exist in blacklist or not
--@param nginx NGINX object
--@param token jwt string
--@return some value from redis or nil or null
local function get_token_from_redis(nginx, token)
    -- get key from redis
    -- nil  (something went wrong or no such key)
    -- key  (the key)
    local redis, _ = get_redis_connection(nginx)
    if not redis then
        return nil
    end

    local res, err = redis:get(token)
    if err then
        nginx.log(nginx.ERR, "something wrong with token: ", token, "\nError message: ", err)
    else
        redis:set_keepalive(REDIS_CONNECTION_KEEPALIVE_TIMEOUT, REDIS_CONNECTION_KEEPALIVE_POOL_SIZE)
    end
    return res
end


--@function extracts substring with token from a "Bearer" formatted string from the authorization header
--@param nginx NGINX object
--@return string with jwt token
local function extract_token_from_authorization_header(nginx)
    local authorization_string = nginx.req.get_headers()["authorization"]
    local _, _, token = string.find(
            authorization_string or '',
            "Bearer%s+(.+)"
    )
    return token
end


--@function Raw method to verify that authorization token is not in blacklist
--@param nginx NGINX object
local function raw_check_blacklist(nginx)
    -- check if the current valid token is in blacklist (redis is used to keep blacklist)
    local token = extract_token_from_authorization_header(nginx)

    if token == nil then
        nginx.log(nginx.NOTICE, "There is no token in headers. Skipping redis checking...")
        return
    end

    local token_blacklisted = get_token_from_redis(nginx, token)

    if token_blacklisted == nil or token_blacklisted == nginx.null then
        nginx.log(nginx.NOTICE, "Token is not blacklisted. Check passed.")
        return
    else
        nginx.log(nginx.NOTICE, "Token ", token, " is blocked. Returning error...")
        return nginx.exit(nginx.HTTP_UNAUTHORIZED)
    end
end



--@function method to verify that authorization token is not in blacklist
-- nginx object is guessed from the global scope
local function check_blacklist()
    return _M.raw_check_blacklist(ngx)
end

_M.check_blacklist = check_blacklist
_M.raw_check_blacklist = raw_check_blacklist

return _M
