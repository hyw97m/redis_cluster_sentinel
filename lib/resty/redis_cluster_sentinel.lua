
local redis = require "resty.redis"
local json_encode   = require("cjson").encode

local ngx_log   = ngx.log
local ERR       = ngx.ERR
local WARN      = ngx.WARN

local null      = ngx.null
local now       = ngx.now

local randomseed= math.randomseed
local random    = math.random


local _M = {}


for cmd, func in pairs(redis) do
    _M[cmd] = function(self, ...)
        if not self.red then
            return nil, "not init redis instance"
        end

        if not self.red[cmd] then
            return nil
        end

        return self.red[cmd](self.red, ...)
    end
end


redis.add_commands("sentinel")


local master = {}


local function _update_master(config)
    local node_count = #config.nodes
    local offset = 0
    if node_count > 1 then
        randomseed(now())
        offset = random(1, 100) % node_count
    end

    local red = redis:new()
    for i = 1, node_count do
        local idx = (i + offset > node_count) and i + offset - node_count or i + offset
        local server = config.nodes[idx]
        local ok, err = red:connect(server.host, server.port)
        if ok then
            local res, err = red:sentinel("get-master-addr-by-name", config.name)
            if res and res ~= null then
                return res[1], res[2]
            end
            red:set_keepalive(config.idle_timeout, config.pool_size)
        else
            ngx_log(WARN, server.host, ":", server.port, ", err", tostring(err))
        end
    end
end


local function _get_master(config)
    if not master[config.name] then
        master[config.name] = {
            expire  = 0,
            ttl     = config.update_ttl,
        }
    end

    local _master = master[config.name]

    local _t = now()
    if _master.expire < _t and not _master.lock then
        _master.lock = true
        local host, port = _update_master(config)
        if host then
            _master.host = host
            _master.port = port
            _master.expire = _t + _master.ttl
        else
            _master.expire = _t + (_master.ttl/10 + 1)
        end

        master[config.name] = _master

        _master.lock = nil
    end

    return _master.host, _master.port
end


function _M.new(self, conf)
    if not conf.sentinel or type(conf.sentinel.nodes) ~= "table" then
        return nil, "not found sentinel config"
    end

    local sentinel_config = {
        name    = conf.sentinel.name or "dev",
        nodes   = conf.sentinel.nodes,
        idle_timeout= conf.sentinel.idle_timeout or 1000,
        pool_size   = conf.sentinel.pool_size or 100,
        update_ttl    = conf.sentinel.update_ttl or 60,
    }

    local host, port = _get_master(sentinel_config)
    if not host then
        return nil, "failed to fetch redis master"
    end

    local config = {
        hos     = host,
        port    = port,
        idle_timeout= conf.server.idle_timeout or 1000,
        pool_size   = conf.server.pool_size or 100,
    }

    local red = redis:new()
    local ok, err = red:connect(host, port)

    if not ok then
        return nil, "failed to init redis instance"
    end

    return setmetatable({ config = config, red = red }, { __index = _M })
end


function _M.set_keepalive(self)
    if self.red then
        local ok, err = self.red:set_keepalive(self.config.idle_timeout, self.config.pool_size)
        if not ok then
            return nil, err
        end
    end

    return true
end


return _M

