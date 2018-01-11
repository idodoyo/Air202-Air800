require"misc"

--[[
消息路由
所有系统消息经此路由转发给相应的业务进程
]]
local app = {
  DEBUG = function(a,b,c)
    print("DEBUG:", a,b,c)
    --向其他业务进程转发消息
    --sys.dispatch("DEVICE_MANAGER_DEBUG", a,b,c)
    --sys.dispatch("DISPLAY_DEBUG", a,b,c)
    --sys.dispatch("NETWORK_DEBUG", a,b,c)
  end,
  -- 卡已准备好
  IMEI_READY = function()
    sys.dispatch("NETWORK_IMEI_READY", misc.getimei())
  end,
}
sys.regapp(app)
