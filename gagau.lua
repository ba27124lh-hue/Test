-- ÉP BUỘC MỞ QUYỀN KẾT NỐI HTTP CHO EXECUTOR DELTA
game:GetService("HttpService").HttpEnabled = true

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local GaGauUpdate = ReplicatedStorage:WaitForChild("Remote"):WaitForChild("GaGauUpdate")

-- ĐƯỜNG TRUYỀN LOCALTUNNEL TERMUX MỚI CỦA BẠN (ĐÃ CẬP NHẬT CHUẨN)
local AI_SERVER_URL = "https://grumpy-carpets-help.loca.lt/predict" 
local AI_API_KEY = "HacTrieuAIVip2026"

-- XÓA UI CŨ NẾU CÓ TRÁNH LỖI ĐÈ GIAO DIỆN
if CoreGui:FindFirstChild("GaGauGroqV6_1") then 
    CoreGui.GaGauGroqV6_1:Destroy() 
end

-- TẠO GIAO DIỆN NGƯỜI DÙNG CYBERPUNK DASHBOARD
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "GaGauGroqV6_1"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = CoreGui

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 290, 0, 165)
MainFrame.Position = UDim2.new(0.1, 0, 0.35, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 14)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(0, 255, 204)
MainStroke.Thickness = 1.5
MainStroke.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 35)
Title.Text = "🧠 GROQ SMART AI PREDICTOR V6.1"
Title.TextColor3 = Color3.fromRGB(0, 255, 204)
Title.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 12
Title.Parent = MainFrame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 14)
TitleCorner.Parent = Title

local GaBar = Instance.new("TextLabel")
GaBar.Size = UDim2.new(0.44, 0, 0, 45)
GaBar.Position = UDim2.new(0, 12, 0, 50)
GaBar.BackgroundColor3 = Color3.fromRGB(236, 70, 70)
GaBar.Text = "GÀ\n--"
GaBar.TextColor3 = Color3.fromRGB(255, 255, 255)
GaBar.Font = Enum.Font.GothamBold
GaBar.TextSize = 15
GaBar.Parent = MainFrame

local GaCorner = Instance.new("UICorner")
GaCorner.CornerRadius = UDim.new(0, 8)
GaCorner.Parent = GaBar

local GauBar = Instance.new("TextLabel")
GauBar.Size = UDim2.new(0.44, 0, 0, 45)
GauBar.Position = UDim2.new(0.56, -12, 0, 50)
GauBar.BackgroundColor3 = Color3.fromRGB(52, 131, 250)
GauBar.Text = "GẤU\n--"
GauBar.TextColor3 = Color3.fromRGB(255, 255, 255)
GauBar.Font = Enum.Font.GothamBold
GauBar.TextSize = 15
GauBar.Parent = MainFrame

local GauCorner = Instance.new("UICorner")
GauCorner.CornerRadius = UDim.new(0, 8)
GauCorner.Parent = GauBar

local AdviceLabel = Instance.new("TextLabel")
AdviceLabel.Size = UDim2.new(1, -24, 0, 48)
AdviceLabel.Position = UDim2.new(0, 12, 0, 105)
AdviceLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
AdviceLabel.Text = "⚡ Đang kết nối mượt mà tới Termux..."
AdviceLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
AdviceLabel.Font = Enum.Font.GothamBold
AdviceLabel.TextSize = 12
AdviceLabel.TextWrapped = true
AdviceLabel.Parent = MainFrame

local AdviceCorner = Instance.new("UICorner")
AdviceCorner.CornerRadius = UDim.new(0, 8)
AdviceCorner.Parent = AdviceLabel

-- HỆ THỐNG KÉO THẢ GIAO DIỆN TRÊN ĐIỆN THOẠI
local dragging, dragInput, dragStart, startPos
local function update(input)
    local delta = input.Position - dragStart
    local targetPos = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    TweenService:Create(MainFrame, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = targetPos}):Play()
end
MainFrame.InputBegan:Connect(function(input) 
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then 
        dragging = true dragStart = input.Position startPos = MainFrame.Position 
        input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end) 
    end 
end)
MainFrame.InputChanged:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end end)
UserInputService.InputChanged:Connect(function(input) if input == dragInput and dragging then update(input) end end)

-- CHUYỂN DỮ LIỆU CẦU VÀ NHẬN KẾT QUẢ AI TỪ TERMUX VIA REQUESTASYNC
local function FetchGroqPrediction(historyData)
    local jsonPayload = HttpService:JSONEncode({ history = historyData })
    
    task.spawn(function()
        local success, response = pcall(function()
            return HttpService:RequestAsync({
                Url = AI_SERVER_URL,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json",
                    ["Authorization"] = AI_API_KEY,
                    -- Thêm Header chặn trang thông báo phiền phức của Localtunnel
                    ["bypass-tunnel-reminder"] = "true", 
                    ["Bypass-Tunnel-Reminder"] = "1",
                    ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
                },
                Body = jsonPayload
            })
        end)
        
        if success and response.Success then
            local successDecode, data = pcall(function()
                return HttpService:JSONDecode(response.Body)
            end)
            
            if successDecode and data then
                GaBar.Text = string.format("GÀ\n%d%%", data.percent_ga or 50)
                GauBar.Text = string.format("GẤU\n%d%%", data.percent_gau or 50)
                AdviceLabel.Text = data.advice or "🤖 AI đang tính toán dữ liệu thế cầu..."
                AdviceLabel.TextColor3 = Color3.fromRGB(0, 255, 204)
            else
                AdviceLabel.Text = "❌ Lỗi: Cấu trúc JSON trả về không đúng mẫu phân tích."
                AdviceLabel.TextColor3 = Color3.fromRGB(255, 150, 0)
            end
        else
            GaBar.Text = "GÀ\nERR" GauBar.Text = "GẤU\nERR"
            AdviceLabel.Text = "❌ Mất kết nối! Hãy kiểm tra tab 'python gagau.py' và tab 'lt' trên Termux."
            AdviceLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
        end
    end)
end

-- LẮNG NGHE SỰ KIỆN REMOTEEVENT ĐỂ ĐỒNG BỘ LỊCH SỬ PHIÊN
GaGauUpdate.OnClientEvent:Connect(function(method, ...)
    local args = { ... }
    if method == "SyncState" and args[1] then
        local fullHistory = {}
        
        if args[1].FullHistory then
            fullHistory = args[1].FullHistory
        elseif args[1].history then
            fullHistory = args[1].history
        else
            for _, v in pairs(args[1]) do
                if type(v) == "table" and (#v > 0) and (v[1] == "Ga" or v[1] == "Gau") then
                    fullHistory = v
                    break
                end
            end
        end
        
        FetchGroqPrediction(fullHistory)
    end
    
    if method == "Result" then
        task.wait(1.5)
        GaGauUpdate:FireServer("RequestSync")
    end
end)

GaGauUpdate:FireServer("RequestSync")
print("[Hac Trieu Groq V6.1 Nâng Cấp]: Khởi chạy Script game hoàn tất!")
