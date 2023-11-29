request = function()
   wrk.method = "POST"
   wrk.path = "/operation"
   wrk.body = '{"operation":' .. math.random (1,65535) .. '}'
   wrk.headers["Content-Type"] = "application/json"
   return wrk.format(method, path, headers, body)
end
