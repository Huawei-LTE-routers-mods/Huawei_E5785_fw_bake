#!/system/bin/busybox sh

LUARUN="/system/xbin/luarun"

WIFI_COMMON='
dm = require("dm")

function is_wifi_enabled(idx)
    local radio = "InternetGatewayDevice.X_Config.Wifi.Radio."..idx.."."
    local errcode,domain = dm.GetParameterValues(radio, {"Enable"})
    if errcode ~= 0 then
        return -1
    end
    return domain[radio]["Enable"]
end

function at_least_one_wifi_enabled()
    return is_wifi_enabled(1) == 1 or is_wifi_enabled(2) == 1
end

function set_param_with_retry(param, value, retries, command)
    local ret = 1
    for i=0,retries,1 do
        ret = dm.SetParameterValues(param, value)
        if ret ~= 100004 then
            break
        end
        os.execute(command)
    end
    return ret
end


function print_r ( t )
    local print_r_cache={}
    local function sub_print_r(t,indent)
        if (print_r_cache[tostring(t)]) then
            print(indent.."*"..tostring(t))
        else
            print_r_cache[tostring(t)]=true
            if (type(t)=="table") then
                for pos,val in pairs(t) do
                    if (type(val)=="table") then
                        print(indent.."["..pos.."] => "..tostring(t).." {")
                        sub_print_r(val,indent..string.rep(" ",string.len(pos)+8))
                        print(indent..string.rep(" ",string.len(pos)+6).."}")
                    else
                        print(indent.."["..pos.."] => "..tostring(val))
                    end
                end
            else
                print(indent..tostring(t))
            end
        end
    end
    sub_print_r(t,"  ")
end

function sanitize_hostname(hostname)
    local new_hostname, count = hostname:gsub("[^a-zA-Z0-9_ -]", "")
    return new_hostname
end

function format_time(seconds)
    local hours = math.floor(seconds / 3600)
    seconds = seconds % 3600
    local minutes = math.floor(seconds / 60)
    seconds = seconds % 60
    if minutes < 10 then
        minutes = "0" .. minutes
    end
    if seconds < 10 then
        seconds = "0" .. seconds
    end
    return hours .. ":" .. minutes .. ":" .. seconds
end

function find_same_sta(wifi_hosts, mac)
    for k,v in pairs(wifi_hosts) do
        for k1,v1 in pairs(v) do
            if mac == v1 then
                return true
            end
        end
    end
    return false
end

function get_host_AssociatedInfo(wifi_hosts, mac )
    for k,v in pairs(wifi_hosts) do
        if mac == v.MacAddress then
            return v.rssi, v.AssociatedTime
        end
    end
end

function get_hosts_table()
    local wifi_hosts = {}
    local hosts = {}

    local errcode,wifiConf = dm.GetParameterValues("InternetGatewayDevice.X_Config.Wifi.Radio.{i}.", {"Enable"});
    for k,v in pairs(wifiConf) do
        local errcode2,wifissid = dm.GetParameterValues(k.."Ssid.{i}.", {"Enable"})
        for k1,v1 in pairs(wifissid) do
            local errcode3,stainfos = dm.GetParameterValues(k1.."AssociatedDevice.{i}.", {"MACAddress", "StayTime", "Rssi"})
            for k4,v4 in pairs(stainfos) do
                local wifi_host ={}
                wifi_host.MacAddress = v4["MACAddress"]
                wifi_host.AssociatedTime = v4["StayTime"]
                wifi_host.rssi = v4["Rssi"]

                if false == find_same_sta(wifi_hosts, wifi_host.MacAddress) then
                    table.insert(wifi_hosts, wifi_host)
                end
            end
        end
    end

    local errcode,uptime = dm.GetParameterValues("InternetGatewayDevice.DeviceInfo.", {"UpTime"});
    local obj = uptime["InternetGatewayDevice.DeviceInfo."]

    errcode,hostipinfo = dm.GetParameterValues("InternetGatewayDevice.LANDevice.1.Hosts.Host.{i}.",
        {
            "IPAddress",
            "AddressSource",
            "LeaseTimeRemaining",
            "MACAddress",
            "HostName",
            "InterfaceType",
            "Active",
            "LastAccessTime",
            "X_IPv6Address",
            "X_IPv6Active"
        }
    );

    for k,v in pairs(hostipinfo) do
        local Host ={}

        Host.MacAddress = v["MACAddress"]
        Host.HostName = v["HostName"]
        Host.AddressSource = v["AddressSource"]
        Host.InterfaceType = v["InterfaceType"]
        Host.Active = v["Active"]

        if nil == v["LeaseTimeRemaining"] then
            Host.LeaseTime = 0
        else
            Host.LeaseTime = v["LeaseTimeRemaining"]
        end

        if nil == v["IPAddress"] then
            Host.IpAddress = ""
        else
            Host.IpAddress = v["IPAddress"]
        end

        if 1 == v["X_IPv6Active"] then
            Host.Active = 1
            if (nil == Host.IpAddress) or (string.len(Host.IpAddress) == 0) then
                Host.IpAddress = v["X_IPv6Address"]
            else
                Host.IpAddress = Host.IpAddress..";"..v["X_IPv6Address"]
            end
        end

        local Rssi, AssociatedTime = get_host_AssociatedInfo(wifi_hosts, Host.MacAddress)

        if nil == Rssi then
            Host.Rssi = 0
        else
            Host.Rssi = Rssi
            Host.Active = 1
        end

        if nil == AssociatedTime then
            if 1 == Host.Active then
                Host.AssociatedTime = obj["UpTime"] - v["LastAccessTime"]
            else
                Host.AssociatedTime = -1
            end
        else
            Host.AssociatedTime = AssociatedTime
        end

        if "802.11" == Host.InterfaceType or "Wireless" == Host.InterfaceType then
            Host.InterfaceType = "Wireless"
            table.insert(hosts, Host)
        end
    end
    return hosts
end

function get_active_hosts(hosts)
    local ret = {}
    for key, host in pairs(hosts) do
        if host.Active == 1 then
            table.insert(ret, host)
        end
    end
    return ret
end

function get_not_active_hosts(hosts)
    local ret = {}
    for key, host in pairs(hosts) do
        if host.Active ~= 1 then
            table.insert(ret, host)
        end
    end
    return ret
end


function add_default_mac_filter_list(ssidKey)
    ret, count = dm.GetObjNum("InternetGatewayDevice.X_Config.Wifi.Radio.{i}")
    if ret == 0 and count < 10 then
        for i=count+1,10,1 do
            dm.AddObject("InternetGatewayDevice.X_Config.Wifi.Radio.1.Ssid.1.MacFilter.List.")
        end
    end
end

function get_ssid_blocked_mac_info(ssidkey)
    local ban_info = {}

    local errorcode3, macfilter = dm.GetParameterValues(ssidkey.."MacFilter.",{"Enabled", "Policy"})
    if (macfilter[ssidkey.."MacFilter."]["Enabled"] == 0) then
        return ban_info
    else
        if(macfilter[ssidkey.."MacFilter."]["Policy"] == 1) then
            return ban_info  -- white list
        end
    end

    for i=1,10,1 do
        local listkey = ssidkey.."MacFilter.List."..i.."."
        local errcode4, macfilterlist = dm.GetParameterValues(listkey, {"SrcMacAddress","HostName"})
        local Ban = {}

        if nil ~= macfilterlist then
            macfilterlist = macfilterlist[listkey]

            Ban.SrcMacAddress = macfilterlist["SrcMacAddress"]
            Ban.HostName = macfilterlist["HostName"]

            table.insert(ban_info, Ban)
        end
    end
    return ban_info
end

function init_and_get_mac_blocked_info_by_radio(radioindex)
    local ssidkey = "InternetGatewayDevice.X_Config.Wifi.Radio."..radioindex..".Ssid.{i}"
    local errorcode, ssidnum, array = dm.GetObjNum(ssidkey)
    local blocked_info_by_ssid_idx = {}
    for i=1,ssidnum,1 do
        local key = "InternetGatewayDevice.X_Config.Wifi.Radio."..radioindex..".Ssid."..i.."."
        add_default_mac_filter_list(key)
        blocked_info_by_ssid_idx[i] = get_ssid_blocked_mac_info(key)
    end
    return blocked_info_by_ssid_idx
end


function get_ban_lists()
    local blocked_info_by_radio_idx = {}

    local errorcode, radionum, array = dm.GetObjNum("InternetGatewayDevice.X_Config.Wifi.Radio.{i}")
    for i=1,radionum,1 do
        blocked_info_by_radio_idx[i] = init_and_get_mac_blocked_info_by_radio(i)
    end
    return blocked_info_by_radio_idx
end


function get_banned_hosts()
    local banned_hosts = {}

    for radio_idx, blocked_info_by_radio_idx in pairs(get_ban_lists()) do
        for ssid_id, blocked_info_by_ssid_idx in pairs(blocked_info_by_radio_idx) do
            for ban_num, Ban in pairs(blocked_info_by_ssid_idx) do
                if Ban.SrcMacAddress ~= nil and Ban.SrcMacAddress ~= "" then
                    if banned_hosts[Ban.SrcMacAddress] == nil then
                        banned_hosts[Ban.SrcMacAddress] = Ban.HostName
                    else
                        if Ban.HostName ~= nil and Ban.HostName ~= "" then
                            banned_hosts[Ban.SrcMacAddress] = Ban.HostName
                        end
                    end
                end
            end
        end
    end

    return banned_hosts
end


function get_banned_mac_count()
    local banned_macs = get_banned_hosts()
    local count = 0
    for host,name in pairs(banned_macs) do
        count = count + 1
    end
    return count
end

function enable_macfilter(key)
    local fullkey = key.."MacFilter"
    local params = {}
    table.insert(params, {fullkey..".Enabled", 1})
    table.insert(params, {fullkey..".Policy", 0})
    dm.SetParameterValues(params)
end

function ban_on_key_idx(key, idx, mac, hostname)
    local fullkey = key.."MacFilter.List." .. idx

    if hostname == nil then
        hostname = ""
    end
    dm.SetParameterValues(fullkey..".SrcMacAddress", mac)
    dm.SetParameterValues(fullkey..".HostName", sanitize_hostname(hostname))
end

function ban_on_key(key, mac, hostname)
    enable_macfilter(key)
    for idx, ban in pairs(get_ssid_blocked_mac_info(key)) do
        if ban.SrcMacAddress == mac then
            return -- already exists
        end
    end
    for idx, ban in pairs(get_ssid_blocked_mac_info(key)) do
        if ban.SrcMacAddress == nil or ban.SrcMacAddress == "" then
            ban_on_key_idx(key, idx, mac, hostname)
            return
        end
    end
end

function ban_on_radio(radioindex, mac, hostname)
    local ssidkey = "InternetGatewayDevice.X_Config.Wifi.Radio."..radioindex..".Ssid.{i}"
    local errorcode, ssidnum, array = dm.GetObjNum(ssidkey)
    for i=1,ssidnum,1 do
        local key = "InternetGatewayDevice.X_Config.Wifi.Radio."..radioindex..".Ssid."..i.."."
        ban_on_key(key, mac, hostname)
    end
end

function ban(mac)
    local hosts = get_hosts_table()
    local hostname = nil
    for num, host in pairs(hosts) do
        if host.MacAddress == mac then
            hostname = host.HostName
        end
    end

    local errorcode, radionum, array = dm.GetObjNum("InternetGatewayDevice.X_Config.Wifi.Radio.{i}")
    for i=1,radionum,1 do
        ban_on_radio(i, mac, hostname)
    end

    if get_banned_hosts()[mac] ~= nil then
        print("text:Success")
    else
        print("text:Failed")
    end
end

function unban_on_key_idx(key, idx)
    local fullkey = key.."MacFilter.List." .. idx

    dm.SetParameterValues(fullkey..".SrcMacAddress", "")
    dm.SetParameterValues(fullkey..".HostName", "")
end

function unban_on_key(key, mac)
    for idx, ban in pairs(get_ssid_blocked_mac_info(key)) do
        if ban.SrcMacAddress == mac then
            unban_on_key_idx(key, idx)
        end
    end
end

function unban_on_radio(radioindex, mac)
    local ssidkey = "InternetGatewayDevice.X_Config.Wifi.Radio."..radioindex..".Ssid.{i}"
    local errorcode, ssidnum, array = dm.GetObjNum(ssidkey)
    for i=1,ssidnum,1 do
        local key = "InternetGatewayDevice.X_Config.Wifi.Radio."..radioindex..".Ssid."..i.."."
        unban_on_key(key, mac)
    end
end


function unban(mac)
    local errorcode, radionum, array = dm.GetObjNum("InternetGatewayDevice.X_Config.Wifi.Radio.{i}")
    for i=1,radionum,1 do
        unban_on_radio(i, mac)
    end

    if get_banned_hosts()[mac] == nil then
        print("text:Success")
    else
        print("text:Failed")
    end
end

'

WIFI_STATUS='
print("text:Wi-Fi:")
if at_least_one_wifi_enabled() then
    print("item:<On>:WIFI_ON")
    print("item: Off:WIFI_OFF")
else
    print("item: On:WIFI_ON")
    print("item:<Off>:WIFI_OFF")
end

hosts = get_hosts_table()
active_hosts = get_active_hosts(hosts)
not_active_hosts = get_not_active_hosts(hosts)

print("pagebreak:")
print("text:Clients:")
print("item:Active ("..table.getn(active_hosts).."):WIFI_ACTIVE_CLIENTS")
print("item:Old ("..table.getn(not_active_hosts).."):WIFI_NOT_ACTIVE_CLIENTS")
print("item:Banned (".. get_banned_mac_count() .. "):WIFI_BANNED_CLIENTS")
'

WIFI_ON='
set_param_with_retry("InternetGatewayDevice.X_Config.Wifi.Radio.1.Enable", "1", 10, "sleep 1")
set_param_with_retry("InternetGatewayDevice.X_Config.Wifi.Radio.2.Enable", "1", 10, "sleep 1")

if at_least_one_wifi_enabled() then
    print("text: Success")
else
    print("text: Failed")
    print("text: Try to reboot")
end
'

WIFI_OFF='
set_param_with_retry("InternetGatewayDevice.X_Config.Wifi.Radio.1.Enable", "0", 10, "sleep 1")
set_param_with_retry("InternetGatewayDevice.X_Config.Wifi.Radio.2.Enable", "0", 10, "sleep 1")
if at_least_one_wifi_enabled() then
    print("text: Failed")
else
    print("text: Success")
end
'

WIFI_ACTIVE_CLIENTS='
hosts = get_hosts_table()
active_hosts = get_active_hosts(hosts)

for num, host in pairs(active_hosts) do
    print("text:" .. sanitize_hostname(host.HostName))
    print("text:" .. host.IpAddress)
    print("text:" .. host.MacAddress)
    print("text:RSSI: " .. host.Rssi .."dBm")
    print("text:Up: " .. format_time(host.AssociatedTime))
    print("item:<Ban>:BAN_" .. host.MacAddress)
    print("pagebreak:")
end
'

WIFI_NOT_ACTIVE_CLIENTS='
hosts = get_hosts_table()
not_active_hosts = get_not_active_hosts(hosts)

for num, host in pairs(not_active_hosts) do
    print("text:" .. sanitize_hostname(host.HostName))
    print("text:" .. host.IpAddress)
    print("text:" .. host.MacAddress)
    print("text:Left: " .. format_time(host.LeaseTime))
    print("item:<Ban>:BAN_" .. host.MacAddress)
    print("pagebreak:")
end
'

WIFI_BANNED_CLIENTS='
banned_hosts = get_banned_hosts()

for mac, name in pairs(banned_hosts) do
    print("text:" .. sanitize_hostname(name))
    print("text:" .. mac)
    print("item:<Unban>:UNBAN_" .. mac)
    print("pagebreak:")
end
'


if [ "$#" -eq 0 ]; then
    echo "$WIFI_COMMON $WIFI_STATUS" | "${LUARUN}"
fi

if [ "$#" -eq 1 ]; then
    case "$1" in
        WIFI_OFF )
            echo "$WIFI_COMMON $WIFI_OFF" | "${LUARUN}"
            ;;
        WIFI_ON )
            echo "$WIFI_COMMON $WIFI_ON" | "${LUARUN}"
            ;;
        WIFI_ACTIVE_CLIENTS )
            echo "$WIFI_COMMON $WIFI_ACTIVE_CLIENTS" | "${LUARUN}"
            ;;
        WIFI_NOT_ACTIVE_CLIENTS )
            echo "$WIFI_COMMON $WIFI_NOT_ACTIVE_CLIENTS" | "${LUARUN}"
            ;;
        WIFI_BANNED_CLIENTS )
            echo "$WIFI_COMMON $WIFI_BANNED_CLIENTS" | "${LUARUN}"
            ;;
        BAN_[a-fA-F0-9][a-fA-F0-9]:[a-fA-F0-9][a-fA-F0-9]:[a-fA-F0-9][a-fA-F0-9]:[a-fA-F0-9][a-fA-F0-9]:[a-fA-F0-9][a-fA-F0-9]:[a-fA-F0-9][a-fA-F0-9] )
            MAC="${1#BAN_}"
            echo "$WIFI_COMMON ban('$MAC')" | "${LUARUN}"
            ;;
        UNBAN_[a-fA-F0-9][a-fA-F0-9]:[a-fA-F0-9][a-fA-F0-9]:[a-fA-F0-9][a-fA-F0-9]:[a-fA-F0-9][a-fA-F0-9]:[a-fA-F0-9][a-fA-F0-9]:[a-fA-F0-9][a-fA-F0-9] )
            MAC="${1#UNBAN_}"
            echo "$WIFI_COMMON unban('$MAC')" | "${LUARUN}"
            ;;
        * )
            echo "text: wrong command mode"
            exit 1;;
    esac
fi
