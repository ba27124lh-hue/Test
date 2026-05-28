game:GetService("HttpService").HttpEnabled = true
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

local GaGauUpdate = ReplicatedStorage:WaitForChild("Remote"):WaitForChild("GaGauUpdate")
local AutoBetRemote = ReplicatedStorage:WaitForChild("Remote"):WaitForChild("PlaceBet") -- Bạn kiểm tra xem Remote đặt cược của game tên là gì nhé

local AI_SERVER_URL = "[https://grumpy-carpets-help.loca.lt/predict](https://grumpy-carpets-help.loca.lt/predict)" 
local AI_API_KEY = "HacTrieuAIVip2026"

local LastMatchResult = true -- Trạng thái ván trước thắng hay thua

-- HÀM QUÉT SỐ TIỀN TỰ ĐỘNG CỦA BẠN TRONG GAME
local function GetCurrentBalance()
    local player = Players.LocalPlayer
    if player then
        -- Thử tìm trong Leaderstats của người chơi
        local leaderstats = player:FindFirstChild("leaderstats")
        if leaderstats then
            local cash = leaderstats:FindFirstChild("Cash") or leaderstats:FindFirstChild("Coins") or leaderstats:FindFirstChild("Money")
            if cash then return cash.Value end
        end
        -- Thử tìm trong Data lưu trữ riêng của Player
        local data = player:FindFirstChild("Data") or player:FindFirstChild("PlayerGui")
        -- Mẹo dự phòng nếu không tìm ra đối tượng số: Trả về số mặc định để AI chia tỷ lệ
        return player:getAttribute("Balance") or 50000 
    end
    return 50000
end

-- TẠO UI HIỂN THỊ TRẠNG THÁI TỰ ĐỘNG ĐÁNH (AUTO BET)
if CoreGui:FindFirstChild("HacTrieuAutoBet_V1") then CoreGui.HacTrieuAutoBet_V1:Destroy() end
local ScreenGui = Instance.new("ScreenGui", CoreGui)
ScreenGui.Name = "HacTrieuAutoBet_V1"

local Frame = Instance.new("Frame", ScreenGui)
Frame.Size = UDim2.new(0, 300, 0, 130)
Frame.Position = UDim2.new(0.1, 0, 0.2, 0)
Frame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)

local StatusLabel = Instance.new("TextLabel", Frame)
StatusLabel.Size = UDim2.new(1, 0, 0, 40)
StatusLabel.Text = "🤖 HẮC TRIỀU AUTO-BET BOT: ĐANG KHỞI ĐỘNG..."
StatusLabel.TextColor3 = Color3.fromRGB(0, 255, 204)
StatusLabel.Font = Enum.Font.GothamBold
StatusLabel.TextSize = 12

local LogLabel = Instance.new("TextLabel", Frame)
LogLabel.Size = UDim2.new(1, -20, 0, 70)
LogLabel.Position = UDim2.new(0, 10, 0, 45)
LogLabel.Text = "Đang quét số dư tài khoản và đợi phiên mới..."
LogLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
LogLabel.TextWrapped = true
LogLabel.Font = Enum.Font.Gotham

-- HÀM GỬI DỮ LIỆU LÊN TERMUX VÀ THỰC THI LỆNH ĐẶT CỰC TỰ ĐỘNG
local function AutoProcessRound(historyData)
    local myBalance = GetCurrentBalance()
    
    local payload = HttpService:JSONEncode({
        history = historyData,
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
                local targeted_door = data.predict       -- Cửa AI chọn: "Ga" hoặc "Gau"
                local amount_to_bet = data.bet_amount    -- Số tiền AI tính toán cược
                
                LogLabel.Text = string.format("Phân tích: %s\n➡️ LỆNH: Đặt %d xu vào cửa [%s]", data.advice, amount_to_bet, targeted_door)
                
                -- HỆ THỐNG TỰ ĐỘNG XUẤT LỆNH ĐẶT VÀO REMOTE CỦA SERVER GAME ROBLOX
                pcall(function()
                    -- Cấu trúc này tùy thuộc vào cấu hình script của game, thông thường là: Remote:FireServer(Cửa_Đặt, Số_Tiền)
                    AutoBetRemote:FireServer(targeted_door, amount_to_bet)
                end)
            end
        else
            LogLabel.Text = "❌ Lỗi kết nối đến Termux! Vui lòng kiểm tra lại tab 'lt' và lệnh python."
        end
    end)
end

-- LẮNG NGHE ĐỒNG BỘ TỪ SERVER GAME ĐỂ AUTO ĐÁNH MỖI VÒNG
GaGauUpdate.OnClientEvent:Connect(function(method, ...)
    local args = { ... }
    if method == "SyncState" and args[1] then
        local fullHistory = {}
        if args[1].history then
            fullHistory = args[1].history
        else
            for _, v in pairs(args[1]) do
                if type(v) == "table" and (#v > 0) and (v[1] == "Ga" or v[1] == "Gau") then
                    fullHistory = v
                    break
                end
            end
        end
        -- Tiến hành kích hoạt bộ não quản lý tài chính và tự động đặt
        AutoProcessRound(fullHistory)
    end
    
    -- Kiểm tra kết quả trận đấu vừa rồi để tính toán chuỗi thắng/thua
    if method == "Result" and args[1] then
        local currentWinner = args[1].Winner -- Giả định cấu trúc game trả về tên cửa thắng
        -- Bạn tự cấu hình logic kiểm tra xem cửa mình vừa đặt có trùng với Winner hay không để gán true/false cho LastMatchResult nhé
        task.wait(2)
        GaGauUpdate:FireServer("RequestSync")
    end
end)

GaGauUpdate:FireServer("RequestSync")
print("Bot Auto Bet Hắc Triều quản lý vốn thông minh đã kích hoạt!")
