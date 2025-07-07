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

function M.config(conf)
  if conf == nil then
    config = { rules = {}, perfStats = false }
    return
  end
  if conf.socketPath ~= nil then config.servSocketPath = conf.socketPath end
  if conf.rules ~= nil then config.rules = conf.rules end
  if conf.perfStats ~= nil then config.perfStats = conf.perfStats end

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
    if rr.type == kres.type.A or rr.type == kres.type.AAAA then
      local message = string.char((nftPath.family % 256), math.floor(nftPath.family / 256)) .. nftPath.tableName .. "\0" .. nftPath.setName .. "\0" .. rr.rdata
      if (socket:sendto(message, config.servSocketPath)) then
        local res = Acns.parseResponse(socket:receive())
        -- TODO use kres log utilities
        if (res == Acns.Responses.WRONG) then
          print("acns: problem receiving message")
        elseif (res == Acns.Responses.KO) then
          print("acns: ack KO for family[" .. nftPath.family .. "] -> tableName[" .. nftPath.tableName .. "] -> setName [" .. nftPath.setName .. "]")
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
    if config.perfStats then
      x = os.clock()
      flag = false
    end

    local initialQuery = req:initial()

    for _, rule in ipairs(config.rules) do
      local nftPath = rule(req, initialQuery)
      if nftPath ~= nil then
        flag = true
        insert(answer, nftPath)
      end
    end
    if (config.perfStats and flag) then
      print(string.format("acns slowed down this query by : %.6f second\n", os.clock() - x))
    end
  end
}

return M
