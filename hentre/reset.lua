
--[[
����ϵͳ����
]]

-- ������־������������������ǰ�����ļ������к�
_G._print = _G.print
_G.print = function(...)
  _G._print('['..debug.getinfo(2).source..':'..debug.getinfo(2).currentline..']',...)
end
