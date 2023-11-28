request = function()
   wrk.method = "GET"
   wrk.path = '/api/customer/' .. math.random (1,500000)
   return wrk.format(method, path, nil, nil)
end
