#!/bin/sh

SMS_WEBHOOK_CLIENT="/app/hijack/bin/sms_webhook_client"
LUARUN="/system/xbin/luarun"

USSD_XML="/data/userdata/ussd/ussd_cmd_list.xml"
DEFAULT_USSD_FILE="<config>
  <USSD_command>
    <Name>Баланс</Name>
    <Command>*100#</Command>
  </USSD_command>
  <USSD_command>
    <Name>Баланс Билайн</Name>
    <Command>*102#</Command>
  </USSD_command>
  <USSD_command>
    <Name>Баланс Tele2</Name>
    <Command>*105#</Command>
  </USSD_command>
  <USSD_command>
    <Name>Баланс МТС без SMS</Name>
    <Command>#100#</Command>
  </USSD_command>
</config>
"

# these lines are magical, the pooler pools if see them
MAGIC1="text:USSD Sent"
MAGIC2="text:Awaiting the answer"

FORMAT_ALL_SMS='
dm = require("dm")
sys = require("sys")
xml = require("xml")


function print_r (t)
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

function format_sms_read_menu(sms_count)
    sms_count = 500
    print(sms_count)
    for i = 0,sms_count-1,15 do
        print("item:"..(i+1).."-"..math.min(i+15,sms_count)..":SMS_ALL_PAGE_"..(math.floor(i/15)+1))
    end
end

function format_date(d)
    if d == os.date("%Y-%m-%d") then
        return "Today at"
    elseif d == os.date("%Y-%m-%d", os.time()-24*60*60) then
        return "Yesterday at"
    end
    return d
end

function format_sms_page(page, content, webhook_client, prefer_unread)
    local messages = xml.decode(content)["response"]["Messages"]
    local count = tonumber(xml.decode(content)["response"]["Count"])

    if (count == 0) then
        print("text:That was the last SMS")
        return
    end

    message = messages["Message"]

    if prefer_unread == 1 and tonumber(message.Smstat) == 1 then
        print("text:No more unreaded SMS")
        return
    end

    req = "<request><Index>"..message.Index.."</Index></request>"
    cmd = webhook_client.." sms set-read 2 \""..req.."\""
    sys.exec(cmd.." > /dev/null")

    print("text:"..message.Phone)

    message.Date,_ = message.Date:gsub("^(%d%d%d%d%-%d%d%-%d%d)", format_date, 1)
    print("text:"..message.Date)
    print("text:"..message.Content:gsub("[\\r\\n]+", "\\ntext:"))

    if prefer_unread == 1 then
        print("item:<Next>:SMS_UNREAD_READ "..(page))
    else
        print("item:<Next>:SMS_ALL_READ "..(page+1))
    end
    print("item:<Delete>:SMS_DELETE "..message.Index.." "..page.." "..prefer_unread)

end

function format_ussd_page(content)
    local commands = xml.decode(content)["config"]

    for idx,command in pairs(commands) do
        print("text:"..command.Name)
        print("item:"..command.Command..":USSD_SEND "..command.Command)
    end
end

function format_ussd_get(content, try, magic1, magic2)
    local parsed = xml.decode(content)

    if parsed.error ~= nil then
        print(magic1)
        print(magic2)
        if tonumber(try) > 10 then
            print("text:Still waiting :(")
            print("text:Try disabling 4G-only mode")
        end
        print("text:"..string.rep(".", tonumber(try) % 10))
    else
        for line in string.gmatch(parsed.response.content,"[^\\r\\n]+") do
            print("text:"..line)
            local c = string.match(line, "^(%d+)%.")
            if c ~= nil then
                print("item:".. c ..":USSD_SEND "..c)
            end
        end
    end
end

'

get_unread_mesages_count () {
    "$SMS_WEBHOOK_CLIENT" sms sms-count 1 0 | grep LocalUnread | grep -Eo '[0-9]+'
}

get_mesages_count () {
    "$SMS_WEBHOOK_CLIENT" sms sms-count 1 0 | grep LocalInbox | grep -Eo '[0-9]+'
}

remove_newlines () {
    echo "${1//
    /}"
}

format_sms() {
    local PAGE="$1"
    local PREFER_UNREAD="$2"
    local REQUEST="
        <request>
            <PageIndex>$PAGE</PageIndex>
            <ReadCount>1</ReadCount>
            <BoxType>1</BoxType>
            <SortType>0</SortType>
            <Ascending>0</Ascending>
            <UnreadPreferred>$PREFER_UNREAD</UnreadPreferred>
        </request>
    "
    REQUEST="$(remove_newlines "$REQUEST")"

    local XML="$("$SMS_WEBHOOK_CLIENT" sms sms-list 2 "$REQUEST")"
    echo "$FORMAT_ALL_SMS format_sms_page(Argv[1], Argv[2], Argv[3], $PREFER_UNREAD)" | \
         "${LUARUN}" "$PAGE" "$XML" "$SMS_WEBHOOK_CLIENT"
}

if [ "$#" -eq 0 ]; then
    echo "text:SMS:"
    echo "item:New ($(get_unread_mesages_count)):SMS_UNREAD_READ 1"
    echo "item:All ($(get_mesages_count)):SMS_ALL_READ 1"
    echo "text:USSD:"
    echo "item:Send:USSD_LIST"
elif [ "$#" -eq 1 ]; then
    case "$1" in
        SMS_ALL )
            echo "$FORMAT_ALL_SMS format_sms_read_menu(Argv[1])" | "${LUARUN}" "$(get_mesages_count)"
            ;;
        USSD_LIST )
            if [ ! -f "$USSD_XML" ]; then
                echo "$DEFAULT_USSD_FILE" > "$USSD_XML"
                chmod 644 "$USSD_XML"
                chown 1000:1000 "$USSD_XML"
            fi
            USSD="$(cat "$USSD_XML")"
            echo "$FORMAT_ALL_SMS format_ussd_page(Argv[1])" | "${LUARUN}" "$USSD"
            ;;
        USSD_RELEASE )
            "$SMS_WEBHOOK_CLIENT" ussd release 1 0
            ;;
        * )
            echo "text: wrong command mode"
            exit 1
            ;;
    esac

elif [ "$#" -eq 2 ]; then
    case "$1" in
        SMS_ALL_READ )
            PAGE="$2"
            format_sms "$PAGE" 0
            ;;
        SMS_UNREAD_READ )
            PAGE="$2"
            format_sms "$PAGE" 1
            ;;
        USSD_SEND )
            NUM="$2"
            "$SMS_WEBHOOK_CLIENT" ussd send 2 "<request><content>${NUM}</content></request>" | grep -qi OK
            if [ "$?" -eq 0 ]; then
                echo "$MAGIC1"
                echo "$MAGIC2"
            else
                echo "text:Failed"
            fi
            ;;
        USSD_GET )
            TRY_NUM="$2"
            ANS="$("$SMS_WEBHOOK_CLIENT" ussd get 1 0)"

            echo "$FORMAT_ALL_SMS format_ussd_get(Argv[1], Argv[2], Argv[3], Argv[4])" | \
                 "${LUARUN}" "$ANS" "$TRY_NUM" "$MAGIC1" "$MAGIC2"
            ;;
        * )
            echo "text: wrong command mode"
            exit 1
            ;;
    esac
elif [ "$#" -eq 4 ]; then
    case "$1" in
        SMS_DELETE )
            ID="$2"
            PAGE="$3"
            PREFER_UNREAD="$4"

            "$("$SMS_WEBHOOK_CLIENT" sms delete-sms 2 "<request><Index>${ID}</Index></request>")"

            format_sms "$PAGE" "$PREFER_UNREAD"
            ;;
        * )
            echo "text: wrong command mode"
            exit 1
            ;;
    esac
fi
