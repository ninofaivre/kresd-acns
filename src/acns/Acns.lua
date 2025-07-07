local bit = require("bit")

local Responses = {
  OK = "OK",
  KO = "KO",
  WRONG = "WRONG"
}

return {
  Responses = Responses,
  parseResponse = function (res)
    if (res == nil or #res ~= 1) then return Responses.WRONG end
    if (bit.band((string.byte(res, 0, 1)), 0x01) == 1) then
      return Responses.KO
    end
    return Responses.OK
  end
}
