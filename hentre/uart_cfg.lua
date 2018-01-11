local uart_id = nil
local uart1_task
local cache_data = ""
local uart1_read_data = ""
local event_cnt = 0

local function read_line()
    while true do
        local s = uart.read(uart_id, "*l")
        if s ~= "" then
            return s
        end
        coroutine.yield()
    end
end

local function uart1_rcv_loop()
    printf("enter uart1_rcv_loop")
    while true do
        local new_data = read_line("*l")

        cache_data = cache_data .. new_data

        local line = string.match(cache_data, "(.+\r*\n)")
        if line then
            printf("in uart1_rcv_loop, read line=" .. line)
            uart1_read_data = uart1_read_data .. line
            event_cnt = event_cnt + 1
            cache_data = ""
        end
    end
    printf("exit uart1_rcv_loop!!")
end

--- uart1.setup
-- @param id 串口id
-- @param baudrate 串口波特率
-- @return 无
-- @usage console.setup(1, 115200)
function setup(id, baudrate)
    -- 默认串口1
    uart_id = id or 1
    -- 默认波特率115200
    baudrate = baudrate or 115200
    -- 创建console处理的协程
    uart1_task = coroutine.create(uart1_rcv_loop)
    -- 初始化串口
    uart.setup(uart_id, baudrate, 8, uart.PAR_NONE, uart.STOP_1)
    -- 串口收到数据时唤醒console协程
    uart.on(
        uart_id,
        "receive",
        function()
            coroutine.resume(uart1_task, "receive")
        end
    )
    coroutine.resume(uart1_task)

    printf("uart1 setup, uart_id=" .. uart_id .. ",baudrate=" .. baudrate)
end

--uart send a string
--input: send_str[string]- string send
--return: none
local function uart1_send(send_str)
    uart.write(uart_id, send_str)
end

--try to rcv a uart1 line
--input: none
--return: read_line[string]- a line string read, end with "\r\n", if read success
--        nil- if read fail, timeout
local uart1_timeout = false
local function on_uart1_rcv_timeout()
    uart1_timeout = true
end

local function uart1_rcv(timeout)
    if (type(timeout) ~= "number") then
        return ""
    end

    printf("in uart1_rcv timeout=" .. tostring(timeout))
    sys.timer_start(on_uart1_rcv_timeout, timeout)

    local s = nil
    while true do
        if (uart1_timeout) then
            --printf("in uart1_rcv timeout")
            log.info("Hentre uart1", "in uart1_rcv timeout")
            break
        end
        if (event_cnt > 0) then
            printf(
                "in uart1_rcv, event ok=" ..
                    tostring(event_cnt) ..
                        ',remain="' .. tostring(uart1_read_data) .. '"' .. ",remain len=" .. #uart1_read_data
            )

            --s=string.match(uart1_read_data, "(.+\r*\n)")        --read a line
            local num = string.find(uart1_read_data, "\r*\n", 1)
            num = string.find(uart1_read_data, "\n", num)
            s = string.sub(uart1_read_data, 1, num)

            uart1_read_data = string.gsub(uart1_read_data, s, "") --cut off read line
            event_cnt = event_cnt - 1

            printf(
                "in uart1_rcv rcv ok=" .. s .. ",remaining=" .. uart1_read_data .. ",remain len=" .. #uart1_read_data
            )
            break
        end
        sys.wait(1)
    end

    uart1_timeout = false
    sys.timer_stop(on_uart1_rcv_timeout)

    return s
end

--uart1 transceive
--input: send_str[string] - string to send
--return: nil if rcv nothing, or return actual rcvd string

local function uart_transceive(send_str)
    if (type(send_str) ~= "string") then
        return nil
    end
    if (not uart_id) then
        return nil
    end

    printf("uart_transceive send:" .. send_str .. ",len=" .. #send_str)

    uart1_send(send_str) --send
    local s = uart1_rcv(200) --rcv with timeout=100ms

    printf("uart_transceive rcv:" .. tostring(s) .. ",len=" .. #tostring(s))
    if (s) then
        --log.info("Hentre uart1", "uart_transceive ok="..tostring(s))
        return s
    else
        log.info("Hentre uart1", "uart_transceive error, ret=" .. tostring(s))
        return nil
    end
end

--stm8 led control
--input:    ontime[number]-     unit: ms
--          offtime[number]-    unit: ms
--          repeat_cnt[number]-     perform led cycle with ontime and offtime assigned in this funciton how many times,
--                              if assigned to 0, led cycle para will permanently set
--return: true if perform ok, or false
function led_control(ontime, offtime, repeat_cnt)
    if (type(ontime) ~= "number" or type(offtime) ~= "number" or type(repeat_cnt) ~= "number") then
        return false
    end

    local s = "led "
    s = s .. tostring(ontime, 10)
    s = s .. ","
    s = s .. tostring(offtime, 10)
    s = s .. ","
    s = s .. tostring(repeat_cnt, 10)
    s = s .. "\r\n"

    local ret = uart_transceive(s)
    if (ret) then
        return true
    else
        return false
    end
end

--stm8 beep control
--input: ontime[number] - in a cycle how many time(ms) to beep on
--       offtime[number]- in a cycle how many time(ms) to beep off
--       repeat_cnt[number]- cycle cnt

function beep_control(ontime, offtime, repeat_cnt)
    if (type(ontime) ~= "number" or type(offtime) ~= "number" or type(repeat_cnt) ~= "number") then
        return false
    end

    local s = "beep "
    s = s .. tostring(ontime, 10)
    s = s .. ","
    s = s .. tostring(offtime, 10)
    s = s .. ","
    s = s .. tostring(repeat_cnt, 10)
    s = s .. "\r\n"

    local ret = uart_transceive(s)
    if (ret) then
        return true
    else
        return false
    end
end

--valve control
--input: action[boolean] - true to open valve, false to close valve
--return: true if perform ok, or false

function valve_control(action)
    if (type(action) ~= "boolean") then
        printf("in valve_control para error=" .. tostring(action))
        return false
    end

    local s = "valve "
    if (action) then
        s = s .. "open"
    else
        s = s .. "close"
    end
    s = s .. "\r\n"

    local ret = uart_transceive(s)
    if (ret) then
        return true
    else
        return false
    end
end

--get tds
--input: none
--return: tds_value[number]- tds_value from stm8 if read ok
--        nil- read fail
function get_tds_value()
    local s = "get tds\r\n"

    local ret = uart_transceive(s)
    if (ret) then
        local tds = tonumber(string.match(ret, "%d+"))
        return tds
    else
        return nil
    end
end

--get leak adc value
--input: none
--return: leak_value[number] - leak adc value from stm8 if read ok
--        nil - read fail
function get_leak_value()
    local s = "get leak\r\n"

    local ret = uart_transceive(s)
    if (ret) then
        local tds = tonumber(string.match(ret, "%d+"))
        return tds
    else
        return nil
    end
end

--[[ local function on_wait_event_timeout()
    coroutine.resume(uart1_task, "TIEMOUT")
end

local function wait_event(event, timeout)
    if timeout then
        printf("wait event, timeout="..timeout)
        sys.timer_start(on_wait_event_timeout, timeout)
    end

    while true do
        local receive_event = coroutine.yield()
        if receive_event == event then
            printf("wait_event="..event.." ok")
            sys.timer_stop(on_wait_event_timeout)
            return
        elseif receive_event == "TIMEOUT" then
            --write("WAIT EVENT " .. event .. "TIMEOUT\r\n")
            printf("WAIT EVENT " .. event .. "TIMEOUT\r\n")
            return
        end
    end
end ]]
