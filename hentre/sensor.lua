require "sensor_cfg"

--get flow from i2c meter sensor
--input: treated_flag[boolean]- if is true, will config flow to treatedflow and config tds to tdstreated
--                              if is false, config flow to untreatedflow and config tds to tdsuntreated
--return:   ret- true if read success, or false
--          temp- read value[0]<<8|value[1]
--          tds-  tds read from i2c sensor
--          speed- flow speed
--          peak-  flow peak
--          flow-  flow count
function read_i2c_sensor(treated_flag)
    local ret = true
    local read_value = ""
    local temp = 0
    local tds = 0
    local speed = 0
    local peak = 0
    local flow = 0

    if system_config.USE_I2C_FLOW_METER == 0 then
        printf("invalid to call read_i2c_sensor, system_config.USE_I2C_FLOW_METER==0")
        return false, 0, 0, 0, 0, 0
    end

    if (type(treated_flag) ~= "boolean") then
        printf("invalid para=" .. tostring(treated_flag))
        return false
    end

    I2c_StartCondition()
    if (I2c_WriteByte(SLAVE_ADDRESS + 1) == 0) then --write ok
        delay(50)
        for i = 1, 18 do
            if (i == 18) then
                --table.insert( read_value,I2c_ReadByte(I2C_ACK_NAK.NO_ACK))
                read_value = read_value .. string.char(I2c_ReadByte(I2C_ACK_NAK.NO_ACK))
            else
                --table.insert( read_value,I2c_ReadByte(I2C_ACK_NAK.ACK))
                read_value = read_value .. string.char(I2c_ReadByte(I2C_ACK_NAK.ACK))
            end
        end
    else
        printf("i2c write address fail")
        ret = false
    end
    I2c_StopCondition()

    if (ret) then
        printf("read i2c sensor len=" .. #read_value .. ",value=")
        local value_show = ""
        for i = 1, #read_value do
            local v = string.byte(read_value, i)
            --printf("["..i.."]="..string.format( "%02x",v))
            value_show = value_show .. string.format("%02x ", v)
        end
        printf(value_show)

        local sensor_crc = 0
        local right_crc = 0
        sensor_crc = string.byte(string.sub(read_value, -2, -2)) --crc high
        sensor_crc = bit.lshift(sensor_crc, 8)
        sensor_crc = sensor_crc + string.byte(string.sub(read_value, -1, -1)) --crc low
        right_crc = network.get_sensor_msg_crc(string.sub(read_value, 1, -3))

        if (sensor_crc == right_crc) then
            printf("sensor data crc valid")

            temp = bit.lshift(string.byte(read_value, 1), 8)
            temp = bit.bor(temp, string.byte(read_value, 2))
            printf("temp=" .. string.format("0x%04x", temp)) --temp=read_value[1]<8|read_value[2]

            tds = string.byte(read_value, 3)
            tds = bit.lshift(tds, 8)
            tds = bit.bor(tds, string.byte(read_value, 4))
            tds = bit.lshift(tds, 8)
            tds = bit.bor(tds, string.byte(read_value, 5))
            tds = bit.lshift(tds, 8)
            tds = bit.bor(tds, string.byte(read_value, 6))
            printf("tds=" .. string.format("0x%08x", tds))

            speed = string.byte(read_value, 7)
            speed = bit.lshift(speed, 8)
            speed = bit.bor(speed, string.byte(read_value, 8))
            printf("speed=" .. string.format("0x%04x", speed))

            peak = string.byte(read_value, 9)
            peak = bit.lshift(peak, 8)
            peak = bit.bor(peak, string.byte(read_value, 10))
            printf("peak=" .. string.format("0x%04x", peak))

            flow = string.byte(read_value, 11)
            flow = bit.lshift(flow, 8)
            flow = bit.bor(flow, string.byte(read_value, 12))
            printf("flow=" .. string.format("0x%04x", flow))

            --config device manager work data field
            printf("config devcie work data fields")

            device_manager.set_device_work_data("temp", temp)

            if (treated_flag) then
                device_manager.set_device_work_data("tdsTreated", tds)
            else
                device_manager.set_device_work_data("tdsUntreated", tds)
            end

            device_manager.set_device_work_data("velocityTreated", speed)

            device_manager.set_device_work_data("peakTreated", peak)

            if (treated_flag) then
                local flowTreated = device_manager.get_device_work_data("flowTreated")
                device_manager.set_device_work_data("flowTreated", flowTreated + flow)
            else
                local flowUntreated = device_manager.get_device_work_data("flowUntreated")
                device_manager.set_device_work_data("flowUntreated", flowUntreated + flow)
            end
        else
            printf(
                "sensor data crc compare fail, sensor_crc=" ..
                    string.format("%x", sensor_crc) .. ",right_crc=" .. string.format("%x", right_crc)
            )
            ret = false
        end
    end

    return ret, temp, tds, speed, peak, flow
end

local app = {
    DISPLAY_DEBUG = function(a, b, c)
        print("DEBUG:", a, b, c)
    end
}
sys.regapp(app)
