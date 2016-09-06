-- password generator
function createpassword(x)
  math.randomseed(os.time())
	local a = {}
	for count = 1, x do
		a[#a+1] = string.char(math.random(33,126))
	end
	return table.concat(a)
end
-- reade password on KV
function kv_ps_read(id)
  return  Keystore.get({key = "pw_" .. id})
end
-- store password on KV
function kv_ps_write(id, password)
  Keystore.set({key = "pw_" .. id, value = password})
end
-- get current logged in user from webservice request
-- returns user table or nil if no user is contained
-- in headers
function currentUser(request)
  return currentUserFromHeaders(request.headers)
end

-- determine the current user from the session information
-- stored in webservice or websocket request headers.
-- returns user table or nil if no user is contained
-- in headers
function currentUserFromHeaders(headers)
  if type(headers.cookie) ~= "string" then
    return nil
  end
  local _, _, sid = string.find(headers.cookie, "sid=([^;]+)")
  if type(sid) ~= "string" then
    return nil
  end
  local user = User.getCurrentUser({token = sid})
  if user ~= nil and user.id ~= nil then
    user.token = sid
    return user
  end
  return nil
end

function table.contains(table, element)
  for _, value in pairs(table) do
    if value == element then
      return true
    end
  end
  return false
end

-- default a particular key in a table to value
-- if that index already exists, otherwise does nothing.
function default(t, key, defaultValue)
  if not table.contains(t, key) then
    t[key] = defaultValue
  end
end

function kv_read(sn)
  return kv_read_opt(sn, true)
end
-- read the latest values for a lightbulb device
-- from the key value cache and from One Platform
--
-- if first variable arg is true, device will be read for
-- any nil values so their latest state is available
-- to the UI.
function kv_read_opt(sn, readDevice)
  local resp = Keystore.get({key = "sn_" .. sn})
  local device = nil
  if type(resp) == "table" and type(resp.value) == "string" then
    -- device has written. Get the latest written values
    -- and look up everything else.
    device = from_json(resp.value)

    if device ~= nil then
      -- backward compatibility with old example versions
      if not table.contains(device, 'rid') then
        device.rid = lookup_rid(device.pid, sn)
      end

      if readDevice then
        -- if any resource values haven't been written in
        -- fetch the last value via the Device service
        if device.temperature == nil or device.humidity == nil or device.state == nil or
           device.temperature == 'undefined' or device.humidity == 'undefined' or device.state == 'undefined' then
          temperature, humidity, state = device_read(device.pid, device.rid)
          device.temperature = temperature
          device.humidity = humidity
          device.state = state
          --default(device, 'temperature', temperature)
          --default(device, 'humidity', humidity)
          --default(device, 'state', state)
        end
      end
    end
  end

  return device
end

-- store device settings to the key value store
function kv_write(sn, values)
  Keystore.set({key = "sn_" .. sn, value = to_json(values)})
end

-- return the device's temperature, humidity, state
function device_read(pid, rid)
  calls = {}
  for k, alias in pairs({'temperature', 'humidity', 'state'}) do
    table.insert(calls, {id=alias, procedure="read", arguments={{alias=alias}, {limit=1}}})
  end
  local rpcret = Device.rpcCall({
    pid = pid,
    auth = {client_id = rid},
    calls = calls})

  -- find and extract the read value from RPC response rpcret
  function get_read_result(alias)
    for k, r in pairs(rpcret) do
      if r.id == alias then
        if table.getn(r.result) > 0 then
          -- get the value part of the data point
          return r.result[1][2]
        else
          return nil
        end
      end
    end
  end
  temperature = get_read_result('temperature')
  humidity = get_read_result('humidity')
  state = get_read_result('state')
  return temperature, humidity, state
end

-- return rid for device, or nil if there is an error
function lookup_rid(pid, sn)
  if pid == nil then
    -- device needs to send data first
    return nil
  end
  local ret = Device.rpcCall({pid = pid, calls = {{
    id = "1",
    procedure = "lookup",
    arguments = {"alias", tostring(sn)}
  }}})
  if type(ret) ~= "table" then
    return "error in lookup rpc call"
  end
  if ret[1].status ~= "ok" then
    -- "error in lookup: "..ret[1].result
    return nil
  end
  return ret[1].result
end

function deviceRpcCall(sn, procedure, args)
  local device = kv_read(sn)
  if device.pid == nil then
    return "device needs to send data first"
  end
  local ret = Device.rpcCall({pid = device.pid, auth = {client_id = device.rid}, calls = {{
    id = "1",
    procedure = procedure,
    arguments = args
  }}})
  return ret[1]
end

function write(sn, alias, value)
  return deviceRpcCall(sn, "write", {
    {alias = alias},
    value
  })
end

http_error_codes = {
  [400] = {
    code = 400,
    message = "Bad Request",
    headers = {}
  },
  [403] = {
    code = 403,
    message = "Permission Denied",
    headers = {}
  },
  [404] = {
    code = 404,
    message = "Not Found",
    headers = {}
  }
}

function http_error(code, response)
  if http_error_codes[code] ~= nil then
    for key, value in pairs(http_error_codes[code]) do
      response[key] = value
    end
  else
    response.code = code
    response.message = "No prepared message for this code"
  end
end

function trigger(alert, timerid)
  Timer.sendAfter({
    message = alert.message,
    duration = alert.timer * 60 * 1000,
    timer_id = timerid
  })
  alert.timer_running = true
  alert.timer_id = timerid
end

function cancel_trigger(alert)
  Timer.cancel({timer_id = alert.timer_id})
  alert.timer_running = false
end
