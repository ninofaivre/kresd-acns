require("acns.ffi")

local ffi = require("ffi")
local Socket = require("socket")
Socket.unix = require("socket.unix")
local Acns = require("acns.Acns")

local M = {}
local config = nil

local socket
-- TODO add instance identifier in socket path
local ackSockPath = "/run/knot-resolver/acnsAck.sock"

function M.init(module)
  socket = assert(Socket.unix.dgram())
  ffi.C.unlink(ackSockPath)
  assert(socket:bind(ackSockPath))
  ffi.C.chmod(ackSockPath, tonumber("620", 8))
end

function M.deinit(module)
  socket:close()
  ffi.C.unlink(ackSockPath)
end

function M.addRule(rule)
  table.insert(config.rules, rule)
end

function M.addRules(rules)
  for _, rule in ipairs(rules) do
    M.addRule(rule)
  end
end

-- TODO clean this mess
function M.config(conf)
  if conf == nil then
    config = { rules = {}, perfStats = false }
    return
  end
  if conf.socketPath ~= nil then config.servSocketPath = conf.socketPath end
  if conf.rules ~= nil then config.rules = conf.rules end
  if conf.perfStats ~= nil then config.perfStats = conf.perfStats end
  if conf.debug ~= nil then config.debug = true end

  if conf.unixSocketAccessGroupName ~= nil then
    local group = assert(
      ffi.C.getgrnam(conf.unixSocketAccessGroupName),
      "gid for group " .. conf.unixSocketAccessGroupName .. " not found !"
    )[0]
    ffi.C.chown(ackSockPath, -1, group.gr_gid)
  end
end

local function insert (answer, nftPath)
  for _, rr in ipairs(answer) do
    if nftPath[rr.type] ~= nil and nftPath[rr.type].enabled == true then
      local family = nftPath[rr.type].family or nftPath.family
      local tableName = nftPath[rr.type].tableName or nftPath.tableName
      local setName = nftPath[rr.type].setName or nftPath.setName

      local message = string.char((family % 256), math.floor(family / 256)) .. tableName .. "\0" .. setName .. "\0" .. rr.rdata
      if (socket:sendto(message, config.servSocketPath)) then
        local res = Acns.parseResponse(socket:receive())
        -- TODO use kres log utilities
        if (res == Acns.Responses.WRONG) then
          print("acns: problem receiving message")
        elseif (res == Acns.Responses.KO) then
          print("acns: ack KO for family[" .. family .. "] -> tableName[" .. tableName .. "] -> setName [" .. setName .. "]")
        end
      else
        print("acns: problem sending message")
      end
    end
  end
end

M.layer = {
  finish = function (state, req, answer)
    if config == nil or
      state ~= kres.DONE or
      config.servSocketPath == nil
    then
      return
    end

    local x, flag
    flag = false
    if config.perfStats then
      x = os.clock()
    end

    local initialQuery = req:initial()

    for _, rule in ipairs(config.rules) do
      local nftPath = rule(req, initialQuery)
      if nftPath ~= nil then
        if config.debug == true then
          io.stderr:write("acns : debug : rule matched : initialQuery.sname :", kres.dname2str(initialQuery.sname), "\n")
          io.stderr:flush();
        end
        flag = true
        insert(answer, nftPath)
      end
    end
    if (flag == false and config.debug == true) then
      io.stderr:write("acns : debug : rule did not matched : initialQuery.sname :", kres.dname2str(initialQuery.sname), "\n")
      io.stderr:flush();
    end
    if (config.perfStats and flag) then
      io.stderr:write(string.format("acns slowed down this query by : %.6f second\n", os.clock() - x), "\n")
      io.stderr:flush();
    end
  end
}

return M
