function log(str) local file = io.open("log.txt", "a") file:write(os.date("%Y-%m-%d %H:%M:%S").."  "..tostring(str).."\n") file:close() end --log函数
