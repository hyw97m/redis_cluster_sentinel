#   Name

redis哨兵模式api

#   部署

##  redis部署

部署redis, 做好主从关系

具体不做详细说明

##  部署sentinel

配置文件

```
port 26801
daemonize yes
dir "/data1/redis/sentinel"
logfile "26801.log"
sentinel monitor master1 127.0.0.1 6801 1
sentinel down-after-milliseconds master1 500
sentinel failover-timeout master1 1000

sentinel monitor master2 127.0.0.1 6901 1
sentinel down-after-milliseconds master2 500
sentinel failover-timeout master2 1000
```

```
port 26802
daemonize yes
dir "/data1/redis/sentinel"
logfile "26802.log"
sentinel monitor master1 127.0.0.1 6801 1
sentinel down-after-milliseconds master1 500
sentinel failover-timeout master1 1000

sentinel monitor master2 127.0.0.1 6901 1
sentinel down-after-milliseconds master2 500
sentinel failover-timeout master2 1000
```

启动redis哨兵

/usr/local/redis/bin/redis-sentinel 26801.conf

/usr/local/redis/bin/redis-sentinel 26802.conf


#   实例

```
server {
    location /test {
        content_by_lua_block {
            local redis = require "resty.redis_cluster_sentinel"
            local config = {
                sentinel    = {
                    name    = "mymaster",
                    nodes = {
                        {host = "127.0.0.1", port = 26801},
                        {host = "127.0.0.1", port = 26802},
                    },
                    idle_timeout    = 1000,
                    pool_size       = 10,
                    update_ttl      = 10,
                },
                server  ={
                    idle_timeout    = 1000,
                    pool_size       = 10,
                }
            }
            local red_cli, err = redis:new(config)
            if not red_cli then
                reutrn
            end
            local ok, err = red_cli:set("test", 2)
            ngx.say(ok)
            local res, err = red_cli:get("test")
            ngx.say(res)
            local ok, err = red_cli:del("test")
            ngx.say(ok)
            red_cli:set_keepalive()
        }
    }
}
```


#   Method

继承resty.redis, 重写了new及set_keepalive

##  new

`syntax: red, err = redis:new(config)`

##  set_keepalive

`syntax: ok, err = red:set_keepalive()`



