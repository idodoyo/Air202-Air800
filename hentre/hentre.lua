require "socket"
require "network_cfg"

module(..., package.seeall)

--server register
--input: dev_id-dev_id to register
--return: true if register ok, or false
local function server_register(dev_id)
    local ret = false
    local s = ""
    --printf("get_register_crc16="..get_register_crc16("8658860364059060"))
    printf("enter server_register")
    ret,
        s =
        socket_transceive(
        string.format(
            "GET /dev/reg?did=%s&crc=%d HTTP/1.1\r\n" .. "Host: %s\n\r\n",
            dev_id,
            get_register_crc16(dev_id),
            system_config.REGISTER_SERVER
        ),
        5000
    )
    printf("socket_transceive ret=", ret)
    --,"s=",s)
    --if transceive ok, decode
    if (ret) then
        ret = server_register_data_decode(s)
    end

    return ret
end

--pack message and send to server
--input: send_str[string]- string to send to server
--return: true - if success or false
local HENTRE_MSG_HEAD_LEN = 38
local HENTRE_MSG_TAIL_LEN = 2
local HENTRE_MSG_START = 0x7e
local HENTRE_MSG_CONTENT_JSON = 0
local function pack_and_send_to_server(send_str)
    local msg_total_len = 0
    local msg_to_send = ""

    if (#sys_config.devID ~= 16 or #sys_config.security ~= 16) or type(send_str) ~= "string" then
        printf(
            "pack_and_send_to_server len of devID or security error,len(devID)=" ..
                #sys_config.devID .. " len(security)=" .. #sys_config.security
        )
        printf("type(send_str)=" .. type(send_str))
        return false
    end

    --msgLen = HENTRE_MSG_HEAD_LEN + len + HENTRE_MSG_TAIL_LEN;
    --memset(msgBuff, 0, msgLen + 1);
    --msgBuff[0] = HENTRE_MSG_START;
    --memcpy(msgBuff + 1, &msgLen, 4);
    --memcpy(msgBuff + 5, getSysContext()->sysConfig.devID, 16);
    --msgBuff[21] = HENTRE_MSG_CONTENT_JSON;
    --memcpy(msgBuff + 22, getSysContext()->sysConfig.security, 16);
    --memcpy(msgBuff + 38, json, len);
    --crc16_msg(msgBuff, msgLen);

    msg_total_len = #send_str + HENTRE_MSG_HEAD_LEN + HENTRE_MSG_TAIL_LEN
    msg_to_send = msg_to_send .. pack.pack("<b1", HENTRE_MSG_START)
    msg_to_send = msg_to_send .. pack.pack("<I1", msg_total_len)
    msg_to_send = msg_to_send .. sys_config.devID
    msg_to_send = msg_to_send .. pack.pack("<b1", HENTRE_MSG_CONTENT_JSON)
    msg_to_send = msg_to_send .. sys_config.security
    msg_to_send = msg_to_send .. send_str
    msg_to_send = msg_to_send .. pack.pack(">H1", get_msg_crc(msg_to_send))
    printf("pack_and_send_to_server total len=" .. msg_total_len .. " len(msg_to_send)=" .. #msg_to_send)
    local temp = ""
    for i = 1, #msg_to_send do
        temp = temp .. string.format("%02X", string.byte(msg_to_send, i))
    end
    printf("msg_to_send=" .. temp)

    --send to server
    local ret = socket_send(msg_to_send)
    if (not ret) then
        printf("pack_and_send_to_server send to server fail")
    end

    return ret
end

local app = {
    DISPLAY_DEBUG = function(a, b, c)
        print("DEBUG:", a, b, c)
    end
}

sys.regapp(app)
