module(...,package.seeall)

require"common"
require"socketssl"
local lpack=require"pack"

local sfind,slen,ssub,smatch,sgmatch= string.find,string.len,string.sub,string.match,string.gmatch
--[[
��������print
����  ����ӡ�ӿڣ����ļ��е����д�ӡ�������testǰ׺
����  ����
����ֵ����
]]
local function print(...)
	_G.print("https",...)
end

--http clients�洢��
local tclients = {}

--[[
��������getclient
����  ������һ��http client��tclients�е�����
����  ��
	  sckidx��http client��Ӧ��socket����
����ֵ��sckidx��Ӧ��http client��tclients�е�����
]]
local function getclient(sckidx)
	for k,v in pairs(tclients) do
		if v.sckidx==sckidx then return k end
	end
end

--[[
��������datinactive
����  ������ͨ���쳣����
����  ��
		sckidx��socket idx
����ֵ����
]]
local function datinactive(sckidx)
    sys.restart("SVRNODATA")
end

--[[
��������snd
����  �����÷��ͽӿڷ�������
����  ��
		sckidx��socket idx
        data�����͵����ݣ��ڷ��ͽ���¼�������ntfy�У��ḳֵ��item.data��
		para�����͵Ĳ������ڷ��ͽ���¼�������ntfy�У��ḳֵ��item.para�� 
����ֵ�����÷��ͽӿڵĽ�������������ݷ����Ƿ�ɹ��Ľ�������ݷ����Ƿ�ɹ��Ľ����ntfy�е�SEND�¼���֪ͨ����trueΪ�ɹ�������Ϊʧ��
]]
function snd(sckidx,data,para)
    return socketssl.send(sckidx,data,para)
end

local RECONN_MAX_CNT,RECONN_PERIOD,RECONN_CYCLE_MAX_CNT,RECONN_CYCLE_PERIOD = 3,5,3,20

--[[
��������reconn
����  ��socket������̨����
        һ�����������ڵĶ�����������Ӻ�̨ʧ�ܣ��᳢���������������ΪRECONN_PERIOD�룬�������RECONN_MAX_CNT��
        ���һ�����������ڶ�û�����ӳɹ�����ȴ�RECONN_CYCLE_PERIOD������·���һ����������
        �������RECONN_CYCLE_MAX_CNT�ε��������ڶ�û�����ӳɹ������������
����  ��
		sckidx��socket idx
����ֵ����
]]
function reconn(sckidx)
	local hidx = getclient(sckidx)
	print("reconn",tclients[hidx].sckreconncnt,tclients[hidx].sckconning,tclients[hidx].sckreconncyclecnt)
	--sckconning��ʾ���ڳ������Ӻ�̨��һ��Ҫ�жϴ˱����������п��ܷ��𲻱�Ҫ������������sckreconncnt���ӣ�ʵ�ʵ�������������
	if tclients[hidx].sckconning then return end
	--һ�����������ڵ�����
	if tclients[hidx].sckreconncnt < RECONN_MAX_CNT then		
		tclients[hidx].sckreconncnt = tclients[hidx].sckreconncnt+1
		socketssl.disconnect(sckidx,"RECONN")
		tclients[hidx].sckconning = true
	--һ���������ڵ�������ʧ��
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
			for k,v in pairs(tclients) do
				socketssl.disconnect(v.sckidx,"RECONN")
				v.sckconning = true
			end
			link.shut()
		end		
	end
end

local function connectitem(hidx)
	local item = tclients[hidx]
	connect(item.sckidx,item.prot,item.host,item.port,item.crtconfig)
end

--[[
��������ntfy
����  ��socket״̬�Ĵ�����
����  ��
        idx��number���ͣ�socket��ά����socket idx��������socketssl.connectʱ����ĵ�һ��������ͬ��������Ժ��Բ�����
        evt��string���ͣ���Ϣ�¼�����
		result�� bool���ͣ���Ϣ�¼������trueΪ�ɹ�������Ϊʧ��
		item��table���ͣ�{data=,para=}����Ϣ�ش��Ĳ��������ݣ�Ŀǰֻ����SEND���͵��¼����õ��˴˲������������socketssl.sendʱ����ĵ�2���͵�3�������ֱ�Ϊdat��par����item={data=dat,para=par}
����ֵ����
]]
function ntfy(idx,evt,result,item)
	local hidx = getclient(idx)
	print("ntfy",evt,result,item)
	--���ӽ��������socketssl.connect����첽�¼���
	if evt == "CONNECT" then
		tclients[hidx].sckconning = false
		--���ӳɹ�
		if result then
			tclients[hidx].sckconnected=true
			tclients[hidx].sckreconncnt=0
			tclients[hidx].sckreconncyclecnt=0
			--ֹͣ������ʱ��
			sys.timer_stop(reconn,idx)
			tclients[hidx].connectedcb()
		else
			--RECONN_PERIOD�������
			sys.timer_start(reconn,RECONN_PERIOD*1000,idx)
		end	
	--���ݷ��ͽ��������socketssl.send����첽�¼���
	elseif evt == "SEND" then
		if not result then
			print("error code")	     	
		end
	--���ӱ����Ͽ�
	elseif evt == "STATE" and result == "CLOSED" then
		tclients[hidx].sckconnected=false
		tclients[hidx].httpconnected=false
		tclients[hidx].sckconning = false
		--������ʱʹ��
		if tclients[hidx].mode then
			sys.timer_start(reconn,RECONN_PERIOD*1000,idx)
		end
	--���������Ͽ�������link.shut����첽�¼���
	elseif evt == "STATE" and result == "SHUTED" then
		tclients[hidx].sckconnected=false
		tclients[hidx].httpconnected=false
		tclients[hidx].sckconning = false
		--������ʱʹ��
		if tclients[hidx].mode then
			connectitem(hidx)
		end
	--���������Ͽ�������socketssl.disconnect����첽�¼���
	elseif evt == "DISCONNECT" then
		tclients[hidx].sckconnected=false
		tclients[hidx].httpconnected=false
		tclients[hidx].sckconning = false
		if item=="USER" then
			if tclients[hidx].discb then tclients[hidx].discb(idx) end
			tclients[hidx].discing = false
		end	
	--������ʱʹ��
		if tclients[hidx].mode or item=="RECONN" then
			connectitem(hidx)
		end
	--���������Ͽ��������٣�����socketssl.close����첽�¼���
	elseif evt == "CLOSE" then
		local cb = tclients[hidx].destroycb
		table.remove(tclients,hidx)
		if cb then cb() end
	end
	--�����������Ͽ�������·����������
	if smatch((type(result)=="string") and result or "","ERROR") then
		socketssl.disconnect(idx)
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
��������timerfnc
���ܣ����������ݳ�ʱʱ������ʱ��
�������ͻ��˶�Ӧ��SOCKER��ID
����ֵ��
]]
function timerfnc(hidx)
	tclients[hidx].rcvcb(3)
	resetpara(hidx)
end

--[[
�����������ݽ��մ�����
���ܣ������������ص����ݽ��д���
������idx���ͻ�������Ӧ�Ķ˿�ID data�����������ص�����
����ֵ����
]]
function rcv(idx,data)
	local hidx = getclient(idx)
	--����һ����ʱ����ʱ��Ϊ30��
	sys.timer_start(timerfnc,30000,hidx)
	--���û������
	if not data then 
		print("rcv: no data receive")
	--������ڽ��շ�������
	elseif tclients[hidx].rcvcb then 
		--������������
		if not tclients[hidx].data then tclients[hidx].data="" end 
		if not (tclients[hidx].filepath and tclients[hidx].status) then tclients[hidx].data=tclients[hidx].data..data end
		local h1,h2 = sfind(tclients[hidx].data,"\r\n\r\n")
		if h1 and h2 then
			--�õ�״̬�к��ײ����ж�״̬
			--����״̬�к�����ͷ
			if not tclients[hidx].status then 
				--����״̬���������Ϊ���´ξͲ���Ҫ���д˹���
				tclients[hidx].status=true 
				local totil=ssub(tclients[hidx].data,1,h2+1)
				tclients[hidx].statuscode=smatch(totil,"%s(%d+)%s")
				tclients[hidx].contentlen=tonumber(smatch(totil,":%s(%d+)\r\n"),10)
				local total=smatch(totil,"\r\n(.+\r\n)\r\n")
				--�ж�total�Ƿ�Ϊ��
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
			--����Ѿ��õ��ײ��Ҵ��ڽ��շ�������
			if	tclients[hidx].rcvhead then
				--�Ƿ�ͷ��ΪTransfer-Encoding=chunked����������õ��Ƿֿ鴫�����
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
				--����Content-Length	
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
					else--��ʵ����ʵ�峤�ȵ���ʵ�ʳ���
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
			--��������û���շ�������	
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
��������connect
����  ����������̨��������socket���ӣ�
        ������������Ѿ�׼���ã���������Ӻ�̨��������������ᱻ���𣬵���������׼���������Զ�ȥ���Ӻ�̨
		ntfy��socket״̬�Ĵ�����
		rcv��socket�������ݵĴ�����
����  ��
		sckidx��socket idx
		prot��string���ͣ������Э�飬��֧��"TCP"
		host��string���ͣ���������ַ��֧��������IP��ַ[��ѡ]
		port��number���ͣ��������˿�[��ѡ]
		crtconfig��nil����table���ͣ�{verifysvrcerts={"filepath1","filepath2",...},clientcert="filepath",clientcertpswd="password",clientkey="filepath"}
����ֵ����
]]
function connect(sckidx,prot,host,port,crtconfig)
	socketssl.connect(sckidx,prot,host,port,ntfy,rcv,crtconfig and crtconfig.verifysvrcerts,crtconfig)
	tclients[getclient(sckidx)].sckconning=true
end


--����Ԫ��ʱ����
local thttp = {}
thttp.__index = thttp

--[[
��������create
����  ������һ��http client
����  ��
		prot��string���ͣ������Э�飬��֧��"TCP"
		host��string���ͣ���������ַ��֧��������IP��ַ[��ѡ]
		port��number���ͣ��������˿�[��ѡ]
����ֵ����
]]
function create(host,port)
	if #tclients>=2 then assert(false,"tclients maxcnt error") return end
	local http_client =
	{
		prot="TCP",
		host=host,
		port=port or 443,		
		sckidx=socketssl.SCK_MAX_CNT-#tclients-2,
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
��������configcrt
����  ������֤��
����  ��
		crtconfig��nil����table���ͣ�{verifysvrcerts={"filepath1","filepath2",...},clientcert="filepath",clientcertpswd="password",clientkey="filepath"}
����ֵ���ɹ�����true��ʧ�ܷ���nil
]]
function thttp:configcrt(crtconfig)
	self.crtconfig=crtconfig
	return true
end

--[[
��������connect
����  ������http������
����  ��
        connectedcb:function���ͣ�socket connected �ɹ��ص�����	
		sckerrcb��function���ͣ�socket����ʧ�ܵĻص�����[��ѡ]
����ֵ����
]]
function thttp:connect(connectedcb,sckerrcb)
	self.connectedcb=connectedcb
	self.sckerrcb=sckerrcb
	
	tclients[getclient(self.sckidx)]=self
	
	if self.httpconnected then print("thttp:connect already connected") return end
	if not self.sckconnected then
		connect(self.sckidx,self.prot,self.host,self.port,self.crtconfig) 
    end
end

--[[
��������setconnectionmode
���ܣ���������ģʽ�������ӻ��Ƕ�����
������v��trueΪ�����ӣ�falseΪ������
���أ�
]]
function thttp:setconnectionmode(v)
	self.mode=v
end

--[[
��������disconnect
����  ���Ͽ�һ��http client�����ҶϿ�socket
����  ��
		discb��function���ͣ��Ͽ���Ļص�����[��ѡ]
����ֵ����
]]
function thttp:disconnect(discb)
	print("thttp:disconnect")
	self.discb=discb
	self.discing = true
	socketssl.disconnect(self.sckidx,"USER")
end

--[[
��������destroy
����  ������һ��http client
����  ��
		destroycb��function���ͣ�mqtt client���ٺ�Ļص�����[��ѡ]
����ֵ����
]]
function thttp:destroy(destroycb)
	local k,v
	self.destroycb = destroycb
	for k,v in pairs(tclients) do
		if v.sckidx==self.sckidx then
			socketssl.close(v.sckidx)
		end
	end
end

 
--[[
��������request
����  ������HTTP����
����  ��
        cmdtyp��string���ͣ�HTTP�����󷽷���"GET"��"POST"����"HEAD"	
		url��string���ͣ�HTTP�������е�URL�ֶ�
		head��nil��""����table���ͣ�HTTP������ͷ��lib��Ĭ��Ϊ�Զ����Connection��Host����ͷ
			�����Ҫ�����������ͷ������������table���ͼ��ɣ���ʽΪ{"head1: value1","head2: value2",...}
        body��nil��""����string���ͣ�HTTP������ʵ��
		rcvcb��function���ͣ�Ӧ��ʵ������ݻص�����
		filepath��string���ͣ�Ӧ��ʵ������ݱ���Ϊ�ļ���·��������"download.bin"��[��ѡ]
����ֵ����
]]
function thttp:request(cmdtyp,url,head,body,rcvcb,filepath)
	local val="" 
	--Ĭ�ϴ��ͷ�ʽΪ"GET"
	self.cmdtyp=cmdtyp or "GET"
	--Ĭ��Ϊ��Ŀ¼
	self.url=url or "/"
	--Ĭ��ʵ��Ϊ��
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
��������getstatus
����  ����ȡHTTP CLIENT��״̬
����  ����
����ֵ��HTTP CLIENT��״̬��string���ͣ���3��״̬��
		DISCONNECTED��δ����״̬
		CONNECTING��������״̬
		CONNECTED������״̬
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

