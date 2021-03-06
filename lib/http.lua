module(...,package.seeall)

require"common"
require"socket"
local lpack=require"pack"

local sfind,slen,ssub,smatch,sgmatch= string.find,string.len,string.sub,string.match,string.gmatch
--[[
函数名：print
功能  ：打印接口，此文件中的所有打印都会加上test前缀
参数  ：无
返回值：无
]]
local function print(...)
	_G.print("http",...)
end

--http clients存储表
local tclients = {}

--[[
函数名：getclient
功能  ：返回一个http client在tclients中的索引
参数  ：
	  sckidx：http client对应的socket索引
返回值：sckidx对应的http client在tclients中的索引
]]
local function getclient(sckidx)
	for k,v in pairs(tclients) do
		if v.sckidx==sckidx then return k end
	end
end

--[[
函数名：datinactive
功能  ：数据通信异常处理
参数  ：
		sckidx：socket idx
返回值：无
]]
local function datinactive(sckidx)
    sys.restart("SVRNODATA")
end

--[[
函数名：snd
功能  ：调用发送接口发送数据
参数  ：
		sckidx：socket idx
        data：发送的数据，在发送结果事件处理函数ntfy中，会赋值到item.data中
		para：发送的参数，在发送结果事件处理函数ntfy中，会赋值到item.para中 
返回值：调用发送接口的结果（并不是数据发送是否成功的结果，数据发送是否成功的结果在ntfy中的SEND事件中通知），true为成功，其他为失败
]]
function snd(sckidx,data,para)
    return socket.send(sckidx,data,para)
end

local RECONN_MAX_CNT,RECONN_PERIOD,RECONN_CYCLE_MAX_CNT,RECONN_CYCLE_PERIOD = 3,5,3,20

--[[
函数名：reconn
功能  ：socket重连后台处理
        一个连接周期内的动作：如果连接后台失败，会尝试重连，重连间隔为RECONN_PERIOD秒，最多重连RECONN_MAX_CNT次
        如果一个连接周期内都没有连接成功，则等待RECONN_CYCLE_PERIOD秒后，重新发起一个连接周期
        如果连续RECONN_CYCLE_MAX_CNT次的连接周期都没有连接成功，则重启软件
参数  ：
		sckidx：socket idx
返回值：无
]]
function reconn(sckidx)
	local hidx = getclient(sckidx)
	print("reconn",tclients[hidx].sckreconncnt,tclients[hidx].sckconning,tclients[hidx].sckreconncyclecnt)
	--sckconning表示正在尝试连接后台，一定要判断此变量，否则有可能发起不必要的重连，导致sckreconncnt增加，实际的重连次数减少
	if tclients[hidx].sckconning then return end
	--一个连接周期内的重连
	if tclients[hidx].sckreconncnt < RECONN_MAX_CNT then		
		tclients[hidx].sckreconncnt = tclients[hidx].sckreconncnt+1
		socket.disconnect(sckidx,"RECONN")
		tclients[hidx].sckconning = true
	--一个连接周期的重连都失败
	else
		tclients[hidx].sckreconncnt,tclients[hidx].sckreconncyclecnt = 0,tclients[hidx].sckreconncyclecnt+1
		if tclients[hidx].sckreconncyclecnt >= RECONN_CYCLE_MAX_CNT or not tclients[hidx].mode then
			if tclients[hidx].sckerrcb then
				tclients[hidx].sckreconncnt=0
				tclients[hidx].sckreconncyclecnt=0
				tclients[hidx].sckerrcb("CONNECT")
			else
				sys.restart("connect fail")
			end
		else
			link.shut()
		end		
	end
end

local function connectitem(hidx)
	connect(tclients[hidx].sckidx,tclients[hidx].prot,tclients[hidx].host,tclients[hidx].port)
end

--[[
函数名：ntfy
功能  ：socket状态的处理函数
参数  ：
        idx：number类型，socket中维护的socket idx，跟调用socket.connect时传入的第一个参数相同，程序可以忽略不处理
        evt：string类型，消息事件类型
		result： bool类型，消息事件结果，true为成功，其他为失败
		item：table类型，{data=,para=}，消息回传的参数和数据，目前只是在SEND类型的事件中用到了此参数，例如调用socket.send时传入的第2个和第3个参数分别为dat和par，则item={data=dat,para=par}
返回值：无
]]
function ntfy(idx,evt,result,item)
	local hidx = getclient(idx)
	print("ntfy",evt,result,item)
	--连接结果（调用socket.connect后的异步事件）
	if evt == "CONNECT" then
		tclients[hidx].sckconning = false
		--连接成功
		if result then
			tclients[hidx].sckconnected=true
			tclients[hidx].sckreconncnt=0
			tclients[hidx].sckreconncyclecnt=0
			--停止重连定时器
			sys.timer_stop(reconn,idx)
			tclients[hidx].connectedcb()
		else
			--RECONN_PERIOD秒后重连
			sys.timer_start(reconn,RECONN_PERIOD*1000,idx)
		end	
	--数据发送结果（调用socket.send后的异步事件）
	elseif evt == "SEND" then
		if not result then
			print("error code")	     	
		end
	--连接被动断开
	elseif evt == "STATE" and result == "CLOSED" then
		tclients[hidx].sckconnected=false
		tclients[hidx].httpconnected=false
		tclients[hidx].sckconning = false
		--长连接时使用
		if tclients[hidx].mode then
			sys.timer_start(connectitem,RECONN_PERIOD*1000,hidx)
		end
	--连接主动断开（调用link.shut后的异步事件）
	elseif evt == "STATE" and result == "SHUTED" then
		tclients[hidx].sckconnected=false
		tclients[hidx].httpconnected=false
		tclients[hidx].sckconning = false
		--长连接时使用
		if tclients[hidx].mode then
			connectitem(hidx)
		end
	--连接主动断开（调用socket.disconnect后的异步事件）
	elseif evt == "DISCONNECT" then
		tclients[hidx].sckconnected=false
		tclients[hidx].httpconnected=false
		tclients[hidx].sckconning = false
		if item=="USER" then
			if tclients[hidx].discb then tclients[hidx].discb(idx) end
			tclients[hidx].discing = false
		end	
	--长连接时使用
		if tclients[hidx].mode or item=="RECONN" then
			connectitem(hidx)
		end
	--连接主动断开并且销毁（调用socket.close后的异步事件）
	elseif evt == "CLOSE" then
		local cb = tclients[hidx].destroycb
		table.remove(tclients,hidx)
		if cb then cb() end
	end
	--其他错误处理，断开数据链路，重新连接
	if smatch((type(result)=="string") and result or "","ERROR") then
		socket.disconnect(idx)
	end
end

local function resetpara(hidx)
	tclients[hidx].statuscode=nil
	tclients[hidx].rcvhead=nil
	tclients[hidx].rcvbody=nil
	tclients[hidx].status=nil
	tclients[hidx].result=nil
	tclients[hidx].filepath,tclients[hidx].filelen=nil
	tclients[hidx].data=""
end

--[[
函数名：timerfnc
功能：当接收数据超时时启动定时器
参数：客户端对应的SOCKER的ID
返回值：
]]
function timerfnc(hidx)
	tclients[hidx].rcvcb(3)
	resetpara(hidx)
end

--[[
函数名：数据接收处理函数
功能：将服务器返回的数据进行处理
参数：idx：客户端所对应的端口ID data：服务器返回的数据
返回值：无
]]
function rcv(idx,data)
	local hidx = getclient(idx)
	--设置一个定时器，时间为30秒
	sys.timer_start(timerfnc,30000,hidx)
	--如果没有数据
	if not data then 
		print("rcv: no data receive")
	--如果存在接收反馈函数
	elseif tclients[hidx].rcvcb then 
		--创建接收数据
		if not tclients[hidx].data then tclients[hidx].data="" end 
		if not (tclients[hidx].filepath and tclients[hidx].status) then tclients[hidx].data=tclients[hidx].data..data end
		local h1,h2 = sfind(tclients[hidx].data,"\r\n\r\n")
		if h1 and h2 then
			--得到状态行和首部，判断状态
			--解析状态行和所有头
			if not tclients[hidx].status then 
				--设置状态参数，如果为真下次就不需要运行此过程
				tclients[hidx].status=true 
				local totil=ssub(tclients[hidx].data,1,h2+1)
				tclients[hidx].statuscode=smatch(totil,"%s(%d+)%s")
				tclients[hidx].contentlen=tonumber(smatch(totil,":%s(%d+)\r\n"),10)
				local total=smatch(totil,"\r\n(.+\r\n)\r\n")
				--判断total是否为空
				if total~="" then	
					if not tclients[hidx].rcvhead then tclients[hidx].rcvhead={} end
					for k,v in sgmatch(total,"(.-):%s(.-)\r\n") do
						if v=="chunked" then
							chunked=true
						end
						tclients[hidx].rcvhead[k]=v
					end
				end
			end
			--如果已经得到首部且存在接收反馈函数
			if	tclients[hidx].rcvhead then
				--是否头部为Transfer-Encoding=chunked，若是则采用的是分块传输编码
				if chunked then
					if sfind(ssub(tclients[hidx].data,h2,-1),"\r\n%s-0%s-\r\n") then
						local chunkedbody = ""
						for k in sgmatch(ssub(tclients[hidx].data,h2+1,-1),"%x-\r\n(.-)\r\n") do
							chunkedbody=chunkedbody..k
						end
						tclients[hidx].rcvbody=chunkedbody
						tclients[hidx].rcvcb(0,tclients[hidx].statuscode,tclients[hidx].rcvhead,tclients[hidx].rcvbody)
						sys.timer_stop(timerfnc,hidx)
						resetpara(hidx)
						chunked=false
					end		
				--存在Content-Length	
				else
					local expectlen = tclients[hidx].contentlen
					if tclients[hidx].filepath then
						local f,result = io.open(tclients[hidx].filepath,tclients[hidx].filelen and "a+" or "wb")
						if tclients[hidx].filelen then
							tclients[hidx].filelen = tclients[hidx].filelen+slen(data)
							f:write(data)
						else
							tclients[hidx].filelen = slen(ssub(tclients[hidx].data,h2+1,-1))
							f:write(ssub(tclients[hidx].data,h2+1,-1))
						end						
						f:close()
						if not (tclients[hidx].filelen < tclients[hidx].contentlen) then
							tclients[hidx].rcvcb(tclients[hidx].filelen==expectlen and 0 or 2,
								tclients[hidx].statuscode,
								tclients[hidx].rcvhead,
								tclients[hidx].filepath)
							sys.timer_stop(timerfnc,hidx)
							resetpara(hidx)
						end	
					else--有实体且实体长度等于实际长度
						local rcvbodylen = slen(ssub(tclients[hidx].data,h2+1,-1))
						if not (rcvbodylen < tclients[hidx].contentlen) then
							tclients[hidx].rcvcb(rcvbodylen==expectlen and 0 or 2,
								tclients[hidx].statuscode,
								tclients[hidx].rcvhead,
								rcvbodylen==expectlen and ssub(tclients[hidx].data,h2+1,-1) or "")
							sys.timer_stop(timerfnc,hidx)
							resetpara(hidx)
						end						
					end								
				end
			--有数据且没接收反馈函数	
			elseif not tclients[hidx].rcvhead	then
				print("no message reback")
			else
				print("rcv",data)
			end
		else 
			print("error data format")
		end
	end
end


--[[
函数名：connect
功能  ：创建到后台服务器的socket连接；
        如果数据网络已经准备好，会理解连接后台；否则，连接请求会被挂起，等数据网络准备就绪后，自动去连接后台
		ntfy：socket状态的处理函数
		rcv：socket接收数据的处理函数
参数  ：
		sckidx：socket idx
		prot：string类型，传输层协议，仅支持"TCP"
		host：string类型，服务器地址，支持域名和IP地址[必选]
		port：number类型，服务器端口[必选]
返回值：无
]]
function connect(sckidx,prot,host,port)
	socket.connect(sckidx,prot,host,port,ntfy,rcv)
	tclients[getclient(sckidx)].sckconning=true
end


--创立元表时所用
local thttp = {}
thttp.__index = thttp

--[[
函数名：create
功能  ：创建一个http client
参数  ：
		prot：string类型，传输层协议，仅支持"TCP"
		host：string类型，服务器地址，支持域名和IP地址[必选]
		port：number类型，服务器端口[必选]
返回值：无
]]
function create(host,port)
	if #tclients>=2 then assert(false,"tclients maxcnt error") return end
	local http_client =
	{
		prot="TCP",
		host=host,
		port=port or 80,		
		sckidx=socket.SCK_MAX_CNT-#tclients-2,
		sckconning=false,
		sckconnected=false,
		sckreconncnt=0,
		sckreconncyclecnt=0,
		httpconnected=false,
		discing=false,
		status=false,
		rcvbody=nil,
		rcvhead={},
		result=nil,
		statuscode=nil,
		contentlen=nil
	}
	setmetatable(http_client,thttp)
	table.insert(tclients,http_client)
	return(http_client)
end

--[[
函数名：connect
功能  ：连接http服务器
参数  ：
        connectedcb:function类型，socket connected 成功回调函数	
		sckerrcb：function类型，socket连接失败的回调函数[可选]
返回值：无
]]
function thttp:connect(connectedcb,sckerrcb)
	self.connectedcb=connectedcb
	self.sckerrcb=sckerrcb
	
	tclients[getclient(self.sckidx)]=self
	
	if self.httpconnected then print("thttp:connect already connected") return end
	if not self.sckconnected then
		connect(self.sckidx,self.prot,self.host,self.port) 
    end
end

--[[
函数名：setconnectionmode
功能：设置连接模式，长连接还是短链接
参数：v，true为长连接，false为短链接
返回：
]]
function thttp:setconnectionmode(v)
	self.mode=v
end

--[[
函数名：disconnect
功能  ：断开一个http client，并且断开socket
参数  ：
		discb：function类型，断开后的回调函数[可选]
返回值：无
]]
function thttp:disconnect(discb)
	print("thttp:disconnect")
	self.discb=discb
	self.discing = true
	socket.disconnect(self.sckidx,"USER")
end

--[[
函数名：destroy
功能  ：销毁一个http client
参数  ：
		destroycb：function类型，mqtt client销毁后的回调函数[可选]
返回值：无
]]
function thttp:destroy(destroycb)
	local k,v
	self.destroycb = destroycb
	for k,v in pairs(tclients) do
		if v.sckidx==self.sckidx then
			socket.close(v.sckidx)
		end
	end
end

 
--[[
函数名：request
功能  ：发送HTTP请求
参数  ：
        cmdtyp：string类型，HTTP的请求方法，"GET"、"POST"或者"HEAD"	
		url：string类型，HTTP请求行中的URL字段
		head：nil、""或者table类型，HTTP的请求头，lib中默认为自动添加Connection和Host请求头
			如果需要添加其他请求头，本参数传入table类型即可，格式为{"head1: value1","head2: value2",...}
        body：nil、""或者string类型，HTTP的请求实体
		rcvcb：function类型，应答实体的数据回调函数
		filepath：string类型，应答实体的数据保存为文件的路径，例如"download.bin"，[可选]
返回值：无
]]
function thttp:request(cmdtyp,url,head,body,rcvcb,filepath)
	local val="" 
	--默认传送方式为"GET"
	self.cmdtyp=cmdtyp or "GET"
	--默认为根目录
	self.url=url or "/"
	--默认实体为空
	self.head={}
	self.body=body or ""
	self.rcvcb=rcvcb
	if filepath then
		self.filepath = (ssub(filepath,1,1)~="/" and "/" or "")..filepath
		if rtos.make_dir and rtos.make_dir("/http_down") then self.filepath = "/http_down"..self.filepath end
	end

	if not head or head=="" or (type(head)=="table" and #head==0) then
		self.head={"Connection: keep-alive", "Host: "..self.host}
		if cmdtyp=="POST" and self.body~="" and self.body~=nil then
			table.insert(self.head,"Content-Length: "..slen(self.body))
		end
	elseif type(head)=="table" and #head>0 then
		local connhead,hosthead,conlen,k,v
		for k,v in pairs(head) do
			if sfind(v,"Connection: ")==1 then connhead = true end
			if sfind(v,"Host: ")==1 then hosthead = true end
			if sfind(v,"Content-Length: ")==1 then conlen = true end
			table.insert(self.head,v)
		end
		if not hosthead then table.insert(self.head,1,"Host: "..self.host) end
		if not connhead then table.insert(self.head,1,"Connection: keep-alive") end
		if not conlen and cmdtyp=="POST" and self.body~="" and self.body~=nil then 
			table.insert(self.head,1,"Content-Length: "..slen(self.body)) 
		end
	else
		assert(false,"head format error")
	end
	
	val=cmdtyp.." "..self.url.." HTTP/1.1"..'\r\n'
	for k,v in pairs(self.head) do
		val=val..v..'\r\n'
	end
	if self.body then 
		val=val.."\r\n"..self.body
	end		
	snd(self.sckidx,val,cmdtyp)	
end

--[[
函数名：getstatus
功能  ：获取HTTP CLIENT的状态
参数  ：无
返回值：HTTP CLIENT的状态，string类型，共3种状态：
		DISCONNECTED：未连接状态
		CONNECTING：连接中状态
		CONNECTED：连接状态
]]
function thttp:getstatus()
	if self.httpconnected then
		return "CONNECTED"
	elseif self.sckconnected or self.sckconning then
		return "CONNECTING"
	elseif self.disconnect then
		return "DISCONNECTED"
	end
end

