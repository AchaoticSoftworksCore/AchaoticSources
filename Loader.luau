local scripts = {
    [13772394625] = "https://raw.githubusercontent.com/AchaoticSoftworksCore/AchaoticSources/refs/heads/main/BladeBall/Main.luau",
    [6741970382] = "https://raw.githubusercontent.com/AchaoticSoftworksCore/AchaoticSources/refs/heads/main/ZombieLab/Main.luau",
}

local placeid = game.PlaceId

if scripts[placeid] then
    local url = scripts[placeid]
    local success, response = pcall(function()
        return game:HttpGet(url)
    end)
    if success then
        local func, loadError = loadstring(response)
        if func then
            func()
        else
            warn("Error loading script:", loadError)
        end
    else
        warn("Error fetching script:", response)
    end
else
    warn("No script found for this PlaceId:", placeid)
end
