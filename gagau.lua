-- THIẾT LẬP HỆ THỐNG KẾT NỐI KHÔNG GIAN GAME
game:GetService("HttpService").HttpEnabled = true
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local GaGauUpdate = ReplicatedStorage:WaitForChild("Remote"):WaitForChild("GaGauUpdate")

-- ĐƯỜNG DẪN KẾT NỐI ĐÃ ĐỒNG BỘ ĐƯỜNG DẪN GỐC VỚI TERMUX
local AI_SERVER_URL = "[https://ninety-insects-beg.loca.lt/](https://ninety-insects-beg.loca.lt/)" 
local AI_API_KEY = "HacTrieuAIVip2026"

-- KHAI BÁO UI TỪ BẢN DECOMPILE CỦA BẠN
local FrameGaGau = LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("GaGauGui"):WaitForChild("FrameGaGau")
local HistoryFrame = FrameGaGau:WaitForChild("HistoryFrame")

-- BIẾN HỆ THỐNG QUẢN LÝ
local LastMatchResult = true
local LastBetSide = nil
local LastBetAmount = 0
local CurrentSession = 0
local IsPlacedThisRound = false
local FakeHistoryMemory = {} 

-- HÀM SỬA ĐỔI: QUÉT CHÍNH XÁC TIỀN "VND" TRONG BẢNG XẾP HẠNG LEADERSTATS
local function GetCurrentBalanceFromUI()
    if LocalPlayer then
        -- Truy quét vào thư mục chứa dữ liệu bảng xếp hạng của Script game
        local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
        if leaderstats then
            -- Tìm kiếm chính xác giá trị có tên định dạng là "VND"
            local vndMoney = leaderstats:FindFirstChild("VND")
            if vndMoney then 
                return tonumber(vndMoney.Value) 
            end
        end
    end
    return 100000000 -- Số dư dự phòng 100M nếu hệ thống phản hồi chậm để AI giữ nguyên tỷ lệ chia tiền
end

-- HÀM THU THẬP CHUỖI CẦU HIỆN TẠI TỪ CÁC CHẤM TRÒN TRÊN SÀN GAME
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

-- TẠO GIAO DIỆN HỘP ĐEN - GIỮ NGUYÊN MENU CŨ VÀ ĐỔI TÊN THÀNH AI ĐÁNH GÀ GẤU
if CoreGui:FindFirstChild("HacTrieuFinancialBotV2") then CoreGui.HacTrieuFinancialBotV2:Destroy() end
local ScreenGui = Instance.new("ScreenGui", CoreGui)
ScreenGui.Name = "HacTrieuFinancialBotV2"

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 330, 0, 120)
MainFrame.Position = UDim2.new(0.05, 0, 0.25, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(12, 16, 26)
MainFrame.Active = true
MainFrame.Draggable = true 

local UICorner = Instance.new("UICorner", MainFrame)
UICorner.CornerRadius = UDim.new(0, 8)

local Title = Instance.new("TextLabel", MainFrame)
Title.Size = UDim2.new(1, 0, 0, 30)
Title.Text = "⚡ AI ĐÁNH GÀ GẤU" 
Title.TextColor3 = Color3.fromRGB(0, 255, 153)
Title.BackgroundColor3 = Color3.fromRGB(20, 28, 45)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 12

local LogLabel = Instance.new("TextLabel", MainFrame)
LogLabel.Size = UDim2.new(1, -20, 0, 80)
LogLabel.Position = UDim2.new(0, 10, 0, 35)
LogLabel.Text = "🔄 Đang đồng bộ số dư VND từ Leaderstats và quét thế trận..."
LogLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
LogLabel.TextWrapped = true
LogLabel.Font = Enum.Font.Gotham
LogLabel.TextXAlignment = Enum.TextXAlignment.Left
LogLabel.TextYAlignment = Enum.TextYAlignment.Top
LogLabel.BackgroundTransparency = 1

-- TIẾN TRÌNH XỬ LÝ GỬI THÔNG TIN VÀ RA LỆNH ĐẶT TIỀN TỰ ĐỘNG
local function ProcessAIExecution()
    if IsPlacedThisRound then return end
    IsPlacedThisRound = true

    local currentBalance = GetCurrentBalanceFromUI()
    local currentHistory = GetCurrentHistoryFromUI()
    
    local payload = HttpService:JSONEncode({
        history = currentHistory,
        balance = currentBalance,
        last_match_win = LastMatchResult
    })
    
    LogLabel.Text = "🧠 AI đang phân tích dòng tiền VIP và tính toán độ tự tin..."
    
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
                local ai_bet = tonumber(data.bet_amount) or 3000000 
                
                LogLabel.Text = string.format("💰 Số dư VND: %d\n💬 %s\n➡️ LỆNH: Tự động đặt %d VND vào [%s]", currentBalance, data.advice, ai_bet, ai_target)
                
                LastBetSide = ai_target
                LastBetAmount = ai_bet
                
                -- THỰC THI ĐẶT TIỀN THEO ĐÚNG CẤU TRÚC PHIÊN BẢN GỐC CỦA GAME
                pcall(function()
                    local betData = {
                        side = ai_target,
                        amount = ai_bet
                    }
                    GaGauUpdate:FireServer("Place", betData)
                end)
            end
        else
            LogLabel.Text = "❌ Lỗi kết nối! Đang đợi chu kỳ đếm ngược tiếp theo để lấy lại link..."
            IsPlacedThisRound = false
        end
    end)
end

-- ĐỒNG BỘ DỮ LIỆU SỰ KIỆN TỪ SERVER GAME ROBLOX TRÊN SỰ KIỆN GỐC
GaGauUpdate.OnClientEvent:Connect(function(p1, ...)
    local args = { ... }
    
    if p1 == "SyncState" and args[1] then
        CurrentSession = args[1].sessionNumber or 0
        if args[1].phase == "countdown" and args[1].phaseTimeLeft and args[1].phaseTimeLeft > 15 then
            ProcessAIExecution()
        end
    end
    
    if p1 == "Countdown" then
        local timeLeft = args[1] or 0
        if timeLeft <= 50 and timeLeft >= 20 and not IsPlacedThisRound then
            ProcessAIExecution()
        end
        if timeLeft == 60 then
            IsPlacedThisRound = false
        end
    end
    
    if p1 == "Result" then
        local winningDoor = args[1] 
        CurrentSession = args[3] or (CurrentSession + 1)
        
        table.insert(FakeHistoryMemory, winningDoor)
        if #FakeHistoryMemory > 10 then table.remove(FakeHistoryMemory, 1) end
        
        if LastBetSide ~= nil then
            if LastBetSide == winningDoor then
                LastMatchResult = true
                LogLabel.Text = string.format("🎉 PHIÊN #%06d THẮNG!\nThu về lời lớn: +%d VND.\nTiếp tục phân tích...", CurrentSession, LastBetAmount)
            else
                LastMatchResult = false
                LogLabel.Text = string.format("😭 PHIÊN #%06d CHƯA ĂN!\nTổn thất: -%d VND.\nAI đang kích hoạt cấu trúc bảo toàn vốn...", CurrentSession, LastBetAmount)
            end
        else
            LogLabel.Text = string.format("Phiên #%06d kết thúc. Kết quả: [%s]\nĐang chờ vòng cược mới mở ra...", CurrentSession, winningDoor)
        end
        
        LastBetSide = nil
        LastBetAmount = 0
        IsPlacedThisRound = false
    end
end)

GaGauUpdate:FireServer("RequestSync")
print("[Hắc Triều] Chế độ AI ĐÁNH GÀ GẤU - Whale Mode (Lệnh Lớn) đã chạy!")
