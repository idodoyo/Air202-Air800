require"user_cfg"

--[[
显示模块
处理LED显示请求
]]
local app = {
  DISPLAY_DEBUG = function(a,b,c)
    print("DEBUG:", a,b,c)
  end
}
sys.regapp(app)
