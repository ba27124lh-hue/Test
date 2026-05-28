-- HỆ THỐNG KẾT NỐI VÀ ĐỒNG BỘ DỮ LIỆU CẦU HẮC TRIỀU
game:GetService("HttpService").HttpEnabled = true
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local GaGauUpdate = ReplicatedStorage:WaitForChild("Remote"):WaitForChild("GaGauUpdate")

-- ĐƯỜNG DẪN LOCAL TUNNEL (Thay đổi link này nếu bạn khởi động lại lt)
local AI_SERVER_URL = "https://curly-walls-wash.loca.lt/" 
local AI_API_KEY = "HacTrieuAIVip2026"

local FrameGaGau = LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("GaGauGui"):WaitForChild("FrameGaGau")
local HistoryFrame = FrameGaGau:WaitForChild("HistoryFrame")

local LastMatchResult = true
local LastBetSide = nil
local LastBetAmount = 0
local IsPlacedThisRound = false
local FakeHistoryMemory = {} 

local function GetCurrentBalanceFromUI()
    if LocalPlayer then
        local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
        if leaderstats then
            local vndMoney = leaderstats:FindFirstChild("VND")
            if vndMoney then return tonumber(vndMoney.Value) end
        end
    end
    return 100000000
end

local function GetCurrentHistoryFromUI()
    local historyList = {}
    for _, child in ipairs(HistoryFrame:GetChildren()) do
        if child:IsA("ImageLabel") and child.Name == "HistoryDot" then
            if child.Image == "rbxassetid://80209267344815" then
                table.insert(historyList, "Ga")
            elseif child.Image == "rbxassetid://79945118847683" then
                table.insert(historyList, "Gau")
            end
        end
    end
    if #historyList == 0 then return FakeHistoryMemory end
    return historyList
end

-- Khởi tạo UI hiển thị thông tin trạng thái tool trong game
if CoreGui:FindFirstChild("HacTrieuFinancialBotV3") then CoreGui.HacTrieuFinancialBotV3:Destroy() end
local ScreenGui = Instance.new("ScreenGui", CoreGui)
ScreenGui.Name = "HacTrieuFinancialBotV3"

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 340, 0, 130)
MainFrame.Position = UDim2.new(0.05, 0, 0.25, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(10, 14, 22)
MainFrame.Active = true
MainFrame.Draggable = true 

local UICorner = Instance.new("UICorner", MainFrame)
UICorner.CornerRadius = UDim.new(0, 8)

local Title = Instance.new("TextLabel", MainFrame)
Title.Size = UDim2.new(1, 0, 0, 30)
Title.Text = "⚔️ HẮC TRIỀU VIP BOT - USER: " .. LocalPlayer.Name
Title.TextColor3 = Color3.fromRGB(0, 255, 153)
Title.BackgroundColor3 = Color3.fromRGB(18, 24, 38)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 12

local LogLabel = Instance.new("TextLabel", MainFrame)
LogLabel.Size = UDim2.new(1, -20, 0, 90)
LogLabel.Position = UDim2.new(0, 10, 0, 35)
LogLabel.Text = "🔄 Đang đồng bộ hóa dữ liệu sever và gửi thông tin..."
LogLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
LogLabel.TextWrapped = true
LogLabel.Font = Enum.Font.Gotham
LogLabel.TextXAlignment = Enum.TextXAlignment.Left
LogLabel.TextYAlignment = Enum.TextYAlignment.Top
LogLabel.BackgroundTransparency = 1

local function ProcessAIExecution()
    if IsPlacedThisRound then return end
    IsPlacedThisRound = true

    local currentBalance = GetCurrentBalanceFromUI()
    local currentHistory = GetCurrentHistoryFromUI()
    
    -- GỬI ĐẦY ĐỦ USERNAME, LỊCH SỬ VÀ SỐ DƯ SANG TERMUX
    local payload = HttpService:JSONEncode({
        username = LocalPlayer.Name,
        history = currentHistory,
        balance = currentBalance,
        last_match_win = LastMatchResult
    })
    
    task.spawn(function()
        local success, response = pcall(function()
            return HttpService:RequestAsync({
                Url = AI_SERVER_URL,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json",
                    ["Authorization"] = AI_API_KEY,
                    ["bypass-tunnel-reminder"] = "true"
                },
                Body = payload
            })
        end)
        
        if success and response.Success then
            local decodeSuccess, data = pcall(function() return HttpService:JSONDecode(response.Body) end)
            if decodeSuccess and data then
                local ai_target = data.predict      
                local ai_bet = tonumber(data.bet_amount)
                
                LogLabel.Text = string.format("👤 User: %s\n💬 Phân tích: %s\n➡️ ĐẶT CỬA: %d VNĐ vào [%s]", LocalPlayer.Name, data.advice, ai_bet, ai_target)
                
                LastBetSide = ai_target
                LastBetAmount = ai_bet
                
                pcall(function()
                    local betData = { side = ai_target, amount = ai_bet }
                    GaGauUpdate:FireServer("Place", betData)
                end)
            else
                IsPlacedThisRound = false
            end
        else
            LogLabel.Text = "❌ Lỗi kết nối Termux hoặc đang đợi mở phiên mới..."
            IsPlacedThisRound = false
        end
    end)
end

GaGauUpdate.OnClientEvent:Connect(function(p1, ...)
    local args = { ... }
    if p1 == "SyncState" and args[1] then
        if args[1].phase == "countdown" and args[1].phaseTimeLeft and args[1].phaseTimeLeft > 15 then
            ProcessAIExecution()
        end
    end
    if p1 == "Countdown" then
        local timeLeft = args[1] or 0
        if timeLeft <= 50 and timeLeft >= 15 and not IsPlacedThisRound then
            ProcessAIExecution()
        end
        if timeLeft == 60 then IsPlacedThisRound = false end
    end
    if p1 == "Result" then
        local winningDoor = args[1] 
        table.insert(FakeHistoryMemory, winningDoor)
        if #FakeHistoryMemory > 14 then table.remove(FakeHistoryMemory, 1) end
        if LastBetSide ~= nil then
            LastMatchResult = (LastBetSide == winningDoor)
        end
        LastBetSide = nil
        LastBetAmount = 0
        IsPlacedThisRound = false
    end
end)

GaGauUpdate:FireServer("RequestSync")
print("[HẮC TRIỀU] Script khởi chạy thành công! Đang đồng bộ User: " .. LocalPlayer.Name)
