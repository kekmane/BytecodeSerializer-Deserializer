local bconstruct = {}

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

function string.flip(str)
	local f = ''
	str:gsub('..', function (cc)
		f = cc..f
	end)
	return f
end
function num2byte(num)
  return string.format('%02X', num)
end
function num2int(num)
  local num = string.format('%02x',num)
  if #num > 8 then return '00000000', error('number too large to be represented by integer') end
  for i=1,8-#num do
    num = '0'..string.upper(num)
  end
  return num:flip()
end

function num2size_t(num)
  local num = string.format('%02x',num)
  if #num > 16 then return '0000000000000000', error('number too large to be represented by size_t') end
  for i=1,16-#num do
    num = '0'..string.upper(num)
  end
  return num:flip()
end

function num2double(x)
  local function grab_byte(v)
    return math.floor(v / 256), string.char(math.mod(math.floor(v), 256))
  end
  local sign = 0
  if x < 0 then sign = 1; x = -x end
  local mantissa, exponent = math.frexp(x)
  if x == 0 then -- zero
    mantissa, exponent = 0, 0
  elseif x == 1/0 then
    mantissa, exponent = 0, 2047
  else
    mantissa = (mantissa * 2 - 1) * math.ldexp(0.5, 53)
    exponent = exponent + 1022
  end
  local v, byte = "" -- convert to bytes
  x = mantissa
  for i = 1,6 do
    x, byte = grab_byte(x); v = v..byte -- 47:0
  end
  x, byte = grab_byte(exponent * 16 + x); v = v..byte -- 55:48
  x, byte = grab_byte(sign * 128 + x); v = v..byte -- 63:56

  return v:tohex()
end


function bconstruct.constructheader(set)
    local HeaderString = '1B4C7561'
    --[[
      set = {
    ['version'] 
		['format'] 
		['endian'] 
		['sizeint']
		['sizesize_t']
		['sizeinst']
		['sizelnum'] 
		['iflag'] 
      }
    ]]
    function a(str)
      HeaderString = HeaderString..str
    end
    a('5100') -- static for our version no use in changing, version and format
    a(num2byte(set['endian']))
    a(num2byte(set['sizeint']))
    a(num2byte(set['sizesize_t']))
    a(num2byte(set['sizeinst']))
    a(num2byte(set['sizelnum']))
    a(num2byte(set['iflag']))

    return HeaderString
    
end

function bconstruct.constructfunction(funcinfo,tog)
local x = math.random()
--[[
  {
  LastLineDefined = 0,
  LineDefined = 0,
  NameLength = 29,
  SourceName = "hi_totheluaaaaaaaa(10+1,nil)\0",
  constants = { "hi_totheluaaaaaaaa\0", 11 },
  constsize = 2,
  instructions = { "05000000", "41400000", "83000001", "1C408001", "1E008000" },
  instsize = 5,
  ismainchunk = true,
  isvararg = 2,
  nparams = 0,
  nups = 0,
  protos = {},
  protosize = 0,
  stacksize = 3
}
]]
  --construct name of source

  local funchex = (not tog and bconstruct.constructheader(funcinfo['header'])) or ''
  function a(x,r)
    funchex = funchex..x
    if nil then print("REASON FOR APPENDATION :"..r.. " APPENDED :"..x) end
  end
  local fi = funcinfo -- for ease

    local function setstring(str)
    a(num2size_t(#str),"STRLGNTEHT")
    a(str:tohex(),"STRNG")
  end
  local NameLength = #fi['SourceName'] or 0
  a(num2size_t(NameLength),"SRCNAMLENGTH")
  a(fi['SourceName']:tohex(),"SRCNAME")
  a(num2int( fi['LineDefined']),"LINEDEFINED")
  a(num2int(fi['LastLineDefined']),"LASTLINEDEINFED")
  a(num2byte(fi['nups']),"NUPS")
  a(num2byte(fi['nparams']),"NPARAMS")
  a(num2byte(fi['isvararg']),"ISVARARG")
  a(num2byte(fi['stacksize']),"STACKSIZE")

  a(num2int(#fi['instructions']),"SIZEINSTRUCTIONS")
  for i,v in pairs(fi['instructions']) do
    a(v,"INSTRUCTION")
  end
  a(num2int(#fi['constants']),"CONSTSIZE")

  for i,v in pairs(fi['constants']) do

    if type(v) == 'string' then
      a(num2byte(4))
      setstring(v,"STRINCONST")
    end
    if type(v) == 'number' then
        a(num2byte(3))
        a(num2double(v),"DOUBLECONST")
    end
    if type(v) == 'table' then
      a(num2byte(0))
    end
    if type(v) == 'boolean' then
      a(num2byte(1))
      a(num2byte((v==true and 1) or (v==false and 0)),'BOOLCONST')
    end
  end
  a(num2int(#fi['protos']),'SIZEPROTO')
  for i,v in pairs(fi['protos']) do
    a(bconstruct.constructfunction(v,true),'NEWFUNC')
  end
  
    a(num2int(#fi['lineinfo']),'LINEINFO')
    for i,v in pairs(fi['lineinfo']) do
      a(num2int(v))
    end
  
  a(num2int(#fi['locals']),'SIZELOCALS')

  for i,v in pairs(fi['locals']) do
    setstring(v.name,'NAME')
    a(num2int(v.StartPc),'STARTPC')
    a(num2int(v.EndPc),'ENDPC')
  end

  a(num2int(#fi['upvals']),"UPVALSIZE")
  for i,v in pairs(fi['upvals']) do
    setstring(v)
  end
  

  return funchex
end


return bconstruct