-- THIẾT LẬP HỆ THỐNG KẾT NỐI
game:GetService("HttpService").HttpEnabled = true
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local GaGauUpdate = ReplicatedStorage:WaitForChild("Remote"):WaitForChild("GaGauUpdate")

-- ĐƯỜNG DẪN ĐẾN FILE PYTHON TRÊN TERMUX (ĐÃ FIX BỎ /PREDICT ĐỂ HẾT LỖI 404)
local AI_SERVER_URL = "https://ninety-insects-beg.loca.lt/" 
local AI_API_KEY = "HacTrieuAIVip2026"

-- ĐƯỜNG DẪN UI GỐC CỦA GAME (Dựa theo code decompile bạn gửi)
local FrameGaGau = LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("GaGauGui"):WaitForChild("FrameGaGau")
local HistoryFrame = FrameGaGau:WaitForChild("HistoryFrame")

-- BIẾN QUẢN LÝ TRẠNG THÁI
local LastMatchResult = true
local LastBetSide = nil
local LastBetAmount = 0
local CurrentSession = 0
local IsPlacedThisRound = false
local FakeHistoryMemory = {} -- Bộ nhớ đệm tự lưu lịch sử cầu nếu game không đồng bộ mảng

-- HÀM QUÉT SỐ TIỀN TRỰC TIẾP TỪ GIAO DIỆN GAME (UI SCANNER)
local function GetCurrentBalanceFromUI()
    -- Thử quét nhãn hiển thị tiền chung trên UI Gà Gấu nếu có
    local moneyLabel = FrameGaGau:FindFirstChild("MoneyLabel") or FrameGaGau:FindFirstChild("BalanceLabel") or FrameGaGau:FindFirstChild("TokenLabel")
    if moneyLabel then
        local cleanNet = moneyLabel.Text:gsub(",", ""):gsub("%$", ""):match("%d+")
        if cleanNet then return tonumber(cleanNet) end
    end
    
    -- Cách dự phòng 2: Quét từ leaderstats của hệ thống người chơi
    if LocalPlayer then
        local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
        if leaderstats then
            local cash = leaderstats:FindFirstChild("Cash") or leaderstats:FindFirstChild("Coins") or leaderstats:FindFirstChild("Money") or leaderstats:FindFirstChild("Xu")
            if cash then return cash.Value end
        end
    end
    return 50000 -- Số dư mặc định để AI tính toán tỷ lệ % nếu không quét ra UI tiền
end

-- HÀM QUÉT LỊCH SỬ CẦU TỪ CÁC CHẤM TRÒN TRÊN MÀN HÌNH (HISTORY SCANNER)
local function GetCurrentHistoryFromUI()
    local historyList = {}
    for _, child in ipairs(HistoryFrame:GetChildren()) do
        if child:IsA("ImageLabel") and child.Name == "HistoryDot" then
            -- Nhận diện Gà hay Gấu dựa vào ID ảnh gốc của game
            if child.Image == "rbxassetid://80209267344815" then
                table.insert(historyList, "Ga")
            elseif child.Image == "rbxassetid://79945118847683" then
                table.insert(historyList, "Gau")
            end
        end
    end
    
    -- Nếu danh sách UI trống, sử dụng bộ nhớ đệm tự lưu
    if #historyList == 0 then
        return FakeHistoryMemory
    end
    return historyList
end

-- KHỞI TẠO MENU THÔNG BÁO RIÊNG CỦA BOT HẮC TRIỀU (ĐÃ ĐỔI TÊN THÀNH AI ĐÁNH GÀ GẤU)
if CoreGui:FindFirstChild("HacTrieuFinancialBotV2") then CoreGui.HacTrieuFinancialBotV2:Destroy() end
local ScreenGui = Instance.new("ScreenGui", CoreGui)
ScreenGui.Name = "HacTrieuFinancialBotV2"

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 330, 0, 120)
MainFrame.Position = UDim2.new(0.05, 0, 0.25, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(12, 16, 26)
MainFrame.Active = true
MainFrame.Draggable = true -- Bạn có thể kéo menu này di chuyển trên màn hình điện thoại

local UICorner = Instance.new("UICorner", MainFrame)
UICorner.CornerRadius = UDim.new(0, 8)

local Title = Instance.new("TextLabel", MainFrame)
Title.Size = UDim2.new(1, 0, 0, 30)
Title.Text = "⚡ AI ĐÁNH GÀ GẤU" -- Đã cập nhật tên theo yêu cầu
Title.TextColor3 = Color3.fromRGB(0, 255, 153)
Title.BackgroundColor3 = Color3.fromRGB(20, 28, 45)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 12

local LogLabel = Instance.new("TextLabel", MainFrame)
LogLabel.Size = UDim2.new(1, -20, 0, 80)
LogLabel.Position = UDim2.new(0, 10, 0, 35)
LogLabel.Text = "🔄 Đang kết nối server Termux và đợi phiên mới..."
LogLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
LogLabel.TextWrapped = true
LogLabel.Font = Enum.Font.Gotham
LogLabel.TextXAlignment = Enum.TextXAlignment.Left
LogLabel.TextYAlignment = Enum.TextYAlignment.Top
LogLabel.BackgroundTransparency = 1

-- HÀM GỬI DATA CHO AI VÀ TỰ ĐỘNG ĐẶT TIỀN QUẢN LÝ VỐN
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
    
    LogLabel.Text = "🧠 AI đang phân tích dòng vốn và thuật toán cầu..."
    
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
                local ai_target = data.predict      -- Cửa AI chọn: "Ga" hoặc "Gau"
                local ai_bet = tonumber(data.bet_amount) or 10 -- Số tiền cược AI ra lệnh
                
                LogLabel.Text = string.format("💰 Vốn quét: %d xu\n💬 %s\n➡️ LỆNH: Tự động đặt %d xu vào [%s]", currentBalance, data.advice, ai_bet, ai_target)
                
                -- Ghi nhớ dữ liệu phiên này để tính toán thắng thua sau đó
                LastBetSide = ai_target
                LastBetAmount = ai_bet
                
                -- BẮN LỆNH ĐẶT TIỀN THẲNG LÊN SERVER GAME (Sao chép chuẩn từ dòng 301 code gốc)
                pcall(function()
                    local betData = {
                        side = ai_target,
                        amount = ai_bet
                    }
                    GaGauUpdate:FireServer("Place", betData)
                end)
            end
        else
            LogLabel.Text = "❌ Lỗi kết nối Termux! Đang thử lại ở chu kỳ sau..."
            IsPlacedThisRound = false
        end
    end)
end

-- LẮNG NGHE SỰ KIỆN ĐỒNG BỘ ĐỂ KÍCH HOẠT AUTO-BET KHÔNG BỊ TRỄ NHỊP
GaGauUpdate.OnClientEvent:Connect(function(p1, ...)
    local args = { ... }
    
    -- Khi game gửi trạng thái đồng bộ ban đầu
    if p1 == "SyncState" and args[1] then
        CurrentSession = args[1].sessionNumber or 0
        if args[1].phase == "countdown" and args[1].phaseTimeLeft and args[1].phaseTimeLeft > 15 then
            ProcessAIExecution()
        end
    end
    
    -- Khi game đang đếm ngược (Thời gian vàng để đặt tiền)
    if p1 == "Countdown" then
        local timeLeft = args[1] or 0
        -- Kích hoạt lệnh đặt tiền từ giây thứ 50 đến giây thứ 20 (Tránh vùng 10 giây cuối bị khóa cược)
        if timeLeft <= 50 and timeLeft >= 20 and not IsPlacedThisRound then
            ProcessAIExecution()
        end
        
        -- Reset trạng thái khi bắt đầu phiên hoàn toàn mới (giây thứ 60)
        if timeLeft == 60 then
            IsPlacedThisRound = false
        end
    end
    
    -- Khi game công bố kết quả xúc xắc (Xử lý tính toán lời/lỗ để gấp thếp vòng sau)
    if p1 == "Result" then
        local winningDoor = args[1] -- "Ga" hoặc "Gau"
        CurrentSession = args[3] or (CurrentSession + 1)
        
        -- Thêm vào bộ nhớ đệm lịch sử
        table.insert(FakeHistoryMemory, winningDoor)
        if #FakeHistoryMemory > 10 then table.remove(FakeHistoryMemory, 1) end
        
        if LastBetSide ~= nil then
            if LastBetSide == winningDoor then
                LastMatchResult = true
                LogLabel.Text = string.format("🎉 PHIÊN #%06d THẮNG!\nNhận về: +%d xu.\nĐang chuẩn bị vòng tiếp theo...", CurrentSession, LastBetAmount)
            else
                LastMatchResult = false
                LogLabel.Text = string.format("😭 PHIÊN #%06d THUA!\nThất thoát: -%d xu.\nAI đang lên kế hoạch đi tiền hoàn vốn...", CurrentSession, LastBetAmount)
            end
        else
            LogLabel.Text = string.format("Phiên #%06d kết thúc. Kết quả: [%s]\nĐang chờ phiên mới mở...", CurrentSession, winningDoor)
        end
        
        -- Xóa dữ liệu cược cũ để chuẩn bị cho chu kỳ mới
        LastBetSide = nil
        LastBetAmount = 0
        IsPlacedThisRound = false
    end
end)

-- Gửi lệnh đồng bộ ban đầu để kích hoạt chu kỳ quét ngầm
GaGauUpdate:FireServer("RequestSync")
print("[Hắc Triều] AI ĐÁNH GÀ GẤU đã được kích hoạt thành công!")

