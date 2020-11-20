local  bytecode = require('bcparse')
local bconst = require('bconstruct')

function string.fromhex(str)
    return (str:gsub('..', function (cc)
        return string.char(tonumber(cc, 16))
    end))
end

function string.tohex(str)
    return (str:gsub('.', function (c)
        return string.format('%02X', string.byte(c))
    end))
end
for i = 1,1000 do
print('\n\n\n\n\n\n\n\n\n')

end

local ParseF = string.dump(loadstring([[
  Your_Code_Here(1,2,3,"hi")
]],'chunkname'))


local hinfo = (bytecode.readHeader(ParseF))
local parsefhex = ParseF:tohex()
local sinfo,x = bytecode.ParseChunk(parsefhex)

--print(inspect(sinfo))
for i,v in pairs(sinfo) do
  print(i,v)
end
