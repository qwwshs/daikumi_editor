function log(...) local file = io.open("log.txt", "a") file:write(os.date("%Y-%m-%d %H:%M:%S").."  "..tableToString({...}).."\n") file:close() end --log函数
