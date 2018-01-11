module(..., package.seeall)

--[[
创建配置文件对象（仅支持文本和数字）
key: 文件名
default: 缺省配置参数键值对
]]
local USER_DIR_PATH = "/hentre"
local SYS_CONFIG_FILE = USER_DIR_PATH .. "/sys_config.txt"
local SYS_WORK_STATUS_FILE = USER_DIR_PATH .. "/sys_work_status.txt"
local DEV_WORK_DATA_FILE = USER_DIR_PATH .. "/device_work_data.txt"
local DEV_WORK_STATUS_FILE = USER_DIR_PATH .. "/device_work_status.txt"

function create(key, default)
    if key == nil or key == "" then
        return nil
    end
    local _config = default ~= nil and default or {}
    _config._default = loadstring("return " .. utils.toString(_config))()
    _config._key = key
    _config._filename = USER_DIR_PATH .. key .. ".config"
    --从文件载入参数
    _config.load = function(self)
        local file = io.open(self._filename, "r")
        if not file then
            print(self._key .. " config file not existed")
            return {}
        end
        local config = loadstring("return " .. file:read("*all"))()
        file:close()
        return config
    end
    -- 保存参数
    _config.save = function(self)
        local file = io.open(self._filename, "w")
        if not file then
            print(self._key .. " config file can not write now")
            return false
        end
        --print(utils.toString(self))
        file:write(utils.toString(self))
        file:close()
        return true
    end
    -- 设置参数，自动保存文件
    _config.set = function(self, key, value)
        print("----------", key, value)
        self[key] = value
        return self:save() and 1 or 0
    end
    -- 获取参数
    _config.get = function(self, key, default)
        return self[key] and self[key] or default
    end
    --[[从文件中恢复参数]]
    _config.restore = function(self)
        local config = self:load()
        for key, value in pairs(config) do
            self[key] = value
        end
    end
    --[[载入参数缺省值]]
    _config.reset = function(self)
        if self._default then
            local _default = self._default
            for key, value in pairs(_default) do
                --print(key, value)
                self[key] = value
            end
            self:save()
        end
    end
    -- 创建参数对象时自动恢复一次，这样可以在系统重启时自动载入上一次的参数
    _config:restore()
    return _config
end
