
function string.table(str)
	local rt={}
	for i=1,#str do
		table.insert(rt,str:sub(i,i))
	end
	return rt
end

function string.bits(str,bits)
	local num = (type(str) == 'string' and string.byte(str)) or str
	local t=''-- will contain the bits
	for b=bits,1,-1 do
		rest=math.fmod(num,2)
		t=tostring(rest)..t
		num=(num-rest)/2
	end
	if num==0 then return t else return {'Not enough bits to represent this number'}end

	return t
end

function string.fromhex(str)
	return (str:gsub('..', function (cc)
		return string.char(tonumber(cc, 16))
	end))
end

local bytecode = {}


function bytecode.flipendian(str)
	local f = ''
	str:gsub('..', function (cc)
		f = cc..f
	end)
	return f
end


function bytecode.bchex(bc)
	return (bc:gsub('.', function (c)
		return string.format('%02X', string.byte(c))
	end))
end

function bytecode.charbin(bc,bs)
	str = bc
	bits = bs
	local num = (type(str) == 'string' and string.byte(str)) or str
	local t=''-- will contain the bits
	for b=bits,1,-1 do
		rest=math.fmod(num,2)
		t=tostring(rest)..t
		num=(num-rest)/2
	end
	if num==0 then return t else return {'Not enough bits to represent this number'}end

	return t
end

function bytecode.bcbin(bc,n,tog)
	tog = (type(n) == 'boolean' and n) or tog
	n=(type(n) == 'number' and n) or (type(n) == 'boolean' and 8) or 8
	local bintab = (tog and {}) or ''
	for i,v in pairs(bc:table()) do
		if tog == true then
			table.insert(bintab,bytecode.charbin(v,n))
		else
			bintab = bintab..bytecode.charbin(v,n)
		end
	end
	return bintab
end

function bytecode.readHeader(bc)
	local hexheader=(bc:sub(1,8) ~= '1B4C7561' and bytecode.bchex(bc:sub(1,12))) or bc
	local signature = hexheader:sub(1,8)
	if signature ~= '1B4C7561' then
		return {},print('not official lua version')
	end
	local header = {
		['version'] = tonumber(hexheader:sub(9,10))/10;
		['format'] = tonumber(hexheader:sub(11,12),16);
		['endian'] = tonumber(hexheader:sub(13,14),16);
		['sizeint'] = tonumber(hexheader:sub(15,16),16);
		['sizesize_t'] = tonumber(hexheader:sub(17,18),16);
		['sizeinst'] = tonumber(hexheader:sub(19,20),16);
		['sizelnum'] = tonumber(hexheader:sub(21,22),16);
		['iflag'] = tonumber(hexheader:sub(23,24),16);
	}
	return header
		--infotable['format'] = bc:sub()
end

--[[function bytecode.readInstruction(inst) --assuming 32 bits long
	inst = bytecode.flipendian(inst)
	local rawinst = ''
	inst:gsub('..',function(a)
		rawinst = rawinst..string.char(tonumber(a,16)):bits(8)
	end)
	local x =rawinst
	local function ss(a,b) -- kind alike a macro for tonumber(x:sub(a,b),2)
		return tonumber(x:sub(a,b),2)
	end
	local op,a,c,b,bx = ss(-6,-1),ss(-14,-7),ss(-23,-15),ss(-32,-24),ss(-32,-15)
	return {
		['op'] = op;
		['a'] = a;
		['b'] = b;
		['c'] = c;
		['bx'] = bx;
		['sbx'] = bx - 131071;
	}
end]]

function bytecode.parsefloat(fl)
local flraw = fl:fromhex()
local flbits = bytecode.bcbin(flraw)
local first = flbits:sub(1,32)
local sign = (tonumber(first:sub(-32,-32))==1 and true) or false
local exp = (tonumber(first:sub(-31,-21),2))
local frac = tonumber(flbits:sub(-53,-1),2)
frac = frac/2^52
if frac < 1 then
  frac=frac+1
end
--print(frac/2^52)

local num = math.ldexp((sign==false and 1) or -1, exp - 1023) * (frac)
return num
end

function bytecode.parseFunction(instx,HeaderInfo,p)--takes hex, not raw data
	--cut out any variable length portions to not mix up subs
  local inst = instx
  --for ex cut out names of source just to keep it uniform
  local p = p or 1
  local size_t = HeaderInfo['sizesize_t']
	local int = HeaderInfo['sizeint']
  local sizeinst = HeaderInfo['sizeinst']

  local function GetBits()
    local Subbed = inst:sub(p,p+1)
    p=p+2
    return tonumber(Subbed,16)
  end
  local function GetInt()
    local Subbed = bytecode.flipendian(inst:sub(p,p+(int*2)-1))
    p=p+(int*2)
    return tonumber(Subbed,16)
  end
  local function GetSizeT()
    local Subbed = bytecode.flipendian(inst:sub(p,p+(size_t*2)-1))
    p=p+(size_t*2)
    return tonumber(Subbed,16)
  end
  local function GetString()
    local StrSize = GetSizeT()
    local Str = inst:sub(p,p+(StrSize*2)-1)
    p=p+(StrSize*2)
    return Str:fromhex();
  end
  local function GetInstruction()
    local Subbed = (inst:sub(p,p+(sizeinst*2)-1))
    p=p+(sizeinst*2)
    return Subbed
  end

	local SourceInfo = {}
  SourceInfo['header'] = HeaderInfo
  local SrcName,SrcLength = GetString()
	SourceInfo['NameLength'] = SrcLength--lol
	SourceInfo['SourceName'] = SrcName
	SourceInfo['LineDefined'] = GetInt()
	SourceInfo['LastLineDefined'] = GetInt()
	SourceInfo['nups'] = GetBits()
	SourceInfo['nparams'] = GetBits()
	SourceInfo['isvararg'] = GetBits()
	SourceInfo['stacksize'] = GetBits()
  SourceInfo['instsize'] = GetInt();

  --instruction list
  SourceInfo['instructions'] = {}
  for i=1,SourceInfo['instsize'] do
    table.insert(SourceInfo['instructions'],GetInstruction())
  end
  --//--//--//--//--//--//
  --constant list 
  SourceInfo['constsize'] = GetInt();
  SourceInfo['constants'] = {}


  for i = 1,SourceInfo['constsize'] do
    local ConstType = GetBits()
    if ConstType == 4 then--stringconst
      local StringValue,StringSize = GetString()
      table.insert(SourceInfo['constants'],i,StringValue)
    end
    if ConstType == 3 then
      local num = bytecode.parsefloat(bytecode.flipendian(inst:sub(p,p+15)))
      p=p+16
      table.insert(SourceInfo['constants'],i,num)
    end
    if ConstType == 1 then
      local bool = GetBits()
      bool = (bool == 1 and true) or (bool == 0 and false)
      table.insert(SourceInfo['constants'],i,bool)
    end
    if ConstType == 0 then
      table.insert(SourceInfo['constants'],i,{'nil'})
    end
  end


SourceInfo['protos'] = {}
  SourceInfo['protosize'] = GetInt();
  for i = 1,SourceInfo['protosize'] do
    local x,y,z = bytecode.parseFunction(inst,HeaderInfo,p)
    table.insert(SourceInfo['protos'],x)
    p=y
  end


  SourceInfo['sizelineinfo'] = GetInt()
  SourceInfo['lineinfo'] = {}
   for i = 1, SourceInfo['sizelineinfo'] do
    table.insert(SourceInfo['lineinfo'],GetInt())
   end
  SourceInfo['sizelocals'] = GetInt()
SourceInfo['locals'] = {

}
   for i =1, SourceInfo['sizelocals'] do
    local Name,StringSize = GetString()
    local StartPc = GetInt()
    local EndPc = GetInt()
    
    table.insert(SourceInfo['locals'], {
      ['name'] = Name;
      ['StartPc'] = StartPc;
      ['EndPc'] = EndPc;
    })
  end 

  SourceInfo['sizeupval'] =  GetInt();
  
  SourceInfo['upvals']= {}
  for i =1,SourceInfo['sizeupval'] do
    local Str,StrSize = GetString()
    table.insert(SourceInfo['upvals'],Str)
  end
  return SourceInfo, p,inst
  --//--//--//--//--//--//
end


function bytecode.ParseChunk(Chnk)
  local Header = bytecode.readHeader(Chnk)
  return bytecode.parseFunction(Chnk:sub(25),Header)
end
return bytecode
