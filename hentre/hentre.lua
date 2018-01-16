require "socket"
require "pins"
require "gpio_cfg"

module(..., package.seeall)

local function print(...)
	_G.print("[---HENTRE---]",...)
end

local pin8flg = true
local function pin8set()
    pins.set(pin8flg, gpio_cfg.gpioKeep)
    pin8flg = not pin8flg
end

local app = {
    GPIO_DBG = function(a, b, c)
        print("gpio_dbg", a, b, c)
    end,
    SCKT_DBG = function(a, b, c)
        print("sckt_dbg", a, b, c)
    end,
    DISP_DBG = function(a, b, c)
        print("sckt_dbg", a, b, c)
    end,
    --网络准备好
    IMEI_READY = function()
	    sys.dispatch("SCREEN_IMEI_READY")
        sys.dispatch("DIVCE_STATUS_CHECK") --启动后检查状态
        sys.timer_start(
            function()
                sys.dispatch("MSG_REQ_LBS_LOCATE")
            end,
            10000
        ) --启动10s后开始定位
        sys.timer_start(
            function()
                sys.dispatch("UPLOAD_IMEI_READY")
            end,
            1000
        ) --启动服务器连接
    end,

    sys.timer_loop_start(pin8set, 1000),
    sys.timer_loop_start(
        function()
            sys.dispatch("GPIO_DBG")
        end,
        3000
    ),
    sys.timer_loop_start(
        function()
            sys.dispatch("SCKT_DBG")
        end,
        2000
    )
}

sys.regapp(app)
