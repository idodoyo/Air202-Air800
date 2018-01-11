module(...,package.seeall)

--get register crc16
--input: dev_id(16byte)
--return: crc16(4bytes) if ok, 0 if fail
function get_register_crc16(device_id)
  local input_str=device_id.."HSMR"
  local index=0
  local high=0xff
  local low=0xff
  --length of dev_id is 16
  if(#input_str ~= 20) then 
    printf("get_register_crc16 device_id len err")
    return 0 
  end
  --for (i=0; i<20;i++)  {
  --  int index = low ^ buf[i];
  --  low = high ^ CRC16TABLE_LOW[index];
  --  high = CRC16TABLE_HIGH[index];
  --}
  for i=1,20 do
    index = bit.bxor(low,  string.byte(input_str, i))
    low   = bit.bxor(high, CRC16TABLE_LOW[index+1])
    high  = CRC16TABLE_HIGH[index+1];
  end
  local high1 = int2byte(high)
  local low1 = int2byte(low)
  --local crcresult = ~((low1 << 8) + high1);
  local crcresult = bit.bnot( bit.lshift(low1, 8) + high1 )
  return crcresult
end