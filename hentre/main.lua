--重要提醒：必须在这个位置定义MODULE_TYPE、PROJECT和VERSION变量
--MODULE_TYPE：模块型号，目前仅支持Air201、Air202、Air800
--PROJECT：ascii string类型，可以随便定义，只要不使用,就行
--VERSION：ascii string类型，如果使用Luat物联云平台固件升级的功能，必须按照"X.X.X"定义，X表示1位数字；否则可随便定义
MODULE_TYPE = "Air202"
PROJECT = "hentre_water"
VERSION = "1.0.0"
require"sys"

require"hentre"

if MODULE_TYPE=="Air201" then
require"wdt"
end

sys.init(0,0)
sys.run()
