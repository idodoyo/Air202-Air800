require"user_cfg"

--[[
��ʾģ��
����LED��ʾ����
]]
local app = {
  DISPLAY_DEBUG = function(a,b,c)
    print("DEBUG:", a,b,c)
  end
}
sys.regapp(app)
