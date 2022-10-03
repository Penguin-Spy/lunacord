--[[
  zlib.lua  zlib implementation in pure Lua 5.4
  Copyright (c)  Penguin_Spy 2022

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all
  copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  SOFTWARE.
]]

local zlib = {}

local byte, char, sub = string.byte, string.char, string.sub

-- [=[ BITSTREAM READING ]=]

--
--- Peeks ahead a number of bits, returns a number containing those bits but does not seek forward in the bit buffer
--- @param stream table     The input data stream state
--- @param bit_count number The number of bits to get
--- @return number #        The buffer/value of requested bits
--
local function peekBits(stream, bit_count)
  -- while the # of bits in the buffer is less than we need,
  while stream.bit_count < bit_count do
    if stream.pos > #stream.buffer then
      error("[zlib-deflate] Unexpected EOF while decompressing")
    end
    -- get new byte, put it to the right (less significant) of current bit buffer
    stream.bits = stream.bits + (byte(stream.buffer, stream.pos) << stream.bit_count)
    -- inc pointer thingys
    stream.pos = stream.pos + 1
    stream.bit_count = stream.bit_count + 8
  end

  -- cut off the least significant bits in the buffer that aren't requested
  return stream.bits & ((1 << bit_count) - 1)
end

--
--- Gets a number of bits, returns a number containing those bits
--- @param stream table     The input data stream state
--- @param bit_count number The number of bits to get
--- @return number #        The buffer/value of requested bits
--
local function getBits(stream, bit_count)
  local bits = peekBits(stream, bit_count)

  -- remove the requested bits from the buffer
  stream.bit_count = stream.bit_count - bit_count
  stream.bits = stream.bits >> bit_count

  return bits
end

--
--- Flushes the buffer until reaching the next byte boundary
--- @param stream table     The input data stream state
--
local function flushToByte(stream)
  stream.bit_count = 0
  stream.bits = 0
end

--[=[ HUFFMAN TREE shenanigans ]=]

--
--- Adds a symbol node to a Huffman tree
--- @param root table       The root node of the Huffman tree
--- @param num_bits number  The number of bits in the code
--- @param code_bits number The bits of the code
--- @param symbol number    The symbol to be put at the end of the tree path
--- @return table #         The `root` parameter, used internally for recursion down the tree
--
local function addNode(root, num_bits, code_bits, symbol)
  root = root or {}

  if num_bits > 0 then -- more bits to read to make the path
    if code_bits & (2 ^ (num_bits - 1)) == 0 then
      root.left = addNode(root.left, num_bits - 1, code_bits, symbol)
    else
      root.right = addNode(root.right, num_bits - 1, code_bits, symbol)
    end
  else -- end of the path
    root.symbol = symbol
  end

  return root
end

--
--- Creates a Huffman tree from a code table \
--- In a code table, the key is the numerical representation of the `symbol` and the value is `{ code_length, code_bits }`
--- @param code_table table The code table
--- @return table # The generated Huffman tree
--
local function createTree(code_table)
  local root = {}

  -- symbol is a number: 0-255 correspond to literal bytes, 256 is end of block, 257-285 are length thingys
  for symbol, code in pairs(code_table) do
    local num_bits, code_bits = table.unpack(code)

    if num_bits > 0 then -- if this symbol is present in the code_table
      addNode(root, num_bits, code_bits, symbol)
    end
  end

  return root
end

-- Generate the Fixed prefix codes Huffman tables
local fixed_ll_tree, fixed_dist_tree
do
  local ll_code = {}
  for i = 0, 143 do
    ll_code[i] = { 8, 48 + i } --          0b00110000  = 48
  end
  for i = 144, 255 do
    ll_code[i] = { 9, 400 + (i - 144) } -- 0b110010000 = 400
  end
  for i = 256, 279 do
    ll_code[i] = { 7, i - 256 } --         0b0000000   = 0
  end
  for i = 280, 287 do
    ll_code[i] = { 8, 192 + (i - 280) } -- 0b11000000  = 192
  end
  fixed_ll_tree = createTree(ll_code)

  local dist_code = {}
  for i = 0, 31 do
    dist_code[i] = { 5, i }
  end
  fixed_dist_tree = createTree(dist_code)
end

-- Generate the LZSS length/distance symbol -> value tables
local length_codes, dist_codes = {}, {}
do
  local symbol, bits, base_value
  local function create_codes(codes, count)
    for i = 0, count - 1 do
      codes[symbol + i] = { bits, base_value }
      base_value = base_value + (2 ^ bits)
    end
    bits = bits + 1
    symbol = symbol + count
  end

  symbol, bits, base_value = 257, 0, 3
  create_codes(length_codes, 8)
  for i = 1, 5 do
    create_codes(length_codes, 4)
  end
  length_codes[285] = { 0, 258 }

  symbol, bits, base_value = 0, 0, 1
  create_codes(dist_codes, 4)
  for i = 1, 13 do
    create_codes(dist_codes, 2)
  end
end

--
--- Create a code table from a list of code lengths
--- @param code_lengths table The table of code lengths, where the key is the symbol & the value is the length of that symbol's code
--- @return table #           The code table
--
local function createCodeTable(code_lengths)
  -- Step 1
  local maxLength = 0
  local bl_count = {}
  for _, length in pairs(code_lengths) do
    maxLength = math.max(maxLength, length)
    bl_count[length] = (bl_count[length] or 0) + 1
  end
  bl_count[0] = 0

  -- Step 2
  local code = 0
  local next_code = {}
  for bits = 1, maxLength + 1 do
    code = (code + (bl_count[bits - 1] or 0)) << 1
    next_code[bits] = code
  end

  -- Step 3
  local code_table = {}
  for n, length in pairs(code_lengths) do
    if length ~= 0 then
      code_table[n] = { length, next_code[length] }
      next_code[length] = next_code[length] + 1
    end
  end

  return code_table
end

--
--- March down a node of a Huffman tree until encountering a symbol
--- @param stream table The input data stream state
--- @param node table   The Huffman table node to use
--- @return number #    Numerical representation of the symbol
--
local function marchNode(stream, node)
  if not node then
    error("[zlib-deflate] Encountered nil while marching huffman tree")
  elseif node.symbol then
    return node.symbol
  end

  if getBits(stream, 1) == 0 then
    return marchNode(stream, node.left)
  else
    return marchNode(stream, node.right)
  end
end

--
--- Decode a stream of data using the provided Huffman tree \
--- The result is put into the `stream.result` string
--- @param stream table    The input data stream state
--- @param ll_tree table   The Literal/Length tree to use
--- @param dist_tree table The distance tree to use
--
local function decodeTree(stream, ll_tree, dist_tree)
  repeat
    local symbol = marchNode(stream, ll_tree)
    if symbol < 256 then -- literal
      stream.result = stream.result .. char(symbol)
    elseif symbol > 256 then -- LZSS yipee
      local length, dist, bits

      -- get length from symbol & extra bits
      bits, length = table.unpack(length_codes[symbol])
      if bits > 0 then
        length = length + getBits(stream, bits)
      end

      -- get distance from symbol & extra bits (using seperate distance code tree)
      symbol = marchNode(stream, dist_tree)
      bits, dist = table.unpack(dist_codes[symbol])
      if bits > 0 then
        dist = dist + getBits(stream, bits)
      end

      local br_start = #stream.result - dist
      local backreference = sub(stream.result, br_start + 1, br_start + length)

      stream.result = stream.result .. backreference
    end
  until symbol == 256
end

--[=[ BLOCK DECOMPRESSORS ]=]

--
--- Block type 0: Store (uncompressed)
--- @param stream table The input data stream state
--- @return boolean #   Returns true if decompression should exit early
--
local function decompressStore(stream)
  flushToByte(stream)
  local length, inverse_length = getBits(stream, 16), getBits(stream, 16) ~ 0x0000ffff

  if not (length == inverse_length) then
    error("[zlib-deflate] Invalid length for block type 0 (" .. length .. " does not match " .. inverse_length .. ")")
  end
  if length == 0 then
    return true -- some implemenations use a block length of 0 bytes (which should not occur) to indicate the current end of a stream of data
  end

  stream.result = stream.result .. sub(stream.buffer, stream.pos, length)
  stream.pos = stream.pos + length
  return false
end

--
--- Block type 1: LZSS + Fixed Codes
--- @param stream table The input data stream state
--
local function decompressFixed(stream)
  decodeTree(stream, fixed_ll_tree, fixed_dist_tree)
end

--
--- Block type 2: LZSS + Dynamic Codes
--- @param stream table The input data stream state
--
local function decompressDynamic(stream)
  -- hlit encodes the number of entries of the LL code table that are specified, minus 257
  -- hdist encodes the number of entries of the Distance code table, minus 1
  -- hclen specifies the number of entries in the CL code that are present, minus 4
  local hlit, hdist, hclen = getBits(stream, 5), getBits(stream, 5), getBits(stream, 4)
  local ll_codes_count = hlit + 257
  local dist_codes_count = hdist + 1

  -- decode Code Length codes --
  local cl_lengths = {}
  for i = 16, 18 do
    cl_lengths[i] = getBits(stream, 3)
  end
  cl_lengths[0] = getBits(stream, 3)

  for i = 1, hclen do
    if i % 2 == 0 then
      cl_lengths[8 - math.floor(i / 2)] = getBits(stream, 3)
    else
      cl_lengths[math.floor(i / 2) + 8] = getBits(stream, 3)
    end
  end
  for i = hclen + 1, 15 do
    cl_lengths[i] = 0
  end

  -- turn lengths of each symbol into bits, then into huffman tree
  local cl_tree = createTree(createCodeTable(cl_lengths))

  -- decode Literal/Length codes & distance codes --
  local ll_lengths = {}
  local dist_lengths = {}
  local i = 0
  repeat
    local symbol = marchNode(stream, cl_tree)
    if symbol <= 15 then -- symbols 0-15 are literal lengths
      if i < ll_codes_count then
        ll_lengths[i] = symbol
      else
        dist_lengths[i - ll_codes_count] = symbol
      end
      i = i + 1
    elseif symbol == 16 then -- repeat previous symbol 3-6 times (next 2 bytes are repeat length)
      local repeats = getBits(stream, 2) + 3
      for j = 0, repeats - 1 do
        if i < ll_codes_count then
          ll_lengths[i + j] = ll_lengths[i - 1]
        else
          dist_lengths[i + j - ll_codes_count] = dist_lengths[i - 1 - ll_codes_count]
        end
      end
      i = i + repeats
    elseif symbol == 17 then -- repeat length 0 for 3-10 times (next 3 bytes)
      local repeats = getBits(stream, 3) + 3
      for j = 0, repeats - 1 do
        if i < ll_codes_count then
          ll_lengths[i + j] = 0
        else
          dist_lengths[i + j - ll_codes_count] = 0
        end
      end
      i = i + repeats
    elseif symbol == 18 then -- repeat length 0 for 11-138 times (next 7 bytes)
      local repeats = getBits(stream, 7) + 11
      for j = 0, repeats - 1 do
        if i < ll_codes_count then
          ll_lengths[i + j] = 0
        else
          dist_lengths[i + j - ll_codes_count] = 0
        end
      end
      i = i + repeats
    end
  until i >= ll_codes_count + dist_codes_count

  local dynamic_ll_table = createTree(createCodeTable(ll_lengths))
  local dynamic_dist_table = createTree(createCodeTable(dist_lengths))

  decodeTree(stream, dynamic_ll_table, dynamic_dist_table)
end

--
--- Inflates a DEFLATE compressed block of data
--- @param stream table The input data stream state
--- @return boolean #   Is this the last block in the stream
--
local function inflateBlock(stream)
  local is_last = getBits(stream, 1) == 1
  local block_type = getBits(stream, 2)

  if block_type == 0 then
    return decompressStore(stream) or is_last
  elseif block_type == 1 then
    decompressFixed(stream)
  elseif block_type == 2 then
    decompressDynamic(stream)
  else
    error("[zlib-deflate] Invalid DEFLATE block type (" .. block_type .. ")")
  end

  return is_last
end

--
--- Decompresses a zlib-deflate block of data. \
--- If an error occurs while decompressing, `error()` is called with an error message.
--- @param data string The compressed data
--- @return string #   The result of the decompression
--
function zlib.decompress(data)
  local stream = {
    buffer = data, --   string, byte buffer
    pos = 1, --         byte position in buffer
    bits = 0, --        bit buffer
    bit_count = 0, --   number of bits in buffer
    result = "" --      decompressed data
  }

  -- Compression Method and flags
  local cmf = peekBits(stream, 8)
  local method, info = getBits(stream, 4), getBits(stream, 4)
  if not (method == 8) then
    error("[zlib] Invalid compression method (" .. method .. ")")
  end
  if info > 7 then
    error("[zlib] Invalid compression info (" .. info .. ")")
  end

  -- FLaGs [sic]
  local flg = peekBits(stream, 8)
  local fcheck, fdict, flevel = getBits(stream, 5), getBits(stream, 1) == 1, getBits(stream, 2)
  if not (((cmf * 256 + flg) % 31) == 0) then
    error("[zlib] FCHECK failed, zlib header is invalid")
  end
  if fdict then
    error("[zlib] FDICT is not supported")
  end

  -- Decompress all blocks
  repeat
    local is_last = inflateBlock(stream)
  until is_last

  return stream.result
end

function zlib.compress(data)
  error("[zlib] compression is not implemented")
end

return zlib
