require"_config"

module(...,package.seeall)

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

config = meta_config.create('display_cfg', {
  
})
