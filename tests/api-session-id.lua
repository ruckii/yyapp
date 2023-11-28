request = function()
   wrk.method = "GET"
   wrk.path = '/api/session/' .. math.random (1,5000000)
   return wrk.format(method, path, nil, nil)
end
