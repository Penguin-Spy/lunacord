local socket = require 'socket'
local copas = require 'copas'

local HTTP = {}

---@class Response
---@field status number The numerical status code
---@field reason string The reason prhase that MAY correspond to the status number. This can be any string, including the empty string; You should rely on the numerical `status` for logic.
---@field headers table The response headers as key-value pairs
---@field body string   The body of the response

---@class Socket
---@field send function    (data: string) -> number, string?
---@field receive function (pattern: string) -> string|nil, string?

-- TODO: these are like, really not secure. find how to make this more secure
local SSL_PARAMS = { mode = "client", protocol = "any" }

local function parse_url(url)
  local protocol, address, uri = url:match('^(%w+)://([^/]+)(.*)$')
  if not protocol then protocol = "https" end
  protocol = protocol:lower()
  local host, port = address:match("^(.+):(%d+)$")
  if not host then
    host = address
    port = 443
  end
  if not uri or uri == '' then uri = '/' end
  return protocol, host, tonumber(port), uri
end

---@return Socket|nil
---@return string? err
local function connect(host, port)
  local sock = copas.wrap(socket.tcp(), SSL_PARAMS)
  local _, err = sock:connect(host, port)
  if err then return nil, "socket wrap failed: " .. err end
  return sock
end

-- Raw request method
---@param method string       request method
---@param url string          full URL of request
---@param req_headers table?  [string]: string
---@param req_body string?    optional body content
--
---@return Response|nil body  Response (with body, status, headers, etc.), or nil if error
---@return string? res        error message if failed
--
function HTTP.request(method, url, req_headers, req_body)
  local protocol, host, port, uri = parse_url(url)
  if protocol ~= "https" then
    return nil, "[http] invalid protocol: " .. protocol
  end

  -- Generate request message
  local format = string.format
  local res_lines = {
    format("%s %s HTTP/1.1", method:upper(), uri or "/"),
    format("Host: %s", host),
  }

  if req_headers then
    for name, value in pairs(req_headers) do
      table.insert(res_lines, name .. ": " .. value)
    end
  end
  table.insert(res_lines, "\r\n")
  local req = table.concat(res_lines, "\r\n")

  if req_body then
    req = req .. req_body
  end

  -- Connect and send request
  local sock, err = connect(host, port)
  if not sock then return nil, "[http] " .. err end

  local n, err = sock:send(req)
  if n ~= #req then
    return nil, format("[http] request send error (expected %d, sent %d): ", #req, n) .. err
  end

  -- Receive response
  res_lines = {}
  repeat
    local line, err = sock:receive("*l")
    if err then return nil, "[http] response receive error: " .. err end
    table.insert(res_lines, line)
  until line == ""
  table.remove(res_lines) -- removes trailing blank line

  ---@type Response
  local res = { headers = {}, body = "" }
  local status

  -- Parse response status message
  status, res.reason = res_lines[1]:match("^HTTP/1%.1 (%d+) ?([%g ]*)$")

  status = tonumber(status)
  if not status then return nil, "[http] parsing response message failed: " .. res_lines[1] end

  res.status = status
  table.remove(res_lines, 1)

  -- Parse response headers
  for _, header in ipairs(res_lines) do
    ---@type string, string
    local name, value = header:match("^([%a%d!#-'*+.^_`|~-]+): ([%g \t]+)$") -- section 5.1 and 5.5 of RFC 9110 (token is defined in 5.6.2)
    if not name then
      return nil, "[http] failed to parse header, cannot continue safely: '" .. header .. "'"
    end
    name = name:lower() -- case insensitive, so force lowercase to simplify client logic

    if name ~= "set-cookie" then
      if res.headers[name] then
        res.headers[name] = res.headers[name] .. ", " .. value -- section 5.3 of RFC 9110
      else
        res.headers[name] = value
      end
    else
      -- TODO: handle cookies
    end
  end

  -- Parse response body
  if res.headers["content-length"] then
    res.body, err = sock:receive(res.headers["content-length"])

  elseif res.headers["transfer-encoding"] == "chunked" then
    while true do
      local line, err = sock:receive("*l")
      if err then break end

      local length = tonumber(line, 16)
      if length == 0 then break
      elseif not length then err = "failed to parse chunk length: " .. line break end

      local chunk, err = sock:receive(length)
      if err then break end
      res.body = res.body .. chunk

      sock:receive("*l") -- discard trailing '\r\n' of data (why tf is it here btw, we already know where the data ends)
    end

  else return nil, "[http] unable to determine content transfer method?" end

  if err then return nil, "[http] request receive error: " .. err end
  return res
end

-- GET a resource
---@param url string          full URL of resource
---@param headers table?      key-value pairs of request headers
--
---@return Response|nil body  Response (with body, status, headers, etc.), or nil if error
---@return string? res        error message if failed
--
function HTTP.get(url, headers)
  return HTTP.request("GET", url, headers)
end

-- POST data to a url \
-- TODO: add a param for content type & encode the data here
---@param url string          full URL of resource
---@param headers table?      key-value pairs of request headers
---@param body string         raw data of POST request
--
---@return Response|nil body  Response (with body, status, headers, etc.), or nil if error
---@return string? res        error message if failed
--
function HTTP.post(url, headers, body)
  return HTTP.request("POST", url, headers, body)
end

return HTTP
