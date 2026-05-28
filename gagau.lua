-- THIẾT LẬP KẾT NỐI HỆ THỐNG
game:GetService("HttpService").HttpEnabled = true
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local GaGauUpdate = ReplicatedStorage:WaitForChild("Remote"):WaitForChild("GaGauUpdate")

-- CẤU HÌNH ĐƯỜNG DẪN KẾT NỐI ĐẾN TERMUX CỦA BẠN
local AI_SERVER_URL = "https://grumpy-carpets-help.loca.lt/predict" 
local AI_API_KEY = "HacTrieuAIVip2026"

-- BIẾN THEO DÕI TRẠNG THÁI TÀI CHÍNH
local LastMatchResult = true
local LastBetSide = nil
local LastBetAmount = 0
local CurrentSession = 0
local IsWaitingResponse = false

-- HÀM QUÉT TIỀN TỰ ĐỘNG (Tự động tìm ví tiền của bạn trong Game)
local function GetCurrentBalance()
    if LocalPlayer then
        -- 1. Tìm trong bảng điểm chung (Leaderstats)
        local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
        if leaderstats then
            local cash = leaderstats:FindFirstChild("Cash") or leaderstats:FindFirstChild("Coins") or leaderstats:FindFirstChild("Money") or leaderstats:FindFirstChild("Xu")
            if cash then return cash.Value end
        end
        -- 2. Tìm trong Data/PlayerGui (Dự phòng dựa trên các game phổ biến)
        local data = LocalPlayer:FindFirstChild("Data")
        if data and data:FindFirstChild("Balance") then return data.Balance.Value end
    end
    return 100000 -- Trả về số dư giả định nếu game ẩn ví tiền quá sâu để AI tính tỷ lệ %
end

-- TẠO UI THÔNG BÁO TRẠNG THÁI AUTO-BET TRÊN MÀN HÌNH
if CoreGui:FindFirstChild("HacTrieuFinancialBot") then CoreGui.HacTrieuFinancialBot:Destroy() end
local ScreenGui = Instance.new("ScreenGui", CoreGui)
ScreenGui.Name = "HacTrieuFinancialBot"

local Frame = Instance.new("Frame", ScreenGui)
Frame.Size = UDim2.new(0, 320, 0, 110)
Frame.Position = UDim2.new(0.05, 0, 0.25, 0)
Frame.BackgroundColor3 = Color3.fromRGB(10, 14, 22)
Frame.BorderSizePixel = 0

local UICorner = Instance.new("UICorner", Frame)
UICorner.CornerRadius = UDim.new(0, 8)

local TitleLabel = Instance.new("TextLabel", Frame)
TitleLabel.Size = UDim2.new(1, 0, 0, 30)
TitleLabel.Text = "🤖 HẮC TRIỀU FINANCIAL AUTO-BET v1.0"
TitleLabel.TextColor3 = Color3.fromRGB(0, 255, 153)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 12
TitleLabel.BackgroundColor3 = Color3.fromRGB(18, 24, 38)

local LogLabel = Instance.new("TextLabel", Frame)
LogLabel.Size = UDim2.new(1, -20, 0, 70)
LogLabel.Position = UDim2.new(0, 10, 0, 35)
LogLabel.Text = "Đang đồng bộ dữ liệu phiên và số dư tài khoản..."
LogLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
LogLabel.TextWrapped = true
LogLabel.Font = Enum.Font.Gotham
LogLabel.TextXAlignment = Enum.TextXAlignment.Left
LogLabel.BackgroundTransparency = 1

-- HÀM XỬ LÝ GỬI THÔNG TIN VÀ TỰ ĐỘNG ĐẶT CƯỢC
local function RequestAIAndPlaceBet(historyList)
    if IsWaitingResponse then return end
    IsWaitingResponse = true

    local myBalance = GetCurrentBalance()
    
    -- Đóng gói dữ liệu gửi lên Termux
    local payload = HttpService:JSONEncode({
        history = historyList,
        balance = myBalance,
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
                local target_door = data.predict       -- "Ga" hoặc "Gau"
                local bet_amount = data.bet_amount    -- Số tiền AI tính toán hoàn vốn/kiếm lời
                
                LogLabel.Text = string.format("Số dư: %d\n%s\n➡️ LỆNH: Đặt %d vào [%s]", myBalance, data.advice, bet_amount, target_door)
                
                -- Ghi nhận dữ liệu cược để kiểm tra thắng thua ở ván sau
                LastBetSide = target_door
                LastBetAmount = bet_amount
                
                -- THỰC THI LỆNH ĐẶT CƯỢC THEO ĐÚNG CẤU TRÚC CODE GỐC CỦA GAME
                pcall(function()
                    local betStructure = {
                        side = target_door,
                        amount = tonumber(bet_amount)
                    }
                    GaGauUpdate:FireServer("Place", betStructure)
                end)
            end
        else
            LogLabel.Text = "❌ Mất kết nối đến Termux! Vui lòng kiểm tra lại tab 'lt' hoặc script python."
        end
        IsWaitingResponse = false
    end)
end

-- LẮNG NGHE ĐỒNG BỘ SỰ KIỆN TỪ GAME (Dựa trên Event gốc của trò chơi)
GaGauUpdate.OnClientEvent:Connect(function(p1, ...)
    local t = { ... }
    
    -- Trường hợp 1: Đồng bộ trạng thái toàn cục khi vừa vào game
    if p1 == "SyncState" and t[1] then
        CurrentSession = t[1].sessionNumber or 0
        if t[1].phase == "countdown" and t[1].phaseTimeLeft and t[1].phaseTimeLeft > 15 then
            RequestAIAndPlaceBet(t[1].history or {})
        end
    end
    
    -- Trường hợp 2: Khi game bắt đầu đếm ngược phiên mới (Thời gian tốt nhất để đặt cược)
    if p1 == "Countdown" then
        local timeLeft = t[1]
        -- Chỉ ra lệnh đặt khi thời gian còn nhiều (ví dụ từ giây thứ 55 đến giây thứ 15), né 10 giây cuối bị khóa cược (Dòng 193 code gốc)
        if timeLeft <= 55 and timeLeft >= 15 and not IsWaitingResponse then
            -- Gọi SyncState tạm thời để lấy mảng lịch sử cầu chính xác nhất
            GaGauUpdate:FireServer("RequestSync")
        end
    end
    
    -- Trường hợp 3: Khi game trả kết quả (Xử lý tính toán thắng thua để tính tiền vòng sau)
    if p1 == "Result" then
        local currentWinner = t[1] -- "Ga" hoặc "Gau"
        CurrentSession = t[3] or (CurrentSession + 1)
        
        if LastBetSide ~= nil then
            if LastBetSide == currentWinner then
                LastMatchResult = true
                LogLabel.Text = string.format("🎉 Phiên #%06d THẮNG! +%d xu. Đang đợi phiên mới...", CurrentSession, LastBetAmount)
            else
                LastMatchResult = false
                LogLabel.Text = string.format("😭 Phiên #%06d THUA! -%d xu. AI đang tính toán lệnh gấp thếp hoàn vốn...", CurrentSession, LastBetAmount)
            end
        else
            LogLabel.Text = string.format("Phiên #%06d Kết quả: [%s]. Đang đợi phiên mới...", CurrentSession, currentWinner)
        end
        
        -- Reset trạng thái cược của phiên cũ
        LastBetSide = nil
        LastBetAmount = 0
    end
end)

-- Kích hoạt đồng bộ ban đầu
GaGauUpdate:FireServer("RequestSync")
print("[Hắc Triều] Hệ thống Auto-Bet quản lý vốn thông minh đã sẵn sàng!")
