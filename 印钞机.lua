-- 服务统一初始化（增强容错）
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")

-- 本地玩家核心组件（自动初始化+重试）
local localPlayer = Players.LocalPlayer
local character, HumanoidRootPart, humanoid
local scriptStartTime = os.time()
local isTeleporting = false -- 传送状态锁

-- 角色初始化函数（防止加载失败）
local function initCharacter()
    character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
    HumanoidRootPart = character:WaitForChild("HumanoidRootPart", 10)
    humanoid = character:WaitForChild("Humanoid", 10)
    if not (HumanoidRootPart and humanoid) then
        warn("角色组件加载失败，重试中...")
        task.wait(2)
        initCharacter()
    end
end
initCharacter()

-- HTTP请求兼容（适配不同执行器）
local httpRequest = (syn and syn.request) 
    or (http and http.request) 
    or http_request 
    or (fluxus and fluxus.request) 
    or request
if not httpRequest then
    warn("未检测到HTTP接口，换服功能可能受限！")
end

-- 核心配置（整合两款脚本功能）
local CONFIG = {
    -- 禁区配置（避开危险区域）
    FORBIDDEN_ZONE = {
        center = Vector3.new(352.884155, 13.0287256, -1353.05396),
        radius = 80
    },
    -- 换服配置
    TELEPORT_COOLDOWN = 0.5,          -- 传送后加载时间
    SERVER_FETCH_RETRY_DELAY = 5,     -- 服务器获取失败重试间隔
    MAX_VISITED_SERVERS = 50,         -- 最大访问服务器缓存
    TIMEOUT = 120,                    -- 单服超时时间（秒）
    -- 收集配置
    COLLECT_DELAY = 0.3,              -- 物品收集间隔
    PICKUP_TIMEOUT = 5,               -- 物品收集超时时间
    -- 自定义目标物品（印钞机+各类道具，可新增/修改）
    TARGET_ITEMS = {
        "Money Printer",               -- 印钞机（核心目标）
        "Blue Candy Cane",             -- 蓝色糖果棒
        "Bunny Balloon",               -- 兔子气球
        "Ghost Balloon",               -- 幽灵气球
        "Clover Balloon",              -- 三叶草气球
        "Bat Balloon",                 -- 蝙蝠气球
        "Gold Clover Balloon",         -- 金色三叶草气球
        "Golden Rose",                 -- 金色玫瑰
        "Black Rose",                  -- 黑色玫瑰
        "Heart Balloon",               -- 爱心气球
        "Diamond Ring",                -- 钻戒
        "Diamond",                     -- 钻石
        "Void Gem",                    -- 虚空宝石
        "Dark Matter Gem",             -- 暗物质宝石
        "Rollie",                      -- 罗利（道具名）
        "NextBot Grenade",             -- 下bot手榴弹
        "Nuclear Missile Launcher",    -- 核导弹发射器
        "Suitcase Nuke",               -- 手提箱核弹
        "Helicopter",                  -- 直升机
        "Trident",                     -- 三叉戟
        "Golden Cup",                  -- 金杯
        "One Dollar Ballon"            -- 一美元气球（原拼写保留）
    },
    -- 银行配置
    BANK_POSITIONS = {
        vaultDoor = Vector3.new(1078.08, 6.25, -343.96), -- 金库门位置
        initialSpawn = Vector3.new(677.13, 62.14, 202.05) -- 初始传送位置
    }
}

-- 服务器列表缓存
local visitedServers = {}
local availableServers = {}

-- 通知功能（统一格式）
local function ShowNotification(text, isError)
    local success = pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "LYY OHIO HUB 整合版",
            Text = text,
            Duration = 4,
            Icon = isError and "rbxassetid://9146315215" or "rbxassetid://9146314609"
        })
    end)
    if not success then
        warn("[通知] " .. text)
    end
end

-- 初始传送（定位到安全位置）
HumanoidRootPart.CFrame = CFrame.new(CONFIG.BANK_POSITIONS.initialSpawn)
ShowNotification("✅ 脚本启动，已定位初始位置")

-- 模拟W键移动（绕开检测）
local function simulateWKey()
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, "W", false, game)
        task.wait(0.8)
        VirtualInputManager:SendKeyEvent(false, "W", false, game)
        ShowNotification("✅ 模拟移动完成")
    end)
end
simulateWKey()

-- 获取可用服务器列表（优化筛选）
local function fetchAvailableServers()
    if not httpRequest then return {} end
    availableServers = {}
    local url = string.format(
        "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100",
        game.PlaceId
    )
    local success, response = pcall(function()
        return httpRequest({
            Url = url,
            Method = "GET",
            Timeout = 8,
            Headers = {["Content-Type"] = "application/json"}
        })
    end)
    if not success or not response or response.StatusCode ~= 200 then
        ShowNotification("❌ 服务器列表获取失败", true)
        return {}
    end
    local data = HttpService:JSONDecode(response.Body)
    if not data or not data.data then return {} end

    -- 清理过期缓存
    if #visitedServers > CONFIG.MAX_VISITED_SERVERS then
        table.clear(visitedServers)
    end

    -- 筛选可用服务器（排除当前服、满员服、已访问服）
    local currentJobId = game.JobId
    for _, server in ipairs(data.data) do
        if server.id ~= currentJobId 
            and server.playing < server.maxPlayers 
            and not visitedServers[server.id] 
            and server.playing > 0 then
            table.insert(availableServers, server.id)
        end
    end
    return availableServers
end

-- 智能换服函数（带重试机制）
local function TPServer()
    if isTeleporting then return end
    isTeleporting = true
    ShowNotification("🌐 正在查找可用服务器...")
    
    local servers = fetchAvailableServers()
    if #servers == 0 then
        ShowNotification("❌ 无可用服务器，等待重试", true)
        task.wait(CONFIG.SERVER_FETCH_RETRY_DELAY)
        isTeleporting = false
        TPServer() -- 重试
        return
    end

    -- 随机选择一个服务器
    local targetServer = servers[math.random(1, #servers)]
    visitedServers[targetServer] = true
    ShowNotification("🔄 尝试传送到服务器：" .. string.sub(targetServer, 1, 8))

    local success, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, targetServer, localPlayer)
    end)
    if not success then
        ShowNotification("❌ 传送失败：" .. tostring(err):sub(1, 30), true)
        task.wait(2)
        isTeleporting = false
        TPServer() -- 重试
    end
end

-- 超时检测函数
local function checkTimeout()
    return (os.time() - scriptStartTime) >= CONFIG.TIMEOUT
end

-- 自动捡物品核心函数（印钞机+自定义物品）
local function AutoPickItem()
    ShowNotification("🎯 开始自动捡物品（优先印钞机）")
    local itemFoundCount = 0

    while task.wait(0.1) do
        -- 超时检测
        if checkTimeout() then
            ShowNotification("⏰ 单服超时，准备换服")
            TPServer()
            return false
        end

        local foundItem = false
        -- 查找物品父容器（容错处理）
        local itemPickup = Workspace:FindFirstChild("Game") 
            and Workspace.Game:FindFirstChild("Entities") 
            and Workspace.Game.Entities:FindFirstChild("ItemPickup")
        if not itemPickup then continue end

        -- 遍历所有物品
        for _, itemFolder in ipairs(itemPickup:GetChildren()) do
            for _, item in ipairs(itemFolder:GetChildren()) do
                if (item:IsA("MeshPart") or item:IsA("Part")) and item:IsDescendantOf(Workspace) then
                    -- 避开禁区
                    local distanceToForbidden = (item.Position - CONFIG.FORBIDDEN_ZONE.center).Magnitude
                    if distanceToForbidden <= CONFIG.FORBIDDEN_ZONE.radius then continue end

                    -- 查找交互提示
                    local prompt = item:FindFirstChildWhichIsA("ProximityPrompt")
                    if prompt then
                        -- 匹配目标物品（包含印钞机）
                        for _, targetName in ipairs(CONFIG.TARGET_ITEMS) do
                            if prompt.ObjectText == targetName then
                                foundItem = true
                                itemFoundCount += 1

                                -- 优化交互设置
                                prompt.RequiresLineOfSight = false
                                prompt.HoldDuration = 0

                                -- 传送到物品位置（防卡模型）
                                HumanoidRootPart.CFrame = item.CFrame * CFrame.new(0, 2, 0)
                                task.wait(0.1)

                                -- 触发拾取
                                if fireproximityprompt then
                                    fireproximityprompt(prompt)
                                elseif prompt.Triggered then
                                    prompt:Triggered(localPlayer)
                                end

                                ShowNotification("✅ 捡到：" .. targetName .. "（累计" .. itemFoundCount .. "个）")

                                -- 物品超时清理
                                local startTime = tick()
                                local connection
                                connection = RunService.Heartbeat:Connect(function()
                                    if not item or not item.Parent then
                                        connection:Disconnect()
                                        return
                                    end
                                    if tick() - startTime >= CONFIG.PICKUP_TIMEOUT then
                                        item:Destroy()
                                        connection:Disconnect()
                                    end
                                end)

                                task.wait(CONFIG.COLLECT_DELAY)
                            end
                        end
                    end
                end
            end
        end

        -- 若当前轮未找到物品，提示并准备切换到银行farming
        if not foundItem and itemFoundCount == 0 then
            ShowNotification("🔍 当前区域无目标物品，切换到银行farming")
            task.wait(1)
            return true
        elseif not foundItem and itemFoundCount > 0 then
            ShowNotification("✅ 区域物品拾取完成（累计" .. itemFoundCount .. "个），切换到银行farming")
            task.wait(1)
            return true
        end
    end
end

-- 银行自动farming函数（保留原逻辑并优化）
local function AutoFarmBank()
    ShowNotification("🏦 开始银行自动farming")

    while task.wait(0.1) do
        -- 超时检测
        if checkTimeout() then
            ShowNotification("⏰ 单服超时，准备换服")
            TPServer()
            return
        end

        -- 查找银行核心组件（容错）
        local BankRobbery = Workspace:FindFirstChild("BankRobbery")
        if not BankRobbery then
            ShowNotification("❌ 未找到银行区域，准备换服", true)
            task.wait(1)
            TPServer()
            return
        end

        local BankDoor = BankRobbery:FindFirstChild("VaultDoor")
        local BankCashs = BankRobbery:FindFirstChild("BankCash")
        if not (BankDoor and BankCashs) then
            ShowNotification("❌ 银行组件缺失，准备换服", true)
            task.wait(1)
            TPServer()
            return
        end

        local cashBundle = BankCashs.Cash:FindFirstChild("Bundle")
        -- 情况1：金库门未打开且有现金
        if BankDoor.Door.Attachment.ProximityPrompt.Enabled and cashBundle then
            ShowNotification("🔓 正在打开金库门")
            HumanoidRootPart.CFrame = CFrame.new(CONFIG.BANK_POSITIONS.vaultDoor)
            BankDoor.Door.Attachment.ProximityPrompt.HoldDuration = 0
            if fireproximityprompt then
                fireproximityprompt(BankDoor.Door.Attachment.ProximityPrompt)
            end
            task.wait(0.5)
        -- 情况2：金库门已打开且有现金
        elseif not BankDoor.Door.Attachment.ProximityPrompt.Enabled and cashBundle then
            ShowNotification("💰 正在收集银行现金")
            local targetPos = cashBundle:GetPivot().Position
            local basePosition = Vector3.new(targetPos.X, targetPos.Y - 5, targetPos.Z)
            local lookVector = (targetPos - basePosition).Unit
            HumanoidRootPart.CFrame = CFrame.new(basePosition, basePosition + lookVector)
            
            local cashPrompt = BankCashs.Main.Attachment.ProximityPrompt
            cashPrompt.RequiresLineOfSight = false
            cashPrompt.HoldDuration = 0
            if fireproximityprompt then
                fireproximityprompt(cashPrompt)
            end
            task.wait(0.01)
        -- 情况3：无现金或无法操作，换服
        else
            ShowNotification("🏦 银行无现金，准备换服")
            task.wait(0.5)
            TPServer()
            return
        end
    end
end

-- 主流程：先捡物品（印钞机+自定义道具）→ 再farm银行 → 循环
local function mainLoop()
    while true do
        if isTeleporting then task.wait(1) continue end
        -- 1. 自动捡物品（印钞机优先）
        local itemsFinished = AutoPickItem()
        -- 2. 物品捡完后farm银行
        if itemsFinished then
            AutoFarmBank()
        end
        -- 3. 银行farm完成后换服
        ShowNotification("🔄 本轮流程结束，准备换服")
        TPServer()
    end
end

-- 启动主循环
task.spawn(mainLoop)
ShowNotification("🚀 整合脚本启动成功！自动捡物+银行farm+智能换服")
