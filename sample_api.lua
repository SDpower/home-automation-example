--#ENDPOINT GET /social/handle/{consumer}/loginurl
local consumer = request.parameters.consumer

if consumer == nil then
  response.code = 404
  response.message = 'Not found'
else
local Url = User.getSocialLoginUrl({consumer=consumer})
if Url.status ~= nil then
  response.code = 404
  response.message = 'Not found'
else
  response.headers["location"] = Url
  response.code = 303
end
end

--#ENDPOINT GET /social/handle/{consumer}
results, err = to_json(request.parameters)
resultd, err = from_json(results)
local consumer = resultd.consumer
if consumer == nil then
  response.code = 404
  response.message = 'Not found'
else
  local tokenstr = User.getSocialToken(resultd)
  if tokenstr.status ~= nil then
    response.code = 500
    response.message = 'Get token error'
  else
    local requestInf = User.socialRequest({consumer=request.parameters.consumer, token=tokenstr})
    if requestInf.status ~= nil then
      response.code = 500
      response.message = 'Get request error'
    else
      local userList = User.listUsers({filter = "email::like::" .. requestInf.email})
      if table.getn(userList) == 0 then
        local passwordSample = createpassword(12)
        local ret = User.createUser({
          email = requestInf.email,
          name = requestInf.name,
          password = passwordSample
        })
        User.activateUser({code = ret})
        userList = User.listUsers({filter = "email::like::" .. requestInf.email})
        if #userList == 1 and userList[1].id ~= nil then
          local userId = userList[1].id
          kv_ps_write(userId,passwordSample)
          ret = User.getUserToken({
            email = requestInf.email,
            password = passwordSample
          })
          if ret ~= nil and ret.status_code ~= nil then
            response.code = ret.status_code
            response.message = ret.message
          else
            response.headers = {
              ["Set-Cookie"] = "sid=" .. tostring(ret) .. "; path=/;",
              ["location"] = "/"
            }
            response.code = 303
          end
        end
      elseif #userList == 1 and userList[1].id ~= nil then
        local userId = userList[1].id
        local passwordSample = kv_ps_read(userId).value
        ret = User.getUserToken({
          email = requestInf.email,
          password = passwordSample
        })
        if ret ~= nil and ret.status_code ~= nil then
          response.code = ret.status_code
          response.message = ret.message
        else
          response.headers = {
            ["Set-Cookie"] = "sid=" .. tostring(ret) .. "; path=/;",
            ["location"] = "/"
          }
          response.code = 303
        end
      end
    end
  end

end

--#ENDPOINT PUT /user/{email}
local ret = User.createUser({
  email = request.parameters.email,
  name = request.parameters.email,
  password = request.body.password
})
if ret.status_code ~= nil then
  response.code = ret.status_code
  response.message = ret.message
else
  local domain = string.gsub(request.uri, 'https?://(.-/)(.*)', '%1')
  local text = "Hi " .. request.parameters.email .. ",\n"
  text = text .. "Click this link to verify your account:\n"
  text = text .. "https://" .. domain .. "verify/" .. ret;
  Email.send({
    from = 'Sample App <mail@exosite.com>',
    to = request.parameters.email,
    subject = ("Signup on " .. domain),
    text = text
  })
end
--#ENDPOINT GET /verify/{code}
local ret = User.activateUser({code = request.parameters.code})
if ret == 'OK' then
  response.headers["Content-type"] = "text/html"
  response.message = '<html><head></head><body>Signed up successfully. <a href="/#/login">Log in</a></body></html>'
else
  response.message = 'Sign up failed. Error: ' .. ret.message
end
--#ENDPOINT PATCH /user/{email}
local user = currentUser(request)
if user ~= nil then
  User.updateUserStorage({id = user.id, ["key values"] = request.body})
  User.createUserStorage({id = user.id, ["key values"] = request.body})
end
--#ENDPOINT POST /session
local ret = User.getUserToken({
  email = request.body.email,
  password = request.body.password
})
if ret ~= nil and ret.status_code ~= nil then
  response.code = ret.status_code
  response.message = ret.message
else
  response.headers = {
    ["Set-Cookie"] = "sid=" .. tostring(ret)
  }
  response.message = {["token"] = ret}
end
--#ENDPOINT GET /session
--
local user = currentUser(request)
if user ~= nil and user.id ~= nil then
    return user
end
response.code = 400
response.message = "Session invalid"
--#ENDPOINT POST /user/{email}/lightbulbs
-- Claim a lightbulb with a user's account
-- Lightbulb must have already written in to the platform
-- and not been claimed by someone else.
local sn = tostring(request.body.serialnumber);
local link = request.body.link;
local name = request.body.name
local user = currentUser(request)

if user == nil or user.id == nil then
  http_error(403, response)
  return
end

-- only add device if the Product event handler has
-- heard from it (see event_handler/product.lua)
device = kv_read_opt(sn, false)
if device == nil then
  http_error(404, response)
  return
end

local owners = User.listRoleParamUsers({
  role_id = "owner",
  parameter_name = "sn",
  parameter_value = sn
})

function set_device_name(device, name)
  device.name = name
  kv_write(sn, device)
end

if link == true then
  if #owners == 0 then
    local resp = User.assignUser({
      id = user.id,
      roles = {{
        role_id = "owner",
        parameters = {{
          name = "sn",
          value = sn
        }}
      }}
    })
    if resp.code == nil then
      -- success, set name and return updated role
      set_device_name(device, name)
      response.message = "Ok"
      response.code = 200
    else
      -- error
      response.message = resp.message
      response.code = resp.code
    end
  else
    response.message = "Conflict"
    response.code = 409
    return
  end
elseif link == false then
  local is_owner = false
  for i, owner_id in ipairs(owners) do
    if owner_id == user.id then
      is_owner = true
      break
    end
  end
  if is_owner == false then
    response.message = "Conflict"
    response.code = 409
    return
  else
    local guests = User.listRoleParamUsers({
      role_id = "guest",
      parameter_name = "sn",
      parameter_value = sn
    })
    for i, guest in ipairs(guests) do
      User.deassignUserParam({
        id = guest,
        role_id = "guest",
        parameter_name = "sn",
        parameter_value = sn
      })
    end
    User.deassignUserParam({
      id = user.id,
      role_id = "owner",
      parameter_name = "sn",
      parameter_value = sn
    })

    -- save application-specific data associated with
    -- device here
    set_device_name(device, name)
    response.message = "Added lightbulb"
    response.code = 200
  end
else
  response.message = "Conflict"
  response.code = 409
end

--#ENDPOINT GET /user/{email}/lightbulbs
-- Get a list of lightbulbs associated with user with email {email}
local user = currentUser(request)
if user ~= nil then
  local list = {}
  local roles = User.listUserRoles({id = user.id})
  for _, role in ipairs(roles) do
    for _, parameter in ipairs(role.parameters) do
      if parameter.name == "sn" then
        local device_info = kv_read(parameter.value)
        if device_info == nil then
          print("device_info returned from kv_read is nil in " ..
            "GET /user/{email}/lightbulbs for sn " .. parameter.value)
        else
          if role.role_id == "owner" then
            device_info.type = "full"
          else
            device_info.type = "readonly"
          end
          device_info.serialnumber = parameter.value
          table.insert(list, device_info)
        end
      end
    end
  end
  response.headers["Content-type"] = "application/json; charset=utf-8"
  if table.getn(list) == 0 then
    return '[]'
  else
    return list
  end
else
  http_error(403, response)
end
--#ENDPOINT GET /user/{email}
local user = currentUser(request)
if user ~= nil and user.email == request.parameters.email then
  return User.listUserData({id = user.id})
else
  http_error(403, response)
end
--#ENDPOINT POST /user/{email}/shared/
local sn = tostring(request.body.serialnumber)
local user = currentUser(request)
if user ~= nil then
  local isowner = User.hasUserRoleParam({
    id = user.id,
    role_id = "owner",
    parameter_name = "sn",
    parameter_value = sn
  })
  if 'OK' == isowner then
    local guest = User.listUsers({filter = "email::like::" .. request.parameters.email})
    if #guest == 1 and guest[1].id ~= nil then
      local resp = User.assignUser({
        id = guest[1].id,
        roles = {{
          role_id = "guest",
          parameters = {{
            name = "sn",
            value = sn
          }}
        }}
      });
      return {"ok", resp}
    else
      return {"error", "user not found"}
    end
  end
end
http_error(403, response)
--#ENDPOINT DELETE /user/{email}/shared/{sn}
local sn = request.parameters.sn
local user = currentUser(request)
if user ~= nil then
  local isowner = User.hasUserRoleParam({
    id = user.id, role_id = "owner", parameter_name = "sn", parameter_value = sn
  })
  if isowner == 'OK' then
    local guestusers = User.listRoleParamUsers({
      role_id = "guest", parameter_name = "sn", parameter_value = sn
    })
    if guestusers ~= nil then
      for _, guestid in ipairs(guestusers) do
        local guest = User.getUser({id=guestid})
        if guest.email == request.parameters.email then
          local result = User.deassignUserParam({
            id = guest.id, role_id = "guest", parameter_name = "sn", parameter_value = sn
          })
          return result
        end
      end
    end
  end
end
http_error(403, response)
--#ENDPOINT GET /user/{email}/shared/
local user = currentUser(request)
if user ~= nil then
  if user.email ~= request.parameters.email then
    http_error(403, response)
  else
    local roles = User.listUserRoles({id=user.id})
    local list = {}
    for _, role in ipairs(roles) do
      if role.role_id == "owner" then
        for _, parameter in ipairs(role.parameters) do
          if parameter.name == "sn" then
            local sn = parameter.value
            local user_info = {serialnumber=sn, email=user.email, type="full"}
            table.insert(list, user_info)
            local guestusers = User.listRoleParamUsers({
              role_id = "guest", parameter_name = "sn", parameter_value = parameter.value
            })
            if guestusers ~= nil then
              for _, guestid in ipairs(guestusers) do
                local guest = User.getUser({id=guestid})
                local guest_info = {serialnumber=sn, email=guest.email, type="readonly"}
                table.insert(list, guest_info)
              end
            end
          end
        end
      end
    end
    return list
  end
end
http_error(403, response)
--#ENDPOINT POST /lightbulb/{sn}
-- write to one or more resources of lightbulb with serial number {sn}
-- Expects JSON object containing one or more properties in
-- "state" | "humidity" | "temperature" with the values to be set.
-- E.g. {"state": 1} to turn the lightbulb on
local sn = tostring(request.parameters.sn)
local user = currentUser(request)
if user ~= nil then
  local isowner = User.hasUserRoleParam({
    id = user.id, role_id = "owner", parameter_name = "sn", parameter_value = sn
  })
  if isowner == 'OK' then
    -- allow the owner to write these resources
    local message = {}
    for _, alias in ipairs({"state", "humidity", "temperature"}) do
      if request.body[alias] ~= nil then
        local ret = write(sn, alias, request.body[alias])
        if ret.status ~= nil and ret.status ~= "ok" then
          table.insert(message, {alias = alias, status = ret.status})
        end
      end
    end
    response.code = 200
    response.message = table.getn(message) ~= 0 and  message or ""
  else
    http_error(403, response)
  end
else
  http_error(403, response)
end

--#ENDPOINT GET /lightbulb/{sn}
-- get details about a particular lightbulb
local sn = tostring(request.parameters.sn)
local user = currentUser(request)
if user ~= nil then
  local isowner = User.hasUserRoleParam({
    id = user.id, role_id = "owner", parameter_name = "sn", parameter_value = sn
  })
  local isguest = User.hasUserRoleParam({
    id = user.id, role_id = "guest", parameter_name = "sn", parameter_value = sn
  })
  if isowner == 'OK' or isguest == 'OK' then
    return kv_read(sn)
  else
    http_error(403, response)
  end
else
  http_error(403, response)
end
--#ENDPOINT GET /lightbulb/{sn}/alert
local alerts = {}
local value = kv_read(request.parameters.sn)
if value.alerts ~= nil then
  alerts = value.alerts
end
for _, alert in ipairs(alerts) do
  alert.timer_id = nil
  alert.timer_running = nil
end
return to_json(alerts)
--#ENDPOINT DELETE /lightbulb/{sn}/alert
local sn = request.parameters.sn
if not (request.body.state and request.body.timer) then
  http_error(400, response)
  return
end
local value = kv_read(sn)
if value.alerts ~= nil then
  local alert = value.alerts[1]
  if alert ~= nil and request.body.state == alert.state and request.body.timer == alert.timer then
    alert = nil
  end
end
kv_write(sn, value)
response.code = 204
--#ENDPOINT POST /lightbulb/{sn}/alert
--{state:on, timer:5, email:user, active:true, message=""}
if not (
  request.body.state and request.body.timer and
  request.body.active and request.body.email and
  request.body.message
) then
  http_error(400, response)
  return
end
local sn = request.parameters.sn
local timerid = sn .. "_state"
local value = kv_read(sn)
local req_alert = {
  state = request.body.state,
  timer = request.body.timer,
  active = request.body.active,
  email = request.body.email,
  message = request.body.message,
  timer_running = false
}
if value.state ~= nil and value.state == request.body.state then -- condition true
  if value.alerts ~= nil then
    for _ ,alert in ipairs(value.alerts) do
      if request.body.active and not alert.timer_running then --enabled, not running
        trigger(req_alert, timerid)
      end
      if not request.body.active and alert.timer_running then --disabled, running
        cancel_trigger(alert)
      end
    end
  else -- no existing alert
    if request.body.active then
      trigger(req_alert, timerid)
    end
  end
end
value.alerts = {req_alert}
kv_write(sn, value)
--#ENDPOINT GET /debug-command/{cmd}
response.message = debug(request.parameters.cmd)
--#ENDPOINT WEBSOCKET /debug
response.message = debug(websocket_info.message)
--#ENDPOINT WEBSOCKET /listen
response.message = listen(websocketInfo)
--#ENDPOINT GET /_init
local ret1 = User.createRole({role_id = "owner", parameter = {{name = "sn"}}})
local ret2 = User.createRole({role_id = "guest", parameter = {{name = "sn"}}})
local ret = ret1.status_code ~= nil and ret1 or nil
if ret == nil then
  ret = ret2.status_code ~= nil and ret2 or nil
end
if ret ~= nil then
  response.code = ret.status_code
  response.message = ret.message
else
  response.code = 200
end
