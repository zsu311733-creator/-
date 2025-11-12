-- 服务统一初始化（变量混淆）
local P,TS,HS,SG,RS,W,VI = game:GetService("Players"),game:GetService("TeleportService"),game:GetService("HttpService"),game:GetService("StarterGui"),game:GetService("RunService"),game:GetService("Workspace"),game:GetService("VirtualInputManager")

-- 加密密钥（自定义，增强安全性）
local K = 157
-- 异或加密函数
local function E(S)local R=""for i=1,#S do R=R..string.char(string.byte(S,i)~K)end return R end
-- 异或解密函数
local function D(S)local R=""for i=1,#S do R=R..string.char(string.byte(S,i)~K)end return R end

-- 【白名单系统核心配置（已启用远程白名单）】
local WC = {
    LOCAL_WHITELIST = {
        "你的主账号用户名",  -- 替换为你的核心账号（防止远程链接失效）
    },
    USE_REMOTE_WHITELIST = true,
    REMOTE_WHITELIST_URL = "https://raw.githubusercontent.com/zsu311733-creator/-/refs/heads/main/白名单.lua"
}

-- 本地玩家验证（白名单检测）
local LP = P.LocalPlayer
if not LP then warn("无法获取本地玩家，脚本终止")return end
local PN = LP.Name

-- 白名单验证函数（适配远程JSON格式）
local function IW()
    if WC.USE_REMOTE_WHITELIST then
        local S,R = pcall(function()return game:HttpGet(WC.REMOTE_WHITELIST_URL,true)end)
        if S and R then
            local SD,RD = pcall(function()return HS:JSONDecode(R)end)
            if SD and RD.whitelist and type(RD.whitelist)=="table"then
                for _,N in ipairs(RD.whitelist)do
                    if N==PN then return true end
                end
            end
        end
        warn("远程白名单加载失败，切换到本地白名单")
    end
    for _,N in ipairs(WC.LOCAL_WHITELIST)do
        if N==PN then return true end
    end
    return false
end

-- 验证拦截
local IA = IW()
if not IA then
    pcall(function()
        SG:SetCore("SendNotification",{
            Title="❌ 权限不足",
            Text="你的用户名未在白名单中，无法使用该脚本！\n联系作者添加权限",
            Duration=10,
            Icon="rbxassetid://9146315215"
        })
    end)
    warn("[白名单拦截] 玩家 "..PN.." 尝试使用脚本")
    return
end

-- 白名单验证通过提示
pcall(function()
    SG:SetCore("SendNotification",{
        Title="✅ 验证成功",
        Text="欢迎使用脚本，"..PN.."！",
        Duration=3,
        Icon="rbxassetid://9146314609"
    })
end)

-- ###########################################################################
-- 核心功能加密段（解密后执行）
-- ###########################################################################
local EC = E([[
local C,H,HM,ST,IT=false,false,false,os.time(),false
local function IC()
    C=LP.Character or LP.CharacterAdded:Wait()
    H=C:WaitForChild("HumanoidRootPart",10)
    HM=C:WaitForChild("Humanoid",10)
    if not(H and HM)then
        warn("角色组件加载失败，重试中...")
        task.wait(2)
        IC()
    end
end
IC()
local HR = (syn and syn.request)or(http and http.request)or http_request or(fluxus and fluxus.request)or request
if not HR then warn("未检测到HTTP接口，换服功能受限！")end
local CF = {
    FORBIDDEN_ZONE={center=Vector3.new(352.884155,13.0287256,-1353.05396),radius=80},
    TELEPORT_COOLDOWN=0.5,
    SERVER_FETCH_RETRY_DELAY=5,
    MAX_VISITED_SERVERS=50,
    TIMEOUT=120,
    COLLECT_DELAY=0.3,
    PICKUP_TIMEOUT=5,
    TARGET_ITEMS={
        "Money Printer","Blue Candy Cane","Bunny Balloon","Ghost Balloon",
        "Clover Balloon","Bat Balloon","Gold Clover Balloon","Golden Rose",
        "Black Rose","Heart Balloon","Diamond Ring","Diamond","Void Gem",
        "Dark Matter Gem","Rollie","NextBot Grenade","Nuclear Missile Launcher",
        "Suitcase Nuke","Helicopter","Trident","Golden Cup","One Dollar Ballon"
    },
    BANK_POSITIONS={vaultDoor=Vector3.new(1078.08,6.25,-343.96),initialSpawn=Vector3.new(677.13,62.14,202.05)}
}
local function SN(T,E)
    local S=pcall(function()
        SG:SetCore("SendNotification",{
            Title="LYY OHIO HUB 白名单版",
            Text=T,
            Duration=4,
            Icon=E and"rbxassetid://9146315215"or"rbxassetid://9146314609"
        })
    end)
    if not S then warn("[通知] "..T)end
end
H.CFrame=CFrame.new(CF.BANK_POSITIONS.initialSpawn)
SN("✅ 已定位初始位置")
local function SW()
    pcall(function()
        VI:SendKeyEvent(true,"W",false,game)
        task.wait(0.8)
        VI:SendKeyEvent(false,"W",false,game)
        SN("✅ 模拟移动完成")
    end)
end
SW()
local VS,AS={},{}
local function FAS()
    if not HR then return{}end
    AS={}
    local U=string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100",game.PlaceId)
    local S,R=pcall(function()
        return HR({Url=U,Method="GET",Timeout=8,Headers={["Content-Type"]="application/json"}})
    end)
    if not S or not R or R.StatusCode~=200 then
        SN("❌ 服务器列表获取失败",true)
        return{}
    end
    local D=HS:JSONDecode(R.Body)
    if not D or not D.data then return{}end
    if #VS>CF.MAX_VISITED_SERVERS then table.clear(VS)end
    local CJ=game.JobId
    for _,S in ipairs(D.data)do
        if S.id~=CJ and S.playing<S.maxPlayers and not VS[S.id]and S.playing>0 then
            table.insert(AS,S.id)
        end
    end
    return AS
end
local function TS()
    if IT then return end
    IT=true
    SN("🌐 查找可用服务器...")
    local S=FAS()
    if #S==0 then
        SN("❌ 无可用服务器，重试中",true)
        task.wait(CF.SERVER_FETCH_RETRY_DELAY)
        IT=false
        TS()
        return
    end
    local T=S[math.random(1,#S)]
    VS[T]=true
    SN("🔄 传送至服务器："..string.sub(T,1,8))
    local S,E=pcall(function()
        TS:TeleportToPlaceInstance(game.PlaceId,T,LP)
    end)
    if not S then
        SN("❌ 传送失败："..tostring(E):sub(1,30),true)
        task.wait(2)
        IT=false
        TS()
    end
end
local function CT()
    return(os.time()-ST)>=CF.TIMEOUT
end
local function API()
    SN("🎯 开始捡物品（优先印钞机）")
    local I=0
    while task.wait(0.1)do
        if CT()then
            SN("⏰ 单服超时，准备换服")
            TS()
            return false
        end
        local F=false
        local IP=W:FindFirstChild("Game")and W.Game:FindFirstChild("Entities")and W.Game.Entities:FindFirstChild("ItemPickup")
        if not IP then continue end
        for _,IF in ipairs(IP:GetChildren())do
            for _,IT in ipairs(IF:GetChildren())do
                if(IT:IsA("MeshPart")or IT:IsA("Part"))and IT:IsDescendantOf(W)then
                    local D=(IT.Position-CF.FORBIDDEN_ZONE.center).Magnitude
                    if D<=CF.FORBIDDEN_ZONE.radius then continue end
                    local P=IT:FindFirstChildWhichIsA("ProximityPrompt")
                    if P then
                        for _,TN in ipairs(CF.TARGET_ITEMS)do
                            if P.ObjectText==TN then
                                F=true
                                I=I+1
                                P.RequiresLineOfSight=false
                                P.HoldDuration=0
                                H.CFrame=IT.CFrame*CFrame.new(0,2,0)
                                task.wait(0.1)
                                if fireproximityprompt then
                                    fireproximityprompt(P)
                                elseif P.Triggered then
                                    P:Triggered(LP)
                                end
                                SN("✅ 捡到："..TN.."（累计"..I.."个）")
                                local ST=tick()
                                local C
                                C=RS.Heartbeat:Connect(function()
                                    if not IT or not IT.Parent then
                                        C:Disconnect()
                                        return
                                    end
                                    if tick()-ST>=CF.PICKUP_TIMEOUT then
                                        IT:Destroy()
                                        C:Disconnect()
                                    end
                                end)
                                task.wait(CF.COLLECT_DELAY)
                            end
                        end
                    end
                end
            end
        end
        if not F and I==0 then
            SN("🔍 无目标物品，切换到银行farming")
            task.wait(1)
            return true
        elseif not F and I>0 then
            SN("✅ 物品拾取完成，切换到银行farming")
            task.wait(1)
            return true
        end
    end
end
local function AFB()
    SN("🏦 开始银行farming")
    while task.wait(0.1)do
        if CT()then
            SN("⏰ 单服超时，准备换服")
            TS()
            return
        end
        local BR=W:FindFirstChild("BankRobbery")
        if not BR then
            SN("❌ 未找到银行区域，准备换服",true)
            task.wait(1)
            TS()
            return
        end
        local BD=BR:FindFirstChild("VaultDoor")
        local BC=BR:FindFirstChild("BankCash")
        if not(BD and BC)then
            SN("❌ 银行组件缺失，准备换服",true)
            task.wait(1)
            TS()
            return
        end
        local CB=BC.Cash:FindFirstChild("Bundle")
        if BD.Door.Attachment.ProximityPrompt.Enabled and CB then
            SN("🔓 打开金库门")
            H.CFrame=CFrame.new(CF.BANK_POSITIONS.vaultDoor)
            BD.Door.Attachment.ProximityPrompt.HoldDuration=0
            if fireproximityprompt then
                fireproximityprompt(BD.Door.Attachment.ProximityPrompt)
            end
            task.wait(0.5)
        elseif not BD.Door.Attachment.ProximityPrompt.Enabled and CB then
            SN("💰 收集银行现金")
            local TP=CB:GetPivot().Position
            local BP=Vector3.new(TP.X,TP.Y-5,TP.Z)
            local LV=(TP-BP).Unit
            H.CFrame=CFrame.new(BP,BP+LV)
            local CP=BC.Main.Attachment.ProximityPrompt
            CP.RequiresLineOfSight=false
            CP.HoldDuration=0
            if fireproximityprompt then
                fireproximityprompt(CP)
            end
            task.wait(0.01)
        else
            SN("🏦 银行无现金，准备换服")
            task.wait(0.5)
            TS()
            return
        end
    end
end
local function ML()
    while true do
        if IT then task.wait(1)continue end
        local IF=API()
        if IF then
            AFB()
        end
        SN("🔄 本轮流程结束，准备换服")
        TS()
    end
end
task.spawn(ML)
SN("🚀 脚本启动成功！白名单验证通过")
]])

-- 解密并执行核心功能
loadstring(D(EC))()
