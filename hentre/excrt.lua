require"misc"

--[[
��Ϣ·��
����ϵͳ��Ϣ����·��ת������Ӧ��ҵ�����
]]
local app = {
  DEBUG = function(a,b,c)
    print("DEBUG:", a,b,c)
    --������ҵ�����ת����Ϣ
    --sys.dispatch("DEVICE_MANAGER_DEBUG", a,b,c)
    --sys.dispatch("DISPLAY_DEBUG", a,b,c)
    --sys.dispatch("NETWORK_DEBUG", a,b,c)
  end,
  -- ����׼����
  IMEI_READY = function()
    sys.dispatch("NETWORK_IMEI_READY", misc.getimei())
  end,
}
sys.regapp(app)
