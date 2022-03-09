local guard = require "guardjwt"
local validators = require "resty.jwt-validators"
local blacklist = require "echo-redis-blacklist"
local secret = os.getenv("JWT_SECRET_KEY")

local ngx = require "ngx"
local _M = { _VERSION = '0.0.1' }


--@function apply verification rules for current request:
-- - validate jwt
-- - validate jwt content
-- - check tokens blacklist IF REQUESTED
-- - clear authorization header to reduce a size of transmitted data for backends
--@param nginx NGINX object
local function raw_verify_jwt_and_map_and_blacklist(nginx, use_blacklist)
    -- validate jwt token

    guard.GuardJWT.raw_verify_and_map(
            nginx,
            {
                username = {
                    validators = validators.required(),
                    header = "X-HTTP-USERNAME"
                },
                role = {
                    validators = validators.required(),
                    header = "X-HTTP-ROLE"
                },
                org = {
                    validators = validators.required(),
                    header = "X-HTTP-ORGANIZATION"
                },
                exp = {
                    validators = validators.chain(
                            validators.required(),
                            validators.is_not_expired()  -- exp+LEEWAY < now , see nginx.conf for the LEEWAY setup info
                    )
                }
                --[[,
                sub = {
                    validators = validators.chain(
                            validators.required(),
                            validators.equals("access")  -- only access token is been allowed
                    )
                }
                --]]
            },
            {
                secret = secret,
                clear_authorization_header = false,  -- we need it for blacklist
                is_token_mandatory = true
            }
    )
    if use_blacklist then
        nginx.log(nginx.NOTICE, "Token blacklisted checking...")
        -- check if the current valid token is in blacklist (redis is used to keep blacklist)
        blacklist.check_blacklist()
    end
    -- do not resend an authorization header to the backends, clear it manually here
    nginx.req.clear_header("authorization")
end


--@function apply verification rules for current request:
--@param nginx NGINX object
local function raw_protect(nginx)
    local use_blacklist = false
    raw_verify_jwt_and_map_and_blacklist(nginx, use_blacklist)
end

--@function raw_protect_with_blacklist
-- - check tokens blacklist
-- - apply verification rules for current request
--@param nginx NGINX object
local function raw_protect_with_check_blacklist(nginx)
    local use_blacklist = true
    raw_verify_jwt_and_map_and_blacklist(nginx, use_blacklist)
end


--@function apply verification rules for current request:
-- - validate jwt
-- - validate jwt content
-- - check tokens blacklist
-- - clear authorization header to reduce a size of transmitted data for backends
-- nginx object is guessed from the global scope
local function protect()
    raw_protect(ngx)
end


--@function apply verification rules for current request:
-- - check tokens blacklist
-- - apply verification rules for current request
-- nginx object is guessed from the global scope
local function protect_with_check_blacklist()
    raw_protect_with_check_blacklist(ngx)
end


_M.raw_protect = raw_protect
_M.protect = protect
_M.raw_protect_with_check_blacklist = raw_protect_with_check_blacklist
_M.protect_with_check_blacklist = protect_with_check_blacklist

return _M