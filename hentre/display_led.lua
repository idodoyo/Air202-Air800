require "display_cfg"

module(..., package.seeall)

local DISPLAY_DEFINE = {
    TIM1629A_CMD_DATA_MODE = 0x40,
    TM1629A_CMD_BRT = 0x80,
    TM1629A_CMD_ADDR = 0xC0,
    TM1629A_DATA_AUTO = 0x00,
    TM1629A_DATA_FIXED = 0x04,
    TM1629A_BRT_OFF = 0x00,
    TM1629A_BRT_14_16 = 0x0F
}

local numberData = {0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F}

--delay for display
function delay(cnt)
    --local temp=cnt or 1
    --sys.wait(temp)
    local temp = cnt or 1

    temp = temp
    for i = 1, temp do
    end
end

--send byte to lcm
--input: value[number]: byte to send
--return: none
function send_byte(value)
    if (type(value) ~= "number") then
        printf("display send_byte para error=" .. tostring(value))
        return false
    else
        --printf("led send_byte=0x"..string.format( "%x",value))
    end

    for i = 1, 8 do
        if (bit.isset(value, 0)) then
            pins.set(1,gpio_cfg.gpioLedDio.pin)
        else
            pins.set(0,gpio_cfg.gpioLedDio.pin)
            --pio.pin.setlow(gpio.gpio_config.gpioLedDio.pin)
        end
        pins.set(0,gpio_cfg.gpioLedClk.pin)
        delay()
        pins.set(1,gpio_cfg.gpioLedClk.pin)
        delay()

        value = bit.rshift(value, 1)
    end

    return true
end

--lcm set data mode
--input: mode[number]- TM1629A_DATA_AUTO or TM1629A_DATA_FIXED
--return: none
function set_data_mode(mode)
    if (mode ~= DISPLAY_DEFINE.TM1629A_DATA_AUTO and mode ~= DISPLAY_DEFINE.TM1629A_DATA_FIXED) then
        printf("set_data_mode para error=" .. tostring(mode))
        return false
    end

    local value = bit.bor(DISPLAY_DEFINE.TIM1629A_CMD_DATA_MODE, mode)
    --gpio.gpio_config.gpioLedStb.callback(0)
    pio.pin.setlow(gpio.gpio_config.gpioLedStb.pin)
    delay()
    send_byte(value)
    --gpio.gpio_config.gpioLedStb.callback(1)
    pio.pin.sethigh(gpio.gpio_config.gpioLedStb.pin)
    delay()

    return true
end

--lcm set brightness
--input: bri[number]: TM1629A_BRT_14_16 or TM1629A_BRT_OFF
--return: true if ok, or false

function set_brightness(brt)
    if (brt ~= DISPLAY_DEFINE.TM1629A_BRT_14_16 and brt ~= DISPLAY_DEFINE.TM1629A_BRT_OFF) then
        printf("set_brightness para error=" .. tostring(brt))
        return false
    end

    local value = bit.bor(DISPLAY_DEFINE.TM1629A_CMD_BRT, brt)
    --gpio.gpio_config.gpioLedStb.callback(0)
    pio.pin.setlow(gpio.gpio_config.gpioLedStb.pin)
    delay()
    send_byte(value)
    --gpio.gpio_config.gpioLedStb.callback(1)
    pio.pin.sethigh(gpio.gpio_config.gpioLedStb.pin)
    delay()

    return true
end

function test_display()
    --gpio.gpio_config.gpioLedStb.callback(0)
    pio.pin.setlow(gpio.gpio_config.gpioLedStb.pin)
    send_byte(0xc0)
    for i = 1, 16 do
        send_byte(0xff)
    end
    delay()
    --gpio.gpio_config.gpioLedStb.callback(1)
    pio.pin.sethigh(gpio.gpio_config.gpioLedStb.pin)
    delay()
end

--init display
--input: none
--return: none
function init_display()
    printf("enter init_display")
    set_data_mode(DISPLAY_DEFINE.TM1629A_DATA_AUTO)
    set_brightness(DISPLAY_DEFINE.TM1629A_BRT_14_16)
    test_display()
end

function displayOneBit(displayValue, idx, bitTmp)
    if (type(displayValue) ~= "number" or type(idx) ~= "number" or type(bitTmp) ~= "number") then
        printf(
            "in displayOneBit para displayValue=" ..
                tostring(displayValue) .. ",idx=" .. tostring(idx) .. ",bitTmp=" .. tostring(bitTmp)
        )
        return 0
    end

    return bit.lshift(bit.band(bit.rshift(displayValue, 7 - idx / 2), 0x01), bitTmp)
end

function displayNumber(totalPrf, i, idx)
    if (type(totalPrf) ~= "number" or type(i) ~= "number" or type(idx) ~= "number") then
        printf(
            "in displayNumber para error, totalPrf=" ..
                tostring(totalPrf) .. ",i=" .. tostring(i) .. ",idx=" .. tostring(idx)
        )
        return 0
    end

    local tmpValue = 0
    if (idx % 2 == 0) then
        if (totalPrf > 999) then
            tmpValue = bit.bor(tmpValue, displayOneBit(numberData[9 + 1], idx, i))
            tmpValue = bit.bor(tmpValue, displayOneBit(numberData[9 + 1], idx, i + 1))
            tmpValue = bit.bor(tmpValue, displayOneBit(numberData[9 + 1], idx, i + 2))
        elseif (totalPrf <= 999 and totalPrf >= 100) then
            tmpValue = bit.bor(tmpValue, displayOneBit(numberData[totalPrf / 100 % 10 + 1], idx, i))
            tmpValue = bit.bor(tmpValue, displayOneBit(numberData[totalPrf / 10 % 10 + 1], idx, i + 1))
            tmpValue = bit.bor(tmpValue, displayOneBit(numberData[totalPrf % 10 + 1], idx, i + 2))
        elseif (totalPrf <= 99 and totalPrf >= 10) then
            tmpValue = bit.bor(tmpValue, displayOneBit(0x00, idx, i))
            tmpValue = bit.bor(tmpValue, displayOneBit(numberData[totalPrf / 10 % 10 + 1], idx, i + 1))
            tmpValue = bit.bor(tmpValue, displayOneBit(numberData[totalPrf % 10 + 1], idx, i + 2))
        elseif (totalPrf <= 9 and totalPrf > 0) then
            tmpValue = bit.bor(tmpValue, displayOneBit(0x00, idx, i))
            tmpValue = bit.bor(tmpValue, displayOneBit(0x00, idx, i + 1))
            tmpValue = bit.bor(tmpValue, displayOneBit(numberData[totalPrf % 10 + 1], idx, i + 2))
        elseif (totalPrf <= 0) then
            tmpValue = bit.bor(tmpValue, displayOneBit(0x00, idx, i))
            tmpValue = bit.bor(tmpValue, displayOneBit(0x00, idx, i + 1))
            tmpValue = bit.bor(tmpValue, displayOneBit(numberData[1], idx, i + 2))
        end
    end

    return tmpValue
end

function displaySymbol(tds, money, flowOrtime, literOrton, idx)
    if
        (type(tds) ~= "boolean" or type(money) ~= "boolean" or type(flowOrtime) ~= "boolean" or
            type(literOrton) ~= "boolean" or
            type(idx) ~= "number")
     then
        printf(
            "in displaySymbol para error, tds=" ..
                tostring(tds) ..
                    ",money=" ..
                        tostring(money) ..
                            ",flowoOrtime=" ..
                                tostring(flowOrtime) ..
                                    ",literOrton=" .. tostring(literOrton) .. ",idx=" .. tostring(idx)
        )
        return 0
    end

    local temp = 0

    if (flowOrtime) then
        if (literOrton) then
            if (idx % 2 == 1) then
                temp = bit.bor(temp, displayOneBit(0x20, idx, 1)) --//点亮“升”这个灯
            end
        else
            if (idx % 2 == 0) then
                temp = bit.bor(temp, displayOneBit(0x80, idx, 5)) --//点亮“吨”这个灯
            end
        end
    else
        if (idx % 2 == 1) then
            temp = bit.bor(temp, displayOneBit(0x10, idx, 1)) --//点亮“天”这个灯
        end
    end

    if money and idx % 2 == 0 then
        temp = bit.bor(temp, displayOneBit(0x80, idx, 6)) --//点亮“充值”这个灯
    end

    if idx % 2 == 0 then
        temp = bit.bor(temp, displayOneBit(0x01, idx, 6)) --//点亮“TDS”这个灯
        if tds then
            temp = bit.bor(temp, displayOneBit(0x02, idx, 6)) --//点亮“净水”这个灯
        else
            temp = bit.bor(temp, displayOneBit(0x04, idx, 6)) --//点亮“原水”这个灯
        end
    end

    if idx % 2 == 0 then
        temp = bit.bor(temp, displayOneBit(0x10, idx, 7)) --//点亮“信号标志”这个灯
    end

    return temp
end

function displayRemainTotal(totalPrf, flowOrtime, idx)
    if (type(totalPrf) ~= "number" or type(flowOrtime) ~= "boolean" or type(idx) ~= "number") then
        printf(
            "in displayRemainTotal para error, totalPrf=" ..
                tostring(totalPrf) .. ",flowOrtime=" .. tostring(flowOrtime) .. ",idx=" .. tostring(idx)
        )
        return 0
    end

    --printf("in displayRemainTotal, totalPrf="..tostring(totalPrf)..",flowOrtime="..tostring(flowOrtime)..",idx="..tostring(idx))

    local temp = 0

    if (idx % 2 == 0) then
        if (flowOrtime) then
            if (totalPrf > 999) then
                totalPrf = totalPrf / 10
            else
                temp = bit.bor(temp, displayOneBit(0x80, idx, 4)) --//点亮“小数点”
                if (totalPrf <= 9) then
                    temp = bit.bor(temp, displayOneBit(numberData[1], idx, 4))
                end
            end
        end

        temp = bit.bor(temp, displayNumber(totalPrf, 3, idx))
    end

    return temp
end

function displayGprsRssi(rssiValue, idx)
    if (type(rssiValue) ~= "number" or type(idx) ~= "number") then
        printf("in displayGprsRssi para error, rssiValue=" .. tostring(rssiValue) .. ",idx=" .. tostring(idx))
        return 0
    end

    --printf("in displayGprsRssi, rssiValue="..rssiValue)

    local temp = 0

    if (idx % 2 == 1) then
        if (rssiValue <= 7) then
            temp = bit.bor(temp, displayOneBit(0x00, idx, 0))
        elseif (rssiValue > 7 and rssiValue <= 15) then --弱
            temp = bit.bor(temp, displayOneBit(0x00, idx, 0))
            temp = bit.bor(temp, displayOneBit(0x08, idx, 1))
        elseif (rssiValue > 15 and rssiValue <= 24) then --中
            temp = bit.bor(temp, displayOneBit(0x40, idx, 0))
        elseif (rssiValue > 24 and rssiValue <= 31) then --强
            temp = bit.bor(temp, displayOneBit(0x02, idx, 0))
        end
    end

    return temp
end

local filterdone = false
function displayFilter(life, idx)
    local tempvalue = 0
    local templife = 0

    if (type(life) ~= "table") then
        printf("in displayFilter, para error=" .. tostring(life))
        return 0
    end
    if (table.maxn(life) < 4) then
        printf("in displayFilter, para error maxn of para#1" .. table.maxn(life))
        return 0
    end

    --[[ printf("in displayFilter life=")
  for i,v in pairs(life) do
      printf("life-"..i.."="..v)
  end ]]
    for i = 1, 5 do
        if (i == 1) then
            if (life[1] <= 33) then
                templife = 0x70
            elseif (life[1] > 33 and life[1] <= 66) then
                templife = 0x60
            elseif (life[1] > 66 and life[1] < 100) then
                templife = 0x40
            else
                if (filterdone) then
                    templife = 0x40
                end
            end
            if (idx % 2 == 0) then
                tempvalue = bit.bor(tempvalue, displayOneBit(templife, idx, 6))
            end
        elseif (i == 2) then
            if (life[2] <= 33) then
                templife = 0x0e
            elseif (life[2] > 33 and life[2] <= 66) then
                templife = 0x0c
            elseif (life[2] > 66 and life[2] < 100) then
                templife = 0x08
            else
                if (filterdone) then
                    templife = 0x08
                end
            end
            if (idx % 2 == 0) then
                tempvalue = bit.bor(tempvalue, displayOneBit(templife, idx, 7))
            end
        elseif (i == 3) then
            if (life[3] <= 33) then
                templife = 0xc0
                if (idx % 2 == 1) then
                    tempvalue = bit.bor(tempvalue, displayOneBit(0x01, idx, 0))
                else
                    tempvalue = bit.bor(tempvalue, displayOneBit(templife, idx, 7))
                end
            elseif (life[3] > 33 and life[3] <= 66) then
                templife = 0x80
                if (idx % 2 == 1) then
                    tempvalue = bit.bor(tempvalue, displayOneBit(0x01, idx, 0))
                else
                    tempvalue = bit.bor(tempvalue, displayOneBit(templife, idx, 7))
                end
            elseif (life[3] > 66 and life[3] < 100) then
                templife = 0x01
                if (idx % 2 == 1) then
                    tempvalue = bit.bor(tempvalue, displayOneBit(templife, idx, 0))
                end
            else
                if (filterdone) then
                    templife = 0x01
                end
                if (idx % 2 == 1) then
                    tempvalue = bit.bor(tempvalue, displayOneBit(templife, idx, 0))
                end
            end
        elseif (i == 4) then
            if (life[4] <= 33) then
                templife = 0x38
            elseif (life[4] > 33 and life[4] <= 66) then
                templife = 0x30
            elseif (life[4] > 66 and life[4] < 100) then
                templife = 0x20
            else
                if (filterdone) then
                    templife = 0x20
                end
            end
            if (idx % 2 == 1) then
                tempvalue = bit.bor(tempvalue, displayOneBit(templife, idx, 0))
            end
        elseif (i == 5) then
            if system_config.DEV_FILTER_SUM == 5 and table.maxn(life) >= 5 then
                if (life[5] <= 33) then
                    templife = 0x07
                elseif (life[5] > 33 and life[5] <= 66) then
                    templife = 0x06
                elseif (life[5] > 66 and life[5] < 100) then
                    templife = 0x04
                else
                    if (filterdone) then
                        templife = 0x04
                    end
                end
                if (idx % 2 == 1) then
                    tempvalue = bit.bor(tempvalue, displayOneBit(templife, idx, 1))
                end
            end
        end
    end

    if (idx >= 15) then
        if (filterdone) then
            filterdone = false
        else
            filterdone = true
        end
    end

    return tempvalue
end

function displayState(device_state, idx)
    if (type(device_state) ~= "number" or type(idx) ~= "number") then
        printf("in displayState para error, device_state=" .. tostring(device_state) .. ",idx=" .. tostring(idx))
        return 0
    end

    --printf("in displayState, device_state="..tostring(device_state))

    local tempvalue = 0

    if (idx % 2 == 1) then
        if (device_state == device_manager.DEV_MANAGER_STATE.DEV_WATERMAKE) then --制水
            if (network.get_sys_report_server_status("TANK_EMPTY")) then
                tempvalue = bit.bor(tempvalue, displayOneBit(0x40, idx, 1))
                tempvalue = bit.bor(tempvalue, displayOneBit(0x10, idx, 2))
            else
                tempvalue = bit.bor(tempvalue, displayOneBit(0x40, idx, 1))
                tempvalue = bit.bor(tempvalue, displayOneBit(0x00, idx, 2))
            end
        elseif (device_state == device_manager.DEV_MANAGER_STATE.DEV_WASHING) then --冲洗
            tempvalue = bit.bor(tempvalue, displayOneBit(0x04, idx, 2))
        elseif (device_state == device_manager.DEV_MANAGER_STATE.DEV_WATERFULL) then --满水
            tempvalue = bit.bor(tempvalue, displayOneBit(0x01, idx, 2))
        elseif (device_state == device_manager.DEV_MANAGER_STATE.DEV_WATERSHORTAGE) then --缺水
            tempvalue = bit.bor(tempvalue, displayOneBit(0x10, idx, 2))
        elseif (device_state == device_manager.DEV_MANAGER_STATE.DEV_LOCKED) then --检修
            tempvalue = bit.bor(tempvalue, displayOneBit(0x40, idx, 2))
        elseif
            (device_state == device_manager.DEV_MANAGER_STATE.DEV_PUMPING_WATER or
                device_state == device_manager.DEV_MANAGER_STATE.DEV_MONITORING)
         then
            tempvalue = bit.bor(tempvalue, displayOneBit(0x00, idx, 2))
            tempvalue = bit.bor(tempvalue, displayOneBit(0x00, idx, 1))
        end
    end

    return tempvalue
end

local display_flow_cnt = 0
--local flowortime_bak=false
local flowortime = false
function display(tds_switch)
    if (type(tds_switch) ~= "boolean") then
        printf("in display para error=" .. tostring(tds_switch))
        return
    end

    local tdsTreated = device_manager.get_device_work_data("tdsTreated") / 100
    local tdsDiscount = device_manager.get_device_work_data("tdsDiscount")
    if (tdsDiscount > 0) then
        tdsTreated = tdsTreated * tdsDiscount
    end
    local tdsUntreated = device_manager.get_device_work_data("tdsUntreated") / 100

    local devType = device_manager.get_device_work_data("devType")
    local flowRemaining = device_manager.get_device_work_data("flowRemaining")
    local hoursRemaining = device_manager.get_device_work_data("hoursRemaining")
    local flowTreated = device_manager.get_device_work_data("flowTreated")
    local flowUntreated = device_manager.get_device_work_data("flowUntreated")
    local modeOfLimit = device_manager.get_device_work_data("modeOfLimit")
    local gprs_rssi = network.get_sys_work_status("gprsRssi")
    local filterlife = device_manager.get_device_work_data("filterLife")
    local status = device_manager.get_device_work_status("status")
    local hoursRemaining = device_manager.get_device_work_data("hoursRemaining")

    --local flowortime=false
    local money = false
    local flowshow = 0
    local nLitreOrTon = true
    if (devType == 0) then
        flowshow = (flowTreated + flowUntreated) / 10
        flowortime = true
        money = false
    else
        if (modeOfLimit == device_manager.LIMIT_MODE.LIMIT_FLOW) then
            flowortime = true
            flowshow = flowRemaining / 10
            if (flowshow < 250) then
                money = true
                if (flowshow <= 0) then
                    flowshow = 0
                end
            else
                money = false
            end
        elseif (modeOfLimit == device_manager.LIMIT_MODE.LIMIT_TIME) then
            flowortime = false
            flowshow = hoursRemaining
            if (flowshow < 3) then
                money = true
                if (flowshow <= 0) then
                    flowshow = 0
                    if (status == device_manager.DEV_MANAGER_STATE.DEV_LOCKED) then
                        flowortime = true
                    end
                end
            else
                money = false
            end
        elseif (modeOfLimit == device_manager.LIMIT_MODE.LIMIT_TIME_AND_FLOW) then
            display_flow_cnt = display_flow_cnt + 1
            if (display_flow_cnt >= 24) then --about 10s
                display_flow_cnt = 0
                flowortime = not flowortime
            end

            if ((flowRemaining <= 0 or hoursRemaining <= 0) and status == device_manager.DEV_MANAGER_STATE.DEV_LOCKED) then
                flowortime = true
                flowshow = 0
            else
                if (flowortime) then
                    flowshow = flowRemaining / 10
                    if (flowshow <= 0) then
                        flowshow = 0
                    end
                else
                    flowshow = hoursRemaining
                    if (flowshow <= 0) then
                        flowshow = 0
                    end
                end
            end

            if (flowRemaining < 2500 or hoursRemaining < 3) then
                money = true
            else
                money = false
            end
        else
            flowshow = 0
            flowortime = true
            money = true
        end
    end

    if (flowortime and flowshow > 9999) then
        flowshow = flowshow / 1000
        nLitreOrTon = false
    end

    local temp = 0
    local tds = 0
    local symbol = 0
    local remain = 0
    local rssi = 0
    local filter = 0
    local state = 0
    pio.pin.setlow(gpio.gpio_config.gpioLedStb.pin)
    send_byte(0xc0)
    for i = 1, 16 do
        tds = displayNumber(tds_switch and tdsTreated or tdsUntreated, 0, i - 1)
        symbol = displaySymbol(tds_switch, money, flowortime, nLitreOrTon, i - 1)
        remain = displayRemainTotal(flowshow, flowortime, i - 1)
        rssi = displayGprsRssi(gprs_rssi, i - 1)
        filter = displayFilter(filterlife, i - 1)
        state = displayState(status, i - 1)

        temp = 0
        temp = bit.bor(tds, temp)
        temp = bit.bor(symbol, temp)
        temp = bit.bor(remain, temp)
        temp = bit.bor(rssi, temp)
        temp = bit.bor(filter, temp)
        temp = bit.bor(state, temp)
        send_byte(temp)
    end
    delay()
    pio.pin.sethigh(gpio.gpio_config.gpioLedStb.pin)
    delay()
end

--display task
--input: none
--return: none

function display_task()
    printf("enter display task")

    local bShow = false
    local tdsSelDisplay = true
    local cnt = 0
    local showcnt = 0

    printf(
        "(system_config.DISPLAY_OPT==system_config.GLOBAL_DEFINES.DISPLAY_LED)=" ..
            tostring(system_config.DISPLAY_OPT == system_config.GLOBAL_DEFINES.DISPLAY_LED)
    )

    init_display()
    --display(true)
    while true do
        --task delay
        sys.wait(100)

        --show something
        if system_config.DISPLAY_OPT == system_config.GLOBAL_DEFINES.DISPLAY_LED then
            bShow = true
        else
            showcnt = showcnt + 1
            if (showcnt >= 5) then
                bShow = true
                showcnt = 0
            end
        end
        if (bShow) then
            bShow = false
            display(tdsSelDisplay)
        end

        --counter
        cnt = cnt + 1
        if (cnt % 20 == 0) then
            cnt = 1
            --tdsSelDisplay=not tdsSelDisplay
            printf("display tds sel " .. tostring(tdsSelDisplay))
        end
    end

    printf("exit display task!!!!!")
end

local app = {
    DISPLAY_DEBUG = function(a, b, c)
        print("DEBUG:", a, b, c)
    end
}
sys.regapp(app)
