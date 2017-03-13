# vim:set ft=perl ts=4 sw=4 et fdm=marker:

use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

worker_connections(1024);
repeat_each(1);

plan tests => repeat_each() * (blocks() * 3 + 0);

my $pwd = cwd();

$ENV{TEST_NGINX_ROOT_PATH} = $pwd;

our $HttpConfig = qq{
    lua_package_path "$pwd/lib/?.lua;;";
};

$ENV{TEST_NGINX_RESOLVER} = '8.8.8.8';

#log_level("warn");
no_long_string();
no_shuffle();

run_tests();


__DATA__

=== TEST 1: redis cluster sentinel
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua_block {
            local redis = require "resty.redis_cluster_sentinel"
            local config = {
                sentinel    = {
                    name    = "master1",
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

            local red_cli = redis:new(config)
            if not red_cli then
                return
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
--- request
GET /t
--- response_body
OK
2
1
--- no_error_log
[error]



