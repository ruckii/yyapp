request = function()
   wrk.method = "POST"
   wrk.body = '{"operation":' .. math.random (1,65535) .. '}'
   wrk.headers["Content-Type"] = "application/json"
   return wrk.format(method, nil, headers, body)
end
