
--[[
重载系统函数
]]

-- 重载日志输出函数，在输出内容前加上文件名和行号
_G._print = _G.print
_G.print = function(...)
  _G._print('['..debug.getinfo(2).source..':'..debug.getinfo(2).currentline..']',...)
end
