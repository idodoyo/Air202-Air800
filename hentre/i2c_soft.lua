module(..., package.seeall)

local function printf(...)
    _G.print("Hentre I2C", ...)
end

local _I2C_ERROR = {
    ERROR_NONE = 0x00,
    ERROR_ACK = 0x01,
    ERROR_TIME_OUT = 0x02,
    ERROR_CHECKSUM = 0x04,
    ERROR_UNIT = 0x08
}

local _I2C_ACK_NAK = {
    ACK = 0,
    NO_ACK = 1
}

--local SLAVE_ADDRESS = 0xA8
local I2C_ERROR = system_func.get_read_only_table(_I2C_ERROR)
local I2C_ACK_NAK = system_func.get_read_only_table(_I2C_ACK_NAK)
local SET = 1
local RESET = 0
local sda_is_output = false
local scl_is_output = false

--to set sda to value 1 or 0, return true if ok, or false
local function SDA(set_value)
    pin.set(set_value,gpioI2CSda.pin)
end

--to set scl to value 1 or 0, return true if ok, or false
local function SCL(set_value)
    pins.set(set_value,gpioI2CScl.pin)
end

--to read sda pin, return value 1 or 0 read from sda pin
local function SDARead()
    return pins.get(gpioI2CSda.pin)
end

--to read scl pin, return value 1 or 0 read from scl pin
--[[ local function SCLRead()

    pio.pin.close(gpio.gpio_config.gpioI2CScl.pin)
    --set output dir
    pio.pin.setdir(pio.INPUT, gpio.gpio_config.gpioI2CScl.pin)

    return pio.pin.getval(gpio.gpio_config.gpioI2CScl.pin)

end ]]
local function delay(n)
    n = n * 5
    for i = 1, n do
    end
end

local function I2c_StartCondition()
    SDA(SET)
    SCL(SET)
    delay(1)
    SDA(RESET)
    delay(1) --// hold time start condition (t_HD;STA)
    SCL(RESET)
    delay(1)
end

local function I2c_StopCondition()
    SDA(RESET)
    SCL(RESET)
    delay(1)
    SCL(SET)
    delay(1) --// set-up time stop condition (t_SU;STO)
    SDA(SET)
    delay(1)
end

local function I2c_WriteByte(txByte)
    local error = I2C_ERROR.ERROR_NONE

    for i = 1, 8 do
        local temp = bit.band(0x80, txByte) --msb first
        if (temp ~= 0) then
            SDA(SET)
        else
            SDA(RESET)
        end
        delay(1)
        SCL(SET)
        delay(1)
        SCL(RESET)
        delay(1)
        txByte = bit.lshift(txByte, 1) --left shirft 1 bit
    end

    SDA(SET) --//release SDA-line
    delay(1)
    SCL(SET) --//clk #9 for ack
    delay(1)

    if (SDARead() > 0) then
        error = I2C_ERROR.ERROR_ACK --//check ack from i2c slave
    end

    SCL(RESET)
    delay(1)

    return error
end

local function I2c_ReadByte(ack)
    local rxByte = 0
    
    SDA(SET)
    for i = 1, 8 do
        SCL(SET)
        delay(1)
        if (SDARead() > 0) then
            local temp = bit.rshift(0x80, i - 1)
            rxByte = bit.bor(rxByte, temp)
        end
        SCL(RESET)
        delay(1)
    end

    SDA(ack)
    SCL(SET) --//clk #9 for ack
    delay(1) --//SCL high time (t_SET)
    SCL(RESET)
    SDA(SET) --//release SDA-line
    delay(1)

    return rxByte
end
