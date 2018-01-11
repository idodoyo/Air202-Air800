require "_config"

module(..., package.seeall)

config =
    meta_config.create(
    "network_cfg",
    {
        REGISTER_METHOD = "GET",
        REGISTER_PROTOCOL = "http://",
        REGISTER_SERVER = "office.hentre.com",
        REGISTER_URL = "/dev/reg",
        REGISTER_PARAMS = {
            did = "",
            crc = ""
        }
    }
)
