dm = require('dm')
xml = require("xml")

function trim(s)
   return (s:gsub("^%s*(.-)%s*$", "%1"))
end

encoded_config = trim(xml.decode(FormData.JSONDATA).config)
config = dm.base64Decode(encoded_config)

f = io.open("/data/userdata/ussd/ussd_cmd_list.xml", "wb")
f:write(config)
f:close()
