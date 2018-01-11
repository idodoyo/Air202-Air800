module(..., package.seeall)

local function printf(...)
    log.info("Hentre gpio", ...)
end

gpio_config = {
    --purifier controls I/O
    gpioPowerCtrl = {pin = 5, value = 1, int = nil, callback = nil},
    gpioWaterPressureH = {pin = 10, value = nil, int = nil, callback = nil},
    gpioWaterPressureL = {pin = 8, value = nil, int = nil, callback = nil},
    --pulse flow meter
    gpioPulse = {pin = 12, value = 1, int = nil, callback = nil},
    gpioPulse2 = {pin = 4, value = 1, int = nil, callback = nil},
    --i2c flow meter
    gpioI2CSda = {pin = 6, value = 1, int = nil, callback = nil},
    gpioI2CScl = {pin = 7, value = 1, int = nil, callback = nil},
    --LED I/O
    gpioLedDio = {pin = 30, value = 1, int = nil, callback = nil},
    gpioLedClk = {pin = 31, value = 1, int = nil, callback = nil},
    gpioLedStb = {pin = 2, value = 1, int = nil, callback = nil},
    --keep line
    gpioKeep = {pin = 29, value = 1, int = nil, callback = nil},
    userGpioMax = nil,
    --keys I/O
    gpioKeyFlush = nil,
    gpioBeep = nil,
    --sensor I/O
    gpioLeakDetc = nil,
    --TDS1
    gpioTds1 = nil,
    gpioTds2 = nil,
    gpioTdsDetc = nil,
    --TDS2
    gpioTds3 = nil,
    gpioTds4 = nil,
    gpioTds2Detc = nil,
    gpioValveCtrl = nil,
    gpioGPRSReset = nil,
    gpioDebugTx = nil,
    gpioDebugRx = nil,
    gpioGprsTx = nil,
    gpioGprsRx = nil,
    gpioGPRSPower = nil,
    gpioGPRSColdPower = nil,
    gpioPurifyWaterCtrl = nil
}

--init all gpio
--input: none
--return: none
function init_gpio()
    printf("enter init_gpio()")

    for i, v in pairs(gpio_config) do
        if (v and v.pin) then
            v.callback = pins.setup(v.pin, v.value, v.int)
            printf(
                "config " ..
                    i ..
                        " pin=[" ..
                            tostring(v.pin) ..
                                "] " ..
                                    "to value=" ..
                                        tostring(v.value) ..
                                            ",int=" .. tostring(v.int) .. ",callback=" .. tostring(v.callback)
            )
        end
    end
end
