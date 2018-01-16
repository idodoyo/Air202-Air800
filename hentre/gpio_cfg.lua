require "pins"
module(..., package.seeall)

local function print(...)
	_G.print("[---HENTRE---]GPIO_CFG",...)
end

gpioKeep = {pin = 29, value = 1, int = nil, callback = nil}
gpioPulse = {pin = 12, value = 1, int = nil, callback = nil}
gpioPulse2 = {pin = 4, value = 1, int = nil, callback = nil}
gpioI2CSda = {pin = 6, value = 1, int = nil, callback = nil}
gpioI2CScl = {pin = 7, value = 1, int = nil, callback = nil}
--LED I/O
gpioLedDio = {pin = 30, value = 1, int = nil, callback = nil}
gpioLedClk = {pin = 31, value = 1, int = nil, callback = nil}
gpioLedStb = {pin = 2, value = 1, int = nil, callback = nil}
--control
gpioPowerCtrl = {pin = 5, value = 1, int = nil, callback = nil}
gpioWaterPressureH = {pin = 10, value = nil, int = nil, callback = nil}
gpioWaterPressureL = {pin = 8, value = nil, int = nil, callback = nil}
userGpioMax = nil
--keys I/O
gpioKeyFlush = nil
gpioBeep = nil
--sensor I/O
gpioLeakDetc = nil
--TDS1
gpioTds1 = nil
gpioTds2 = nil
gpioTdsDetc = nil
--TDS2
gpioTds3 = nil
gpioTds4 = nil
gpioTds2Detc = nil
gpioValveCtrl = nil
gpioGPRSReset = nil
gpioDebugTx = nil
gpioDebugRx = nil
gpioGprsTx = nil
gpioGprsRx = nil
gpioGPRSPower = nil
gpioGPRSColdPower = nil
gpioPurifyWaterCtrl = nil

--pmd.ldoset(5, pmd.LDO_VMMC)
pins.reg(
    gpioKeep,
    gpioPulse,
    gpioPulse2,
    gpioI2CSda,
    gpioI2CScl,
    gpioLedDio,
    gpioLedClk,
    gpioLedStb,
    gpioPowerCtrl,
    gpioWaterPressureH,
    gpioWaterPressureL
)

--[[ local function gpio_init()
    for i,k in pairs(pin.reg) do 
        print('Hentre pin init' .. i ..'pin '.. k )
    end
end ]]

