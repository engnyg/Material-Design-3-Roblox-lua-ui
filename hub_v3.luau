--[[
    LY Hub - Material Design 3 Category & Subcategory Architecture
    Visual & Effects Edition:
    1. Search/Settings button replaces close button
    2. Background dimming backdrop on UI toggle
    3. Smooth snowfall particle effect behind the UI
    4. Window transparency & real-time scaling controls
    5. Pure layout skeleton for categories (strictly no unauthorized features)
--]]

-- Clean up previous window on re-execution
if typeof(getgenv) == "function" and getgenv().CurrentMD3Window then
    pcall(function() getgenv().CurrentMD3Window:Destroy() end)
    getgenv().CurrentMD3Window = nil
end

local MD3 = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/engnyg/Material-Design-3-Roblox-lua-ui/main/dist/MaterialDesign3.luau"
))()

local Window = MD3:CreateWindow({
    Title = "LY Hub",
    Subtitle = "v1.0",
    Icon = nil,                          -- Top-left icon (disabled)
    Logo = nil,                          -- Logo image (disabled)
    Mode = "Dark",                       -- "Light" | "Dark"
    ThemeColor = Color3.fromHex("#6750A4"), -- Primary theme color
    Size = UDim2.fromOffset(720, 460),   -- Window dimensions
    ToggleKey = Enum.KeyCode.RightShift, -- Toggle key
    ConfigFolder = "LYHub",              -- Config folder in executor workspace
    IconStyle = "Outlined",              -- Icon style
    LoadingScreen = true,                -- Splash screen
    Silent = false,
    KeybindNotify = true,
})

if typeof(getgenv) == "function" then
    getgenv().CurrentMD3Window = Window
end

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local camera = workspace.CurrentCamera

-- ==================== 1. Top Bar Optimization (Remove '-', Add Top-Left Settings Search) ====================
local topBar = Window.Instance:FindFirstChild("TopBar")
local searchInputBox = nil
local searchDropdown = nil

if topBar then
    local actions = topBar:FindFirstChild("Actions")
    if actions then
        local closeBtn = actions:FindFirstChild("close")
        if closeBtn then closeBtn:Destroy() end
        local minBtn = actions:FindFirstChild("minimize")
        if minBtn then minBtn:Destroy() end
        actions.Visible = false
    end

    -- Create Search Box in Top-Left (next to Titles)
    local searchBox = Instance.new("Frame")
    searchBox.Name = "LY_TopLeftSearchBox"
    searchBox.Size = UDim2.new(0, 220, 0, 32)
    searchBox.Position = UDim2.new(0, 130, 0.5, 0)
    searchBox.AnchorPoint = Vector2.new(0, 0.5)
    searchBox.BackgroundColor3 = Color3.fromRGB(30, 28, 38)
    searchBox.BackgroundTransparency = 0.2
    searchBox.BorderSizePixel = 0
    searchBox.ZIndex = 5
    searchBox.Parent = topBar

    local boxCorner = Instance.new("UICorner")
    boxCorner.CornerRadius = UDim.new(0, 8)
    boxCorner.Parent = searchBox

    local boxStroke = Instance.new("UIStroke")
    boxStroke.Color = Color3.fromRGB(65, 60, 80)
    boxStroke.Thickness = 1
    boxStroke.Transparency = 0.4
    boxStroke.Parent = searchBox

    local searchIcon = Instance.new("ImageLabel")
    searchIcon.Name = "SearchIcon"
    searchIcon.BackgroundTransparency = 1
    searchIcon.Size = UDim2.fromOffset(16, 16)
    searchIcon.Position = UDim2.new(0, 8, 0.5, 0)
    searchIcon.AnchorPoint = Vector2.new(0, 0.5)
    searchIcon.Image = "rbxasset://textures/ui/SearchIcon.png"
    searchIcon.ImageColor3 = Color3.fromRGB(160, 155, 175)
    searchIcon.ZIndex = 6
    searchIcon.Parent = searchBox

    local input = Instance.new("TextBox")
    input.Name = "SearchInput"
    input.BackgroundTransparency = 1
    input.Size = UDim2.new(1, -56, 1, 0)
    input.Position = UDim2.new(0, 30, 0, 0)
    input.PlaceholderText = "Search settings..."
    input.PlaceholderColor3 = Color3.fromRGB(140, 135, 155)
    input.Text = ""
    input.TextColor3 = Color3.fromRGB(240, 240, 255)
    input.TextSize = 13
    input.Font = Enum.Font.Gotham
    input.TextXAlignment = Enum.TextXAlignment.Left
    input.ClearTextOnFocus = false
    input.ZIndex = 6
    input.Parent = searchBox
    searchInputBox = input

    local clearBtn = Instance.new("TextButton")
    clearBtn.Name = "ClearBtn"
    clearBtn.BackgroundTransparency = 1
    clearBtn.Size = UDim2.fromOffset(20, 20)
    clearBtn.Position = UDim2.new(1, -6, 0.5, 0)
    clearBtn.AnchorPoint = Vector2.new(1, 0.5)
    clearBtn.Text = "x"
    clearBtn.TextColor3 = Color3.fromRGB(150, 145, 165)
    clearBtn.Font = Enum.Font.GothamBold
    clearBtn.TextSize = 13
    clearBtn.Visible = false
    clearBtn.ZIndex = 6
    clearBtn.Parent = searchBox

    -- Search Dropdown (floats below search box)
    local dropdown = Instance.new("Frame")
    dropdown.Name = "LY_SearchDropdown"
    dropdown.Size = UDim2.new(0, 260, 0, 0)
    dropdown.AutomaticSize = Enum.AutomaticSize.Y
    dropdown.Position = UDim2.new(0, 130, 0, 52)
    dropdown.BackgroundColor3 = Color3.fromRGB(24, 22, 30)
    dropdown.BorderSizePixel = 0
    dropdown.ZIndex = 60
    dropdown.Visible = false
    dropdown.Parent = Window.Instance
    searchDropdown = dropdown

    local dCorner = Instance.new("UICorner")
    dCorner.CornerRadius = UDim.new(0, 10)
    dCorner.Parent = dropdown

    local dStroke = Instance.new("UIStroke")
    dStroke.Color = Color3.fromRGB(70, 65, 85)
    dStroke.Thickness = 1
    dStroke.Transparency = 0.3
    dStroke.Parent = dropdown

    local dList = Instance.new("UIListLayout")
    dList.SortOrder = Enum.SortOrder.LayoutOrder
    dList.Padding = UDim.new(0, 4)
    dList.Parent = dropdown

    local dPadding = Instance.new("UIPadding")
    dPadding.PaddingTop = UDim.new(0, 6)
    dPadding.PaddingBottom = UDim.new(0, 6)
    dPadding.PaddingLeft = UDim.new(0, 6)
    dPadding.PaddingRight = UDim.new(0, 6)
    dPadding.Parent = dropdown

    clearBtn.Activated:Connect(function()
        input.Text = ""
        clearBtn.Visible = false
        dropdown.Visible = false
    end)

    -- ==================== Window Smooth Lerp Dragging System ====================
    -- Disables instant-snap dragging and replaces it with smooth damped follow
    pcall(function()
        for _, c in ipairs(getconnections(topBar.InputBegan)) do
            c:Disable()
        end
    end)

    local winDragging = false
    local winDragStartMouse = nil
    local winDragStartOffset = nil
    local winTargetOffset = Vector2.new(Window.Instance.Position.X.Offset, Window.Instance.Position.Y.Offset)

    local function getWinScreenClamp(ox, oy)
        local cam = workspace.CurrentCamera
        local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
        local halfW = (Window.Instance.AbsoluteSize.X) / 2
        local halfH = (Window.Instance.AbsoluteSize.Y) / 2
        local minX = -vp.X * 0.5 + halfW + 10
        local maxX = vp.X * 0.5 - halfW - 10
        local minY = -vp.Y * 0.5 + halfH + 10
        local maxY = vp.Y * 0.5 - halfH - 10
        return math.clamp(ox, minX, maxX), math.clamp(oy, minY, maxY)
    end

    local winDragBeganConn = topBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            winDragging = true
            winDragStartMouse = input.Position
            winDragStartOffset = Vector2.new(Window.Instance.Position.X.Offset, Window.Instance.Position.Y.Offset)
            winTargetOffset = winDragStartOffset
        end
    end)

    local winDragEndConn = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            winDragging = false
        end
    end)

    local winDragMoveConn = UserInputService.InputChanged:Connect(function(input)
        if winDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            if input.UserInputType == Enum.UserInputType.MouseMovement and not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
                winDragging = false
                return
            end
            local delta = input.Position - winDragStartMouse
            local rawX = winDragStartOffset.X + delta.X
            local rawY = winDragStartOffset.Y + delta.Y
            local cx, cy = getWinScreenClamp(rawX, rawY)
            winTargetOffset = Vector2.new(cx, cy)
        end
    end)

    local winLerpConn = RunService.RenderStepped:Connect(function(dt)
        local curX = Window.Instance.Position.X.Offset
        local curY = Window.Instance.Position.Y.Offset
        local dist = math.sqrt((curX - winTargetOffset.X)^2 + (curY - winTargetOffset.Y)^2)
        if dist > 0.4 then
            local factor = 1 - math.exp(-10 * dt)
            local newX = curX + (winTargetOffset.X - curX) * factor
            local newY = curY + (winTargetOffset.Y - curY) * factor
            Window.Instance.Position = UDim2.new(0.5, math.round(newX), 0.5, math.round(newY))
        end
    end)

    Window.OnUnload:Connect(function()
        pcall(function() winDragBeganConn:Disconnect() end)
        pcall(function() winDragEndConn:Disconnect() end)
        pcall(function() winDragMoveConn:Disconnect() end)
        pcall(function() winLerpConn:Disconnect() end)
    end)
end

-- ==================== 2. Background Dimming & Snowfall Effect ====================
local gui = Window.Gui

local backdropSettings = {
    Enabled = true,
    Transparency = 0.55,
}

local snowSettings = {
    Enabled = true,
    SpeedMultiplier = 1.0,
    BaseSize = 5,
    Count = 45,
}

local backdrop = Instance.new("Frame")
backdrop.Name = "LY_DarkBackdrop"
backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
backdrop.BackgroundTransparency = 0.55
backdrop.BorderSizePixel = 0
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.Position = UDim2.fromScale(0, 0)
backdrop.ZIndex = 0
backdrop.Visible = Window.Visible and not Window.Minimized
backdrop.Parent = gui

local snowContainer = Instance.new("Frame")
snowContainer.Name = "LY_SnowContainer"
snowContainer.BackgroundTransparency = 1
snowContainer.BorderSizePixel = 0
snowContainer.Size = UDim2.fromScale(1, 1)
snowContainer.Position = UDim2.fromScale(0, 0)
snowContainer.ClipsDescendants = true
snowContainer.ZIndex = 0
snowContainer.Visible = Window.Visible and not Window.Minimized
snowContainer.Parent = gui

local function getScreenBounds()
    local vp = camera and camera.ViewportSize or Vector2.new(1920, 1080)
    return math.max(vp.X, 800), math.max(vp.Y, 600)
end

local screenW, screenH = getScreenBounds()
local snowflakes = {}

local function createFlake(i)
    local flake = Instance.new("Frame")
    flake.Name = "Flake_" .. tostring(i)
    flake.BorderSizePixel = 0
    flake.BackgroundColor3 = Color3.fromRGB(240, 245, 255)
    
    local sizeRatio = math.random(70, 140) / 100
    local curSize = math.clamp(math.round(snowSettings.BaseSize * sizeRatio), 2, 30)
    flake.Size = UDim2.fromOffset(curSize, curSize)
    flake.BackgroundTransparency = math.random(25, 70) / 100
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = flake
    
    local posX = math.random(0, screenW)
    local posY = math.random(0, screenH)
    flake.Position = UDim2.fromOffset(posX, posY)
    flake.Parent = snowContainer
    
    return {
        inst = flake,
        x = posX,
        y = posY,
        sizeRatio = sizeRatio,
        baseSpeed = math.random(40, 100),
        swayAmp = math.random(15, 35),
        swayFreq = math.random(8, 20) / 10,
        phase = math.random() * math.pi * 2,
    }
end

local function updateSnowCount(targetCount)
    snowSettings.Count = targetCount
    while #snowflakes < targetCount do
        local f = createFlake(#snowflakes + 1)
        table.insert(snowflakes, f)
    end
    while #snowflakes > targetCount do
        local f = table.remove(snowflakes)
        if f and f.inst then
            f.inst:Destroy()
        end
    end
end

local function updateSnowSize(newBaseSize)
    snowSettings.BaseSize = newBaseSize
    for _, f in ipairs(snowflakes) do
        local curSize = math.clamp(math.round(newBaseSize * (f.sizeRatio or 1)), 2, 30)
        f.inst.Size = UDim2.fromOffset(curSize, curSize)
    end
end

for i = 1, snowSettings.Count do
    table.insert(snowflakes, createFlake(i))
end

local elapsed = 0
local snowConn = RunService.RenderStepped:Connect(function(dt)
    if not (Window.Visible and not Window.Minimized and snowSettings.Enabled) then return end
    elapsed += dt
    local sw, sh = getScreenBounds()
    
    for _, f in ipairs(snowflakes) do
        f.y += f.baseSpeed * snowSettings.SpeedMultiplier * dt
        if f.y > sh + 10 then
            f.y = -10
            f.x = math.random(0, sw)
        end
        local currentX = (f.x + math.sin(elapsed * f.swayFreq + f.phase) * f.swayAmp) % sw
        f.inst.Position = UDim2.fromOffset(currentX, f.y)
    end
end)

local updateCursorState

local function updateOverlayVisibility()
    local isOpen = Window.Visible and not Window.Minimized
    if isOpen then
        if backdropSettings.Enabled then
            backdrop.Visible = true
            TweenService:Create(backdrop, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                BackgroundTransparency = backdropSettings.Transparency
            }):Play()
        else
            backdrop.Visible = false
        end

        if snowSettings.Enabled then
            snowContainer.Visible = true
        else
            snowContainer.Visible = false
        end
    else
        local tw = TweenService:Create(backdrop, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            BackgroundTransparency = 1
        })
        tw:Play()
        tw.Completed:Connect(function()
            if not (Window.Visible and not Window.Minimized) then
                backdrop.Visible = false
                snowContainer.Visible = false
            end
        end)
    end
    if updateCursorState then
        updateCursorState()
    end
end

-- ==================== Custom Mouse Cursor System ====================
local cursorSettings = {
    Enabled = true,
    Scale = 100,
}

local CoreGui = game:GetService("CoreGui")
local cursorGuiParent = (pcall(function() return CoreGui.Name end) and CoreGui) or (player and player:FindFirstChildOfClass("PlayerGui")) or Window.Gui

local cursorGui = Instance.new("ScreenGui")
cursorGui.Name = "LY_CustomCursorGui"
cursorGui.ResetOnSpawn = false
cursorGui.DisplayOrder = 999999
cursorGui.IgnoreGuiInset = true
cursorGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
cursorGui.Parent = cursorGuiParent

local cursorContainer = Instance.new("Frame")
cursorContainer.Name = "CursorContainer"
cursorContainer.BackgroundTransparency = 1
cursorContainer.BorderSizePixel = 0
cursorContainer.Size = UDim2.fromOffset(0, 0)
cursorContainer.AnchorPoint = Vector2.new(0, 0)
cursorContainer.Visible = false
cursorContainer.Parent = cursorGui

local cursorScale = Instance.new("UIScale")
cursorScale.Name = "CursorScale"
cursorScale.Scale = cursorSettings.Scale / 100
cursorScale.Parent = cursorContainer

local cursorPointer = Instance.new("ImageLabel")
cursorPointer.Name = "CursorPointer"
cursorPointer.BackgroundTransparency = 1
cursorPointer.BorderSizePixel = 0
cursorPointer.Size = UDim2.fromOffset(64, 64)
cursorPointer.Position = UDim2.fromOffset(-31, -32)
cursorPointer.Image = "rbxasset://textures/Cursors/KeyboardMouse/ArrowFarCursor.png"
cursorPointer.ImageColor3 = Window.Theme.Colors.Primary or Color3.fromRGB(220, 205, 255)
cursorPointer.ZIndex = 1000000
cursorPointer.Parent = cursorContainer

if Window._themer and Window._themer.Bind then
    pcall(function()
        Window._themer:Bind(cursorPointer, { ImageColor3 = "Primary" })
    end)
end

updateCursorState = function()
    local isUIOpen = Window.Visible and not Window.Minimized
    if isUIOpen and cursorSettings.Enabled then
        UserInputService.MouseIconEnabled = false
        cursorContainer.Visible = true
    else
        cursorContainer.Visible = false
        UserInputService.MouseIconEnabled = true
    end
end

local cursorRenderConn = RunService.RenderStepped:Connect(function()
    if cursorContainer.Visible then
        local mousePos = UserInputService:GetMouseLocation()
        cursorContainer.Position = UDim2.fromOffset(mousePos.X, mousePos.Y)
    end
end)

local function onVisibilityChanged()
    updateOverlayVisibility()
    if updateCursorState then
        updateCursorState()
    end
end

local visConn = Window.Instance:GetPropertyChangedSignal("Visible"):Connect(onVisibilityChanged)
local toggleKeyConn = UserInputService.InputBegan:Connect(function(input, gpe)
    if input.KeyCode == Enum.KeyCode.RightShift then
        task.defer(onVisibilityChanged)
    end
end)

Window.OnUnload:Connect(function()
    pcall(function() cursorRenderConn:Disconnect() end)
    pcall(function() visConn:Disconnect() end)
    pcall(function() toggleKeyConn:Disconnect() end)
    pcall(function() cursorGui:Destroy() end)
    UserInputService.MouseIconEnabled = true
    pcall(function() snowConn:Disconnect() end)
    pcall(function() backdrop:Destroy() end)
    pcall(function() snowContainer:Destroy() end)
end)

updateCursorState()

-- ==================== 3. Window Transparency & UIScale System ====================
local defaultTransparency = 0.15
Window.Instance.BackgroundTransparency = defaultTransparency
if Window._pages then
    Window._pages.BackgroundTransparency = 0.25
end

local uiScale = Window.Instance:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
uiScale.Name = "LY_WindowScale"
uiScale.Scale = 1.0
uiScale.Parent = Window.Instance

-- ==================== 4. Top Navigation Bar Enhancement (Smooth Sliding Category Indicator) ====================
local navList = Window._navList
local pages = Window._pages
local body = Window.Instance:FindFirstChild("Body") or Window.Instance

local navPill = nil
local currentActiveBtn = nil
local pillTween = nil

local function getBtnRelPos(btn)
    local relX = btn.AbsolutePosition.X - body.AbsolutePosition.X
    local relY = btn.AbsolutePosition.Y - body.AbsolutePosition.Y
    return UDim2.fromOffset(relX, relY), UDim2.fromOffset(btn.AbsoluteSize.X, btn.AbsoluteSize.Y)
end

local function slideToButton(btn, instant)
    if not (btn and btn:IsDescendantOf(game) and navPill) then return end
    currentActiveBtn = btn

    local targetPos, targetSize = getBtnRelPos(btn)
    if pillTween then
        pillTween:Cancel()
        pillTween = nil
    end

    if instant then
        navPill.Position = targetPos
        navPill.Size = targetSize
        navPill.Visible = true
    else
        navPill.Visible = true
        pillTween = TweenService:Create(navPill, TweenInfo.new(0.32, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Position = targetPos,
            Size = targetSize,
        })
        pillTween:Play()
    end
end

if navList and pages then
    navList.Position = UDim2.new(0, 16, 0, 4)
    navList.Size = UDim2.new(1, -32, 0, 42)
    navList.ScrollingDirection = Enum.ScrollingDirection.X
    navList.AutomaticCanvasSize = Enum.AutomaticSize.X
    navList.ScrollBarThickness = 0
    navList.ZIndex = 3

    local listLayout = navList:FindFirstChildOfClass("UIListLayout")
    if listLayout then
        listLayout.FillDirection = Enum.FillDirection.Horizontal
        listLayout.Padding = UDim.new(0, 8)
        listLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    end

    local padding = navList:FindFirstChildOfClass("UIPadding")
    if padding then
        padding.PaddingLeft = UDim.new(0, 0)
        padding.PaddingRight = UDim.new(0, 0)
        padding.PaddingTop = UDim.new(0, 0)
        padding.PaddingBottom = UDim.new(0, 0)
    end

    pages.Position = UDim2.new(0, 16, 0, 50)
    pages.Size = UDim2.new(1, -32, 1, -60)

    -- Create floating sliding indicator pill inside Body (behind navList buttons)
    navPill = Instance.new("Frame")
    navPill.Name = "LY_NavSlideIndicator"
    navPill.BackgroundColor3 = Window.Theme.Colors.SecondaryContainer or Color3.fromRGB(74, 68, 88)
    navPill.BorderSizePixel = 0
    navPill.ZIndex = 1
    navPill.Active = false
    navPill.Visible = false
    navPill.Parent = body

    local pillCorner = Instance.new("UICorner")
    pillCorner.CornerRadius = UDim.new(0, 18)
    pillCorner.Parent = navPill

    local pillStroke = Instance.new("UIStroke")
    pillStroke.Thickness = 1.2
    pillStroke.Color = Window.Theme.Colors.Primary or Color3.fromRGB(208, 188, 255)
    pillStroke.Transparency = 0.5
    pillStroke.Parent = navPill

    if Window._themer and Window._themer.Bind then
        pcall(function()
            Window._themer:Bind(navPill, { BackgroundColor3 = "SecondaryContainer" })
            Window._themer:Bind(pillStroke, { Color = "Primary" })
        end)
    end

    local function styleTabButton(tab)
        if not (tab and tab._button) then return end
        local title = tab.Title or ""
        local hasIcon = tab._icon and tab._icon.Visible ~= false
        local textLen = 0
        for _ in utf8.graphemes(title) do textLen += 1 end
        local btnWidth = math.clamp((hasIcon and 38 or 20) + (textLen * 10) + 18, 80, 140)

        local btn = tab._button
        btn.Size = UDim2.new(0, btnWidth, 0, 36)
        btn.ZIndex = 4
        btn.BackgroundTransparency = 1

        if tab._icon then
            tab._icon.Position = UDim2.new(0, 10, 0.5, 0)
            tab._icon.ZIndex = 5
        end
        if tab._label then
            tab._label.Position = UDim2.new(0, hasIcon and 34 or 10, 0, 0)
            tab._label.Size = UDim2.new(1, hasIcon and -40 or -20, 1, 0)
            tab._label.ZIndex = 5
        end
        local stateLayer = btn:FindFirstChild("StateLayer")
        if stateLayer then stateLayer.ZIndex = 5 end

        btn:GetPropertyChangedSignal("BackgroundTransparency"):Connect(function()
            if btn.BackgroundTransparency ~= 1 then
                btn.BackgroundTransparency = 1
                slideToButton(btn, false)
            end
        end)

        btn.Activated:Connect(function()
            slideToButton(btn, false)
        end)
    end

    local origAddTab = Window.AddTab
    Window.AddTab = function(self, props)
        local tab = origAddTab(self, props)
        styleTabButton(tab)
        return tab
    end

    local origSelectTab = Window.SelectTab
    Window.SelectTab = function(self, tab)
        local res = origSelectTab(self, tab)
        if tab and tab._button then
            slideToButton(tab._button, false)
        end
        return res
    end

    navList:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
        if currentActiveBtn and currentActiveBtn:IsDescendantOf(game) then
            local targetPos, targetSize = getBtnRelPos(currentActiveBtn)
            navPill.Position = targetPos
            navPill.Size = targetSize
        end
    end)

    body:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        if currentActiveBtn and currentActiveBtn:IsDescendantOf(game) then
            local targetPos, targetSize = getBtnRelPos(currentActiveBtn)
            navPill.Position = targetPos
            navPill.Size = targetSize
        end
    end)

    task.defer(function()
        task.wait(0.1)
        local firstTab = Window.Tabs and Window.Tabs[1]
        if firstTab and firstTab._button then
            slideToButton(firstTab._button, true)
        end
    end)
end

-- ==================== 5. Sub-Categories Builder (Dual Columns & Divider) ====================
local function createSubTabs(tab, names)
    local page = tab.Instance
    local theme = Window.Theme

    local subNav = Instance.new("Frame")
    subNav.Name = "SubNavBar"
    subNav.BackgroundTransparency = 1
    subNav.Size = UDim2.new(1, 0, 0, 42)
    subNav.LayoutOrder = 0
    subNav.Parent = page

    local listLayout = Instance.new("UIListLayout")
    listLayout.FillDirection = Enum.FillDirection.Horizontal
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 8)
    listLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    listLayout.Parent = subNav

    local subHolders = {}
    local subButtons = {}

    local function selectSub(idx)
        for i, holder in ipairs(subHolders) do
            holder.Visible = (i == idx)
        end
        for i, btn in ipairs(subButtons) do
            local isSel = (i == idx)
            local stroke = btn:FindFirstChildOfClass("UIStroke")
            if isSel then
                btn.BackgroundColor3 = theme.Colors.SecondaryContainer or Color3.fromRGB(74, 68, 88)
                btn.TextColor3 = theme.Colors.OnSecondaryContainer or Color3.fromRGB(232, 222, 248)
                if stroke then
                    stroke.Transparency = 0.2
                    stroke.Color = theme.Colors.Primary or Color3.fromRGB(208, 188, 255)
                    stroke.Thickness = 1.5
                end
            else
                btn.BackgroundColor3 = theme.Colors.SurfaceContainerHigh or Color3.fromRGB(36, 33, 43)
                btn.TextColor3 = theme.Colors.OnSurfaceVariant or Color3.fromRGB(202, 196, 208)
                if stroke then
                    stroke.Transparency = 0.6
                    stroke.Color = theme.Colors.OutlineVariant or Color3.fromRGB(73, 69, 79)
                    stroke.Thickness = 1
                end
            end
        end
    end

    local subTabApi = {}

    for i, name in ipairs(names) do
        local holder = Instance.new("Frame")
        holder.Name = "SubCategory_" .. name
        holder.BackgroundTransparency = 1
        holder.Size = UDim2.new(1, 0, 1, -54)
        holder.AutomaticSize = Enum.AutomaticSize.Y
        holder.LayoutOrder = i
        holder.Visible = (i == 1)
        holder.Parent = page

        -- Dual columns and center divider line
        local leftCol = Instance.new("Frame")
        leftCol.Name = "LeftCol"
        leftCol.BackgroundTransparency = 1
        leftCol.Size = UDim2.new(0.5, -8, 0, 0)
        leftCol.Position = UDim2.new(0, 0, 0, 0)
        leftCol.AutomaticSize = Enum.AutomaticSize.Y
        leftCol.Parent = holder

        local leftLayout = Instance.new("UIListLayout")
        leftLayout.FillDirection = Enum.FillDirection.Vertical
        leftLayout.SortOrder = Enum.SortOrder.LayoutOrder
        leftLayout.Padding = UDim.new(0, 8)
        leftLayout.Parent = leftCol

        local divider = Instance.new("Frame")
        divider.Name = "DividerLine"
        divider.Size = UDim2.new(0, 1, 1, 0)
        divider.Position = UDim2.new(0.5, 0, 0, 0)
        divider.BackgroundColor3 = theme.Colors.OutlineVariant or Color3.fromRGB(150, 140, 170)
        divider.BackgroundTransparency = 0.4
        divider.BorderSizePixel = 0
        divider.ZIndex = 2
        divider.Parent = holder
        if Window._themer and Window._themer.Bind then
            pcall(function() Window._themer:Bind(divider, { BackgroundColor3 = "OutlineVariant" }) end)
        end

        local rightCol = Instance.new("Frame")
        rightCol.Name = "RightCol"
        rightCol.BackgroundTransparency = 1
        rightCol.Size = UDim2.new(0.5, -8, 0, 0)
        rightCol.Position = UDim2.new(0.5, 8, 0, 0)
        rightCol.AutomaticSize = Enum.AutomaticSize.Y
        rightCol.Parent = holder

        local rightLayout = Instance.new("UIListLayout")
        rightLayout.FillDirection = Enum.FillDirection.Vertical
        rightLayout.SortOrder = Enum.SortOrder.LayoutOrder
        rightLayout.Padding = UDim.new(0, 8)
        rightLayout.Parent = rightCol

        table.insert(subHolders, holder)

        local btn = Instance.new("TextButton")
        btn.Name = "SubBtn_" .. name
        btn.AutoButtonColor = false
        btn.Text = name
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 14
        local charCount = 0
        for _ in utf8.graphemes(name) do charCount += 1 end
        btn.Size = UDim2.new(0, math.clamp(charCount * 9 + 32, 84, 160), 0, 34)
        btn.LayoutOrder = i
        btn.Parent = subNav

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 17)
        corner.Parent = btn

        local stroke = Instance.new("UIStroke")
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Thickness = 1
        stroke.Parent = btn

        btn.Activated:Connect(function()
            selectSub(i)
        end)

        table.insert(subButtons, btn)

        subTabApi[name] = {
            Holder = holder,
            Left = leftCol,
            Right = rightCol,
            Divider = divider,
            AddLeftSection = function(_, title)
                local origHolder = tab._holder
                tab._holder = leftCol
                local section = tab:AddSection(title)
                tab._holder = origHolder
                return section
            end,
            AddRightSection = function(_, title)
                local origHolder = tab._holder
                tab._holder = rightCol
                local section = tab:AddSection(title)
                tab._holder = origHolder
                return section
            end,
            AddSection = function(self, title, side)
                if side == "Right" or side == "right" then
                    return self:AddRightSection(title)
                else
                    return self:AddLeftSection(title)
                end
            end,
        }
    end

    selectSub(1)
    return subTabApi
end

-- ==================== 6. Main and Feature Categories (Full English & Dual Columns) ====================
-- Main
local MainTab = Window:AddTab({ Title = "Main", Icon = "home" })
local MainSubs = createSubTabs(MainTab, { "Overview", "Statistics", "Info" })

-- Main -> Overview
local Main_1_L = MainSubs["Overview"]:AddLeftSection("General")
Main_1_L:AddParagraph({ Title = "Welcome to LY Hub", Content = "Modern Material Design 3 interface with background dimming, snowfall effect, and dual-column layouts." })
local Main_1_R = MainSubs["Overview"]:AddRightSection("System Info")
Main_1_R:AddParagraph({ Title = "Core Status", Content = "Threads running normally. Dual-column structure initialized." })

-- Main -> Statistics
local Main_2_L = MainSubs["Statistics"]:AddLeftSection("Session Stats")
local Main_2_R = MainSubs["Statistics"]:AddRightSection("Performance Monitor")

-- Main -> Info
local Main_3_L = MainSubs["Info"]:AddLeftSection("System Diagnostics")
local Main_3_R = MainSubs["Info"]:AddRightSection("Build Information")

-- Combat - Layout skeleton only
local CombatTab = Window:AddTab({ Title = "Combat", Icon = "shield" })
local CombatSubs = createSubTabs(CombatTab, { "Aimbot", "Silent Bot", "Trigger Bot" })
local Combat_1_L = CombatSubs["Aimbot"]:AddLeftSection("Targeting")
local Combat_1_R = CombatSubs["Aimbot"]:AddRightSection("Target Filtering")
local Combat_2_L = CombatSubs["Silent Bot"]:AddLeftSection("Trigger Conditions")
local Combat_2_R = CombatSubs["Silent Bot"]:AddRightSection("Hitbox Configuration")
local Combat_3_L = CombatSubs["Trigger Bot"]:AddLeftSection("Activation Mode")
local Combat_3_R = CombatSubs["Trigger Bot"]:AddRightSection("Delay & Safety")

-- Visuals tab
local VisualsTab = Window:AddTab({ Title = "Visuals", Icon = "visibility" })
local VisualsSubs = createSubTabs(VisualsTab, { "ESP", "Chams", "World" })
local Visuals_1_L = VisualsSubs["ESP"]:AddLeftSection("Player ESP")
local Visuals_1_R = VisualsSubs["ESP"]:AddRightSection("Distance & Tracers")
local Visuals_2_L = VisualsSubs["Chams"]:AddLeftSection("Chams")
local Visuals_2_R = VisualsSubs["Chams"]:AddRightSection("Skeleton")
local Visuals_3_L = VisualsSubs["World"]:AddLeftSection("Render Effects")
local Visuals_3_R = VisualsSubs["World"]:AddRightSection("Post Processing")

-- ==================== ESP ENGINE (from ESP.lua) ====================
do
    local _Players    = game:GetService("Players")
    local _RunService = game:GetService("RunService")
    local _Workspace  = game:GetService("Workspace")
    local _RS         = game:GetService("ReplicatedStorage")
    local _LocalPlayer = _Players.LocalPlayer

    ---------- ESP Config ----------
    _G.ESPConfig = _G.ESPConfig or {}
    local Box = _G.ESPConfig.Box or {
        MasterEnabled = false,
        Enable        = false,
        Mode          = "2D",  -- "2D" | "3D"
        OutlineColor  = Color3.fromRGB(255,255,255),
        Thickness     = 1,
        Healthbar     = { Enable = false, Thickness = 4 },
        -- Custom gradient: up to 5 stops [ {pct=1.0, color=...}, ... ] sorted desc pct
        HealthGradientStops = {
            { pct = 1.00, color = Color3.fromRGB(0, 255, 0)   },  -- high HP green
            { pct = 0.50, color = Color3.fromRGB(255, 255, 0) },  -- mid HP yellow
            { pct = 0.00, color = Color3.fromRGB(255, 0, 0)   },  -- low HP red
        },
        HealthLerpColors = {  -- kept for backward compat
            Color1 = Color3.fromRGB(0,255,0),
            Color2 = Color3.fromRGB(255,255,0),
            Color3 = Color3.fromRGB(255,0,0),
        },
    }
    _G.ESPConfig.Box = Box

    local Filled = _G.ESPConfig.Filled or {
        Enable        = false,
        ColorStart    = Color3.fromRGB(255, 255, 255),  -- gradient top color
        ColorEnd      = Color3.fromRGB(255, 255, 255),  -- gradient bottom color
        GradientStops = {  -- custom up to 5 stops
            { pct = 1.0, color = Color3.fromRGB(255,255,255) },
            { pct = 0.0, color = Color3.fromRGB(255,255,255) },
        },
        Transparency  = 0.7,
        UseGradient   = false,  -- if true, render per-row gradient blend
    }
    _G.ESPConfig.Filled = Filled

    local Glow = _G.ESPConfig.Glow or {
        Enable       = false,
        ColorStart   = Color3.fromRGB(255,255,255),
        ColorEnd     = Color3.fromRGB(255,255,255),
        Transparency = 0.80,
    }
    _G.ESPConfig.Glow = Glow

    local TextESP = _G.ESPConfig.TextESP or {
        Names         = false,
        NameMode      = "DisplayName",  -- "DisplayName" | "@Username"
        NameColor     = Color3.fromRGB(255,255,255),
        NameColor2    = Color3.fromRGB(255,255,255),
        NameSize      = 13,
        Distance      = false,
        DistanceColor = Color3.fromRGB(255,255,255),
        DistanceColor2= Color3.fromRGB(255,255,255),
        DistanceSize  = 13,
        Tools         = false,
        ToolColor     = Color3.fromRGB(255,255,255),
        ToolColor2    = Color3.fromRGB(255,255,255),
        ToolsSize     = 13,
    }
    _G.ESPConfig.TextESP = TextESP

    local SkeletonCfg = _G.ESPConfig.Skeleton or {
        Enable    = false,
        Color     = Color3.fromRGB(255,255,255),
        Color2    = Color3.fromRGB(255,255,255),
        Thickness = 1,
    }
    _G.ESPConfig.Skeleton = SkeletonCfg

    local TracersCfg = _G.ESPConfig.Tracers or {
        Enable    = false,
        Color     = Color3.fromRGB(255,255,255),
        Color2    = Color3.fromRGB(255,255,255),
        Thickness = 1,
    }
    _G.ESPConfig.Tracers = TracersCfg

    local ChamsCfg = _G.ESPConfig.Chams or {
        Enable       = false,
        Color        = Color3.fromRGB(255,255,255),
        Color2       = Color3.fromRGB(255,255,255),
        Transparency = 0,
    }
    _G.ESPConfig.Chams = ChamsCfg

    -- Helper: interpolate color through custom gradient stops
    local function lerpGradient(stops, pct)
        if not stops or #stops == 0 then return Color3.new(1,1,1) end
        if pct >= stops[1].pct then return stops[1].color end
        if pct <= stops[#stops].pct then return stops[#stops].color end
        for i = 1, #stops - 1 do
            local a, b = stops[i], stops[i+1]
            if pct <= a.pct and pct >= b.pct then
                local t = (a.pct - pct) / (a.pct - b.pct)
                return a.color:Lerp(b.color, t)
            end
        end
        return stops[#stops].color
    end


    ---------- Utility ESP Config ----------
    local UtilConfig = {
        enable   = false,
        color    = Color3.fromRGB(255,255,255),
        color2   = Color3.fromRGB(255,255,255),
        selected = {},
        distance = false,
        images   = false,
    }

    ---------- Utility ESP Internals ----------
    local UTIL_IMG_SIZE = 36
    local UTIL_NAME_GAP = 14
    local UTIL_DIST_GAP = 6

    local ItemLibrary
    pcall(function()
        ItemLibrary = require(_RS.Modules.ItemLibrary)
    end)

    local utilImageName = {
        Grenade               = "Grenade",
        SubspaceTripmineHitbox= "Subspace Tripmine",
        Flashbang             = "Flashbang",
        Satchel               = "Satchel",
        Warpstone             = "Warpstone",
        Molotov               = "Molotov",
        ["Smoke Grenade"]     = "Smoke Grenade",
    }

    local utilImageFallback = {
        Grenade               = "rbxassetid://6603835352",
        Flashbang             = "rbxassetid://243660364",
        Satchel               = "rbxassetid://446111271",
        Warpstone             = "rbxassetid://12781852245",
        Molotov               = "rbxassetid://1084982556",
        ["Smoke Grenade"]     = "rbxassetid://241650108",
        ["Subspace Tripmine"] = "rbxassetid://120777973",
    }

    local utilImageCache = {}

    local function normUtilImageId(id)
        if not id or id == "" then return "" end
        id = tostring(id)
        if tonumber(id) then return "rbxassetid://" .. id end
        return id
    end

    local function resolveUtilImage(modelName)
        if utilImageCache[modelName] ~= nil then return utilImageCache[modelName] end
        local imageId = ""
        local libNames = {}
        local mapped = utilImageName[modelName]
        if mapped then libNames[#libNames+1] = mapped end
        if modelName == "SubspaceTripmineHitbox" then
            libNames[#libNames+1] = "Subspace Tripmine"
        end
        libNames[#libNames+1] = modelName
        pcall(function()
            for _, libName in ipairs(libNames) do
                if imageId ~= "" then break end
                if ItemLibrary and ItemLibrary.GetWeaponImage then
                    imageId = ItemLibrary:GetWeaponImage(libName, true) or ""
                end
                if imageId == "" and ItemLibrary and ItemLibrary.GetImageFromWeaponData then
                    imageId = ItemLibrary:GetImageFromWeaponData({ Name=libName, Weapon=libName, WeaponName=libName }, true) or ""
                end
            end
        end)
        imageId = normUtilImageId(imageId)
        if imageId == "" then
            imageId = utilImageFallback[modelName] or utilImageFallback[utilImageName[modelName]] or ""
        end
        utilImageCache[modelName] = imageId
        return imageId
    end

    local utilMap = {
        ["grenade"]           = "Grenade",
        ["subspace tripmine"] = "SubspaceTripmineHitbox",
        ["flashbang"]         = "Flashbang",
        ["satchel"]           = "Satchel",
        ["warpstone"]         = "Warpstone",
        ["molotov"]           = "Molotov",
        ["smoke grenade"]     = "Smoke Grenade",
    }

    local utilDisplay = {}
    for label, realname in pairs(utilMap) do
        utilDisplay[realname] = label
    end

    local function utilHasSelection()
        for label in pairs(utilMap) do
            if UtilConfig.selected[label] then return true end
        end
        return false
    end

    local function isSelected(realname)
        if not utilHasSelection() then
            for _, rname in pairs(utilMap) do
                if rname == realname then return true end
            end
            return false
        end
        for label, rname in pairs(utilMap) do
            if rname == realname and UtilConfig.selected[label] then return true end
        end
        return false
    end

    ---------- Utility ESP Drawing ----------
    local utilEspObjects = {}
    local espGui
    pcall(function()
        espGui = Instance.new("ScreenGui")
        espGui.Name = "LY_UtilityESPGui"
        espGui.ResetOnSpawn = false
        pcall(function() espGui.Parent = game:GetService("CoreGui") end)
        if not espGui.Parent then espGui.Parent = _LocalPlayer:WaitForChild("PlayerGui") end
    end)

    local function makeDrawText(text, color)
        if not Drawing or not Drawing.new then return nil end
        local ok, t = pcall(function() return Drawing.new("Text") end)
        if not ok or not t then return nil end
        t.Text = text
        t.Color = color
        t.Size = 15
        t.Visible = false
        t.Outline = true
        t.OutlineColor = Color3.new(0,0,0)
        t.Center = true
        t.Font = 2
        return t
    end

    local function makeDrawImage(imageId)
        local img = Instance.new("ImageLabel")
        img.BackgroundTransparency = 1
        img.BorderSizePixel = 0
        img.Image = imageId or ""
        img.ImageTransparency = 0
        img.Size = UDim2.fromOffset(UTIL_IMG_SIZE, UTIL_IMG_SIZE)
        img.Visible = false
        img.ZIndex = 10
        if espGui then img.Parent = espGui end
        return img
    end

    local function getUtilTrackTarget(obj)
        if not obj then return nil, nil end
        if obj:IsA("Model") then
            local root = obj.PrimaryPart or obj:FindFirstChild("Hitbox") or obj:FindFirstChildWhichIsA("BasePart")
            return obj, root
        end
        if obj:IsA("BasePart") then
            local model = obj.Parent and obj.Parent:IsA("Model") and obj.Parent or nil
            return model or obj, obj
        end
        return nil, nil
    end

    local function utilMatchesFilter(obj)
        local model, root = getUtilTrackTarget(obj)
        if not model or not root then return false end
        local realname = model:IsA("Model") and model.Name or obj.Name
        return isSelected(realname)
    end

    local function removeEspObjsFor(model)
        if utilEspObjects[model] then
            for _, d in ipairs(utilEspObjects[model].drawings) do
                pcall(function() d:Remove() end)
            end
            if utilEspObjects[model].image then
                pcall(function()
                    if typeof(utilEspObjects[model].image) == "Instance" and utilEspObjects[model].image:IsA("GuiObject") then
                        utilEspObjects[model].image:Destroy()
                    else
                        utilEspObjects[model].image:Remove()
                    end
                end)
            end
            if utilEspObjects[model].conn then
                utilEspObjects[model].conn:Disconnect()
            end
            utilEspObjects[model] = nil
        end
    end

    local function clearUtilEsp()
        for model in pairs(utilEspObjects) do removeEspObjsFor(model) end
    end

    local function addUtilEsp(obj)
        local model, rootpart = getUtilTrackTarget(obj)
        if not model or not rootpart then return end
        if utilEspObjects[model] then return end

        local realname = model:IsA("Model") and model.Name or tostring(model)
        local nametext = utilDisplay[realname] or string.lower(realname)
        local namedraw = makeDrawText(nametext, UtilConfig.color)
        local distdraw = makeDrawText("", UtilConfig.color)
        local imgdraw  = makeDrawImage(resolveUtilImage(realname))
        if not namedraw and not distdraw then return end

        utilEspObjects[model] = {
            drawings = {},
            image    = imgdraw,
            conn     = nil,
            root     = rootpart,
        }
        if namedraw then table.insert(utilEspObjects[model].drawings, namedraw) end
        if distdraw then table.insert(utilEspObjects[model].drawings, distdraw) end

        local conn = _RunService.RenderStepped:Connect(function()
            pcall(function()
                local trackRoot = utilEspObjects[model] and utilEspObjects[model].root
                if not trackRoot or not trackRoot.Parent then
                    removeEspObjsFor(model)
                    return
                end
                local cam = _Workspace.CurrentCamera
                if not cam then return end
                local sp, onScreen = cam:WorldToViewportPoint(trackRoot.Position)
                local pos = Vector2.new(sp.X, sp.Y)

                if onScreen and UtilConfig.enable and isSelected(realname) then
                    local showImg = UtilConfig.images and imgdraw and imgdraw.Image and imgdraw.Image ~= ""
                    local halfImg = UTIL_IMG_SIZE * 0.5
                    if namedraw then
                        namedraw.Position = showImg and Vector2.new(pos.X, pos.Y - halfImg - UTIL_NAME_GAP) or Vector2.new(pos.X, pos.Y - 8)
                        namedraw.Visible = true
                    end
                    if imgdraw then
                        if showImg then
                            imgdraw.Position = UDim2.new(0, pos.X - halfImg, 0, pos.Y - halfImg)
                            imgdraw.Visible = true
                        else
                            imgdraw.Visible = false
                        end
                    end
                    if distdraw then
                        if UtilConfig.distance then
                            local dist = math.floor((cam.CFrame.Position - trackRoot.Position).Magnitude)
                            distdraw.Text = tostring(dist) .. "m"
                            distdraw.Position = showImg and Vector2.new(pos.X, pos.Y + halfImg + UTIL_DIST_GAP) or Vector2.new(pos.X, pos.Y + 6)
                            distdraw.Visible = true
                        else
                            distdraw.Visible = false
                        end
                    end
                else
                    if namedraw then namedraw.Visible = false end
                    if distdraw then distdraw.Visible = false end
                    if imgdraw then imgdraw.Visible = false end
                end
            end)
        end)
        utilEspObjects[model].conn = conn

        model.AncestryChanged:Connect(function(_, parent)
            if not parent then removeEspObjsFor(model) end
        end)
    end

    local function refreshUtilEsp()
        clearUtilEsp()
        if not UtilConfig.enable then return end
        for _, obj in ipairs(_Workspace:GetDescendants()) do
            if (obj:IsA("Model") or obj:IsA("BasePart")) and utilMatchesFilter(obj) then
                addUtilEsp(obj)
            end
        end
    end

    _Workspace.DescendantAdded:Connect(function(desc)
        if not UtilConfig.enable then return end
        if not desc:IsA("Model") and not desc:IsA("BasePart") then return end
        task.delay(0.15, function()
            if not UtilConfig.enable then return end
            if utilMatchesFilter(desc) then addUtilEsp(desc) end
        end)
    end)

    ---------- Player Box / Skeleton / Tracer ESP (Drawing API) ----------
    local playerEspObjects = {} -- [Player] = { box, healthbar, nameText, distText, tracer, skeleton[] }

    local SKELETON_PAIRS = {
        {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},
        {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
        {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
        {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
        {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
    }

    local function newLine(color, thickness)
        if not Drawing or not Drawing.new then return nil end
        local ok, l = pcall(function() return Drawing.new("Line") end)
        if not ok or not l then return nil end
        l.Color = color or Color3.new(1,1,1)
        l.Thickness = thickness or 1
        l.Visible = false
        return l
    end

    local function newQuad(color, thickness)
        if not Drawing or not Drawing.new then return nil end
        local ok, q = pcall(function() return Drawing.new("Quad") end)
        if not ok or not q then return nil end
        q.Color = color or Color3.new(1,1,1)
        q.Thickness = thickness or 1
        q.Filled = false
        q.Visible = false
        return q
    end

    local function newDrawText(color, size)
        if not Drawing or not Drawing.new then return nil end
        local ok, t = pcall(function() return Drawing.new("Text") end)
        if not ok or not t then return nil end
        t.Color = color or Color3.new(1,1,1)
        t.Size = size or 13
        t.Visible = false
        t.Outline = true
        t.OutlineColor = Color3.new(0,0,0)
        t.Center = true
        t.Font = 2
        return t
    end

    local function removePlayerEsp(player)
        local d = playerEspObjects[player]
        if not d then return end
        pcall(function() if d.box then d.box:Remove() end end)
        pcall(function() if d.boxFill then d.boxFill:Remove() end end)
        if d.box3D then
            for _, l in ipairs(d.box3D) do pcall(function() l:Remove() end) end
        end
        if d.fillRows then
            for _, l in ipairs(d.fillRows) do pcall(function() l:Remove() end) end
        end
        pcall(function() if d.healthbar then d.healthbar:Remove() end end)
        pcall(function() if d.nameText then d.nameText:Remove() end end)
        pcall(function() if d.distText then d.distText:Remove() end end)
        pcall(function() if d.tracer then d.tracer:Remove() end end)
        if d.skeleton then
            for _, l in ipairs(d.skeleton) do
                pcall(function() l:Remove() end)
            end
        end
        if d.chams then
            for _, sel in pairs(d.chams) do
                pcall(function() sel:Destroy() end)
            end
        end
        if d.conn then d.conn:Disconnect() end
        playerEspObjects[player] = nil
    end

    local function createPlayerEsp(plr)
        if playerEspObjects[plr] then return end

        -- Allocate 12 Drawing lines for 3D box edges
        local box3DLines = {}
        for _ = 1, 12 do
            local l = newLine(Box.OutlineColor, 1)
            table.insert(box3DLines, l)
        end

        -- Allocate gradient fill rows (30 lines for smooth gradient)
        local GRAD_ROWS = 30
        local fillRowLines = {}
        for _ = 1, GRAD_ROWS do
            local l = newLine(Filled.ColorStart, 2)
            table.insert(fillRowLines, l)
        end

        local entry = {
            box      = newQuad(Box.OutlineColor, 1),
            box3D    = box3DLines,   -- 12 lines for 3D wireframe
            boxFill  = (function()
                if not Drawing or not Drawing.new then return nil end
                local ok, q = pcall(function() return Drawing.new("Quad") end)
                if not ok or not q then return nil end
                q.Color = Filled.ColorStart
                q.Thickness = 1
                q.Filled = true
                q.Transparency = Filled.Transparency
                q.Visible = false
                return q
            end)(),
            fillRows = fillRowLines,  -- gradient rows
            healthbar= newLine(Color3.fromRGB(0,255,0), 3),
            nameText = newDrawText(TextESP.NameColor, TextESP.NameSize),
            distText = newDrawText(TextESP.DistanceColor, TextESP.DistanceSize),
            tracer   = newLine(TracersCfg.Color, TracersCfg.Thickness),
            skeleton = {},
            chams    = {},
            conn     = nil,
        }
        for _ = 1, #SKELETON_PAIRS do
            local l = newLine(SkeletonCfg.Color, SkeletonCfg.Thickness)
            table.insert(entry.skeleton, l)
        end
        playerEspObjects[plr] = entry

        local function getCharParts(char)
            if not char then return nil end
            local root = char:FindFirstChild("HumanoidRootPart")
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            return root, humanoid, char
        end

        entry.conn = _RunService.RenderStepped:Connect(function()
            pcall(function()
                local char = plr.Character
                local root, humanoid, _ = getCharParts(char)
                local cam = _Workspace.CurrentCamera

                local anyOn = Box.Enable or Filled.Enable or TextESP.Names or TextESP.Distance or TracersCfg.Enable or SkeletonCfg.Enable or ChamsCfg.Enable
                if not Box.MasterEnabled or not anyOn or not root or not root.Parent or not cam then
                    if entry.box then entry.box.Visible = false end
                    if entry.boxFill then entry.boxFill.Visible = false end
                    if entry.healthbar then entry.healthbar.Visible = false end
                    if entry.nameText then entry.nameText.Visible = false end
                    if entry.distText then entry.distText.Visible = false end
                    if entry.tracer then entry.tracer.Visible = false end
                    for _, l in ipairs(entry.skeleton) do if l then l.Visible = false end end
                    return
                end

                -- Project bounding box corners
                local cf = root.CFrame
                local size = char:GetExtentsSize()
                local halfX, halfY, halfZ = size.X/2, size.Y/2, size.Z/2

                local corners3D = {
                    cf * Vector3.new( halfX,  halfY, -halfZ),
                    cf * Vector3.new(-halfX,  halfY, -halfZ),
                    cf * Vector3.new(-halfX, -halfY, -halfZ),
                    cf * Vector3.new( halfX, -halfY, -halfZ),
                    cf * Vector3.new( halfX,  halfY,  halfZ),
                    cf * Vector3.new(-halfX,  halfY,  halfZ),
                    cf * Vector3.new(-halfX, -halfY,  halfZ),
                    cf * Vector3.new( halfX, -halfY,  halfZ),
                }

                local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
                local anyOnScreen = false
                for _, c3 in ipairs(corners3D) do
                    local sp, onScr = cam:WorldToViewportPoint(c3)
                    if onScr then
                        anyOnScreen = true
                        if sp.X < minX then minX = sp.X end
                        if sp.Y < minY then minY = sp.Y end
                        if sp.X > maxX then maxX = sp.X end
                        if sp.Y > maxY then maxY = sp.Y end
                    end
                end

                local rootSp, rootOnScreen = cam:WorldToViewportPoint(root.Position)
                if not anyOnScreen and not rootOnScreen then
                    if entry.box then entry.box.Visible = false end
                    if entry.boxFill then entry.boxFill.Visible = false end
                    if entry.healthbar then entry.healthbar.Visible = false end
                    if entry.nameText then entry.nameText.Visible = false end
                    if entry.distText then entry.distText.Visible = false end
                    if entry.tracer then entry.tracer.Visible = false end
                    for _, l in ipairs(entry.skeleton) do if l then l.Visible = false end end
                    return
                end

                -- Box (2D quad OR 3D 12-edge wireframe)
                if entry.box then
                    entry.box.Color = Box.OutlineColor
                    if Box.Enable and anyOnScreen then
                        if Box.Mode == "3D" then
                            -- Hide the 2D quad, show 12 edge lines
                            entry.box.Visible = false
                            local edges = entry.box3D
                            if edges then
                                -- Project all 8 corners
                                local pts = {}
                                for i, c3 in ipairs(corners3D) do
                                    local sp = cam:WorldToViewportPoint(c3)
                                    pts[i] = Vector2.new(sp.X, sp.Y)
                                end
                                -- 12 edges: front face (1-4), back face (5-8), connecting (1-5, 2-6, 3-7, 4-8)
                                local edgePairs = {
                                    {1,2},{2,3},{3,4},{4,1},  -- front
                                    {5,6},{6,7},{7,8},{8,5},  -- back
                                    {1,5},{2,6},{3,7},{4,8},  -- sides
                                }
                                for ei, ep in ipairs(edgePairs) do
                                    local l = edges[ei]
                                    if l then
                                        l.Color = Box.OutlineColor
                                        l.Thickness = Box.Thickness or 1
                                        l.From = pts[ep[1]]
                                        l.To   = pts[ep[2]]
                                        l.Visible = true
                                    end
                                end
                            end
                        else
                            -- 2D flat quad
                            if entry.box3D then
                                for _, l in ipairs(entry.box3D) do if l then l.Visible = false end end
                            end
                            entry.box.Thickness = Box.Thickness or 1
                            entry.box.PointA = Vector2.new(minX, minY)
                            entry.box.PointB = Vector2.new(maxX, minY)
                            entry.box.PointC = Vector2.new(maxX, maxY)
                            entry.box.PointD = Vector2.new(minX, maxY)
                            entry.box.Visible = true
                        end
                    else
                        entry.box.Visible = false
                        if entry.box3D then
                            for _, l in ipairs(entry.box3D) do if l then l.Visible = false end end
                        end
                    end
                end

                -- Fill (solid or gradient)
                if entry.boxFill then
                    if Filled.Enable and anyOnScreen then
                        -- Simple flat fill (Quad only supports single color)
                        local fillColor = Filled.ColorStart
                        if Filled.UseGradient and Filled.GradientStops and #Filled.GradientStops > 0 then
                            fillColor = lerpGradient(Filled.GradientStops, 0.5)
                        end
                        entry.boxFill.Color = fillColor
                        entry.boxFill.Transparency = Filled.Transparency
                        entry.boxFill.PointA = Vector2.new(minX, minY)
                        entry.boxFill.PointB = Vector2.new(maxX, minY)
                        entry.boxFill.PointC = Vector2.new(maxX, maxY)
                        entry.boxFill.PointD = Vector2.new(minX, maxY)
                        entry.boxFill.Visible = true

                        -- Gradient fill: draw per-row lines from top (ColorStart/stop[1]) to bottom (ColorEnd/stop[last])
                        if Filled.UseGradient then
                            local rows = entry.fillRows
                            if rows then
                                local numRows = #rows
                                for ri, lineObj in ipairs(rows) do
                                    local t = (ri - 1) / math.max(numRows - 1, 1)
                                    local rowY = minY + (maxY - minY) * t
                                    local rowColor = lerpGradient(Filled.GradientStops, 1 - t)
                                    lineObj.Color = rowColor
                                    lineObj.Transparency = Filled.Transparency
                                    lineObj.From = Vector2.new(minX, rowY)
                                    lineObj.To   = Vector2.new(maxX, rowY)
                                    lineObj.Thickness = 2
                                    lineObj.Visible = true
                                end
                                entry.boxFill.Visible = false  -- hide flat quad when gradient rows used
                            end
                        else
                            if entry.fillRows then
                                for _, lineObj in ipairs(entry.fillRows) do lineObj.Visible = false end
                            end
                        end
                    else
                        entry.boxFill.Visible = false
                        if entry.fillRows then
                            for _, lineObj in ipairs(entry.fillRows) do lineObj.Visible = false end
                        end
                    end
                end

                -- Health bar with custom gradient stops
                if entry.healthbar and Box.Healthbar.Enable and humanoid and anyOnScreen then
                    local hp    = humanoid.Health
                    local maxHp = humanoid.MaxHealth
                    local pct   = maxHp > 0 and math.clamp(hp / maxHp, 0, 1) or 0
                    local hpColor = lerpGradient(Box.HealthGradientStops, pct)
                    local barH   = maxY - minY
                    local barTop = maxY - barH * pct
                    entry.healthbar.Color     = hpColor
                    entry.healthbar.From      = Vector2.new(minX - 5, barTop)
                    entry.healthbar.To        = Vector2.new(minX - 5, maxY)
                    entry.healthbar.Thickness = Box.Healthbar.Thickness
                    entry.healthbar.Visible   = true
                elseif entry.healthbar then
                    entry.healthbar.Visible = false
                end

                -- Name (DisplayName or @Username)
                if entry.nameText then
                    if TextESP.Names and anyOnScreen then
                        local headPart = char:FindFirstChild("Head")
                        local headSp, headOn
                        if headPart then
                            headSp, headOn = cam:WorldToViewportPoint(headPart.Position)
                        end
                        local nameStr = TextESP.NameMode == "@Username"
                            and ("@" .. plr.Name)
                            or plr.DisplayName
                        entry.nameText.Text     = nameStr
                        entry.nameText.Color    = TextESP.NameColor
                        entry.nameText.Size     = TextESP.NameSize
                        entry.nameText.Position = Vector2.new(
                            headOn and headSp.X or (minX + maxX) / 2,
                            minY - 16
                        )
                        entry.nameText.Visible = true
                    else
                        entry.nameText.Visible = false
                    end
                end

                -- Distance
                if entry.distText then
                    if TextESP.Distance and anyOnScreen then
                        local dist = math.floor((cam.CFrame.Position - root.Position).Magnitude)
                        entry.distText.Text  = tostring(dist) .. "m"
                        entry.distText.Color = TextESP.DistanceColor
                        entry.distText.Size  = TextESP.DistanceSize
                        entry.distText.Position = Vector2.new((minX + maxX)/2, maxY + 2)
                        entry.distText.Visible = true
                    else
                        entry.distText.Visible = false
                    end
                end

                -- Tracer
                if entry.tracer then
                    if TracersCfg.Enable and rootOnScreen then
                        local vp = cam.ViewportSize
                        entry.tracer.Color = TracersCfg.Color
                        entry.tracer.Thickness = TracersCfg.Thickness
                        entry.tracer.From = Vector2.new(vp.X / 2, vp.Y)
                        entry.tracer.To   = Vector2.new(rootSp.X, rootSp.Y)
                        entry.tracer.Visible = true
                    else
                        entry.tracer.Visible = false
                    end
                end

                -- Skeleton
                for i, pair in ipairs(SKELETON_PAIRS) do
                    local l = entry.skeleton[i]
                    if l then
                        if SkeletonCfg.Enable then
                            local p1 = char:FindFirstChild(pair[1])
                            local p2 = char:FindFirstChild(pair[2])
                            if p1 and p2 then
                                local s1, on1 = cam:WorldToViewportPoint(p1.Position)
                                local s2, on2 = cam:WorldToViewportPoint(p2.Position)
                                if on1 and on2 then
                                    l.Color = SkeletonCfg.Color
                                    l.Thickness = SkeletonCfg.Thickness
                                    l.From = Vector2.new(s1.X, s1.Y)
                                    l.To   = Vector2.new(s2.X, s2.Y)
                                    l.Visible = true
                                else
                                    l.Visible = false
                                end
                            else
                                l.Visible = false
                            end
                        else
                            l.Visible = false
                        end
                    end
                end

                -- Chams (SelectionBox)
                if ChamsCfg.Enable then
                    if not entry.chams[plr] and char then
                        local sel = Instance.new("SelectionBox")
                        sel.Adornee = char
                        sel.Color3  = ChamsCfg.Color
                        sel.SurfaceTransparency = ChamsCfg.Transparency
                        sel.SurfaceColor3 = ChamsCfg.Color
                        sel.LineThickness = 0
                        sel.Parent = _Workspace.CurrentCamera
                        entry.chams[plr] = sel
                    end
                    if entry.chams[plr] then
                        entry.chams[plr].Color3 = ChamsCfg.Color
                        entry.chams[plr].SurfaceColor3 = ChamsCfg.Color
                        entry.chams[plr].SurfaceTransparency = ChamsCfg.Transparency
                    end
                else
                    if entry.chams[plr] then
                        pcall(function() entry.chams[plr]:Destroy() end)
                        entry.chams[plr] = nil
                    end
                end
            end)
        end)
    end

    -- Init ESP for all current + future players
    local function onPlayerAdded(plr)
        if plr == _LocalPlayer then return end
        createPlayerEsp(plr)
        plr.CharacterAdded:Connect(function()
            task.wait(0.5)
            removePlayerEsp(plr)
            createPlayerEsp(plr)
        end)
    end

    for _, plr in ipairs(_Players:GetPlayers()) do
        onPlayerAdded(plr)
    end
    _Players.PlayerAdded:Connect(onPlayerAdded)
    _Players.PlayerRemoving:Connect(function(plr)
        removePlayerEsp(plr)
    end)

    Window.OnUnload:Connect(function()
        for plr in pairs(playerEspObjects) do removePlayerEsp(plr) end
        clearUtilEsp()
        pcall(function() if espGui then espGui:Destroy() end end)
    end)

    -- ==================== ESP UI Controls ====================

    -- [ESP Sub] Player ESP (Left)
    Visuals_1_L:AddToggle({
        Title       = "Master Enable",
        Description = "Enable all ESP rendering",
        Default     = false,
        Callback    = function(v) Box.MasterEnabled = v end,
    })

    Visuals_1_L:AddToggle({
        Title       = "Box ESP",
        Description = "Show 2D bounding boxes around players",
        Default     = false,
        Callback    = function(v) Box.Enable = v end,
    })

    Visuals_1_L:AddToggle({
        Title       = "Fill ESP",
        Description = "Fill boxes with a semi-transparent colour",
        Default     = false,
        Callback    = function(v) Filled.Enable = v end,
    })

    Visuals_1_L:AddSlider({
        Title    = "Fill Transparency",
        Min      = 0, Max = 100, Step = 1,
        Default  = 70,
        Callback = function(v) Filled.Transparency = v / 100 end,
    })

    Visuals_1_L:AddToggle({
        Title       = "Health Bar",
        Description = "Show HP bar on left side of box",
        Default     = false,
        Callback    = function(v) Box.Healthbar.Enable = v end,
    })

    Visuals_1_L:AddSlider({
        Title    = "Health Bar Thickness",
        Min      = 1, Max = 8, Step = 1,
        Default  = 4,
        Callback = function(v) Box.Healthbar.Thickness = v end,
    })

    Visuals_1_L:AddToggle({
        Title       = "Player Names",
        Description = "Show player display name above box",
        Default     = false,
        Callback    = function(v) TextESP.Names = v end,
    })

    Visuals_1_L:AddSlider({
        Title    = "Name Text Size",
        Min      = 8, Max = 24, Step = 1,
        Default  = 13,
        Callback = function(v) TextESP.NameSize = v end,
    })

    -- [ESP Sub] Distance & Tracers (Right)
    Visuals_1_R:AddToggle({
        Title       = "Distance Text",
        Description = "Show distance (metres) below box",
        Default     = false,
        Callback    = function(v) TextESP.Distance = v end,
    })

    Visuals_1_R:AddSlider({
        Title    = "Distance Text Size",
        Min      = 8, Max = 24, Step = 1,
        Default  = 13,
        Callback = function(v) TextESP.DistanceSize = v end,
    })

    Visuals_1_R:AddToggle({
        Title       = "Tracers",
        Description = "Draw line from screen bottom to each player",
        Default     = false,
        Callback    = function(v) TracersCfg.Enable = v end,
    })

    Visuals_1_R:AddSlider({
        Title    = "Tracer Thickness",
        Min      = 1, Max = 6, Step = 1,
        Default  = 1,
        Callback = function(v) TracersCfg.Thickness = v end,
    })

    Visuals_1_R:AddToggle({
        Title       = "Skeleton",
        Description = "Draw bone lines between character joints",
        Default     = false,
        Callback    = function(v) SkeletonCfg.Enable = v end,
    })

    Visuals_1_R:AddSlider({
        Title    = "Skeleton Thickness",
        Min      = 1, Max = 4, Step = 1,
        Default  = 1,
        Callback = function(v) SkeletonCfg.Thickness = v end,
    })

    -- [Chams Sub] Chams (Left)
    Visuals_2_L:AddToggle({
        Title       = "Chams (SelectionBox)",
        Description = "Highlight player characters through walls",
        Default     = false,
        Callback    = function(v) ChamsCfg.Enable = v end,
    })

    Visuals_2_L:AddSlider({
        Title    = "Chams Transparency",
        Min      = 0, Max = 100, Step = 1,
        Default  = 0,
        Callback = function(v) ChamsCfg.Transparency = v / 100 end,
    })

    -- [Chams Sub] Skeleton Right section (reused for Utility ESP)
    Visuals_2_R:AddToggle({
        Title       = "Utility ESP",
        Description = "Show ESP for grenades & throwables in world",
        Default     = false,
        Callback    = function(v)
            UtilConfig.enable = v
            refreshUtilEsp()
        end,
    })

    Visuals_2_R:AddToggle({
        Title       = "Util Distance",
        Description = "Show distance text under utility items",
        Default     = false,
        Callback    = function(v) UtilConfig.distance = v end,
    })

    Visuals_2_R:AddToggle({
        Title       = "Util Images",
        Description = "Show item images above utility names",
        Default     = false,
        Callback    = function(v) UtilConfig.images = v end,
    })

end -- END ESP ENGINE


-- Player - Layout skeleton only
local PlayerTab = Window:AddTab({ Title = "Player", Icon = "person" })
local PlayerSubs = createSubTabs(PlayerTab, { "Movement", "Character", "Camera" })
local Player_1_L = PlayerSubs["Movement"]:AddLeftSection("Movement Attributes")
local Player_1_R = PlayerSubs["Movement"]:AddRightSection("Velocity Modifiers")
local Player_2_L = PlayerSubs["Character"]:AddLeftSection("Physics Simulation")
local Player_2_R = PlayerSubs["Character"]:AddRightSection("State & Attributes")
local Player_3_L = PlayerSubs["Camera"]:AddLeftSection("Field of View")
local Player_3_R = PlayerSubs["Camera"]:AddRightSection("Perspective Controls")

-- World - Layout skeleton only
local WorldTab = Window:AddTab({ Title = "World", Icon = "public" })
local WorldSubs = createSubTabs(WorldTab, { "Lighting", "Environment", "Atmosphere" })
local World_1_L = WorldSubs["Lighting"]:AddLeftSection("Lighting Effects")
local World_1_R = WorldSubs["Lighting"]:AddRightSection("Shadows & Bloom")
local World_2_L = WorldSubs["Environment"]:AddLeftSection("Weather Systems")
local World_2_R = WorldSubs["Environment"]:AddRightSection("Time of Day")
local World_3_L = WorldSubs["Atmosphere"]:AddLeftSection("Asset Streaming")
local World_3_R = WorldSubs["Atmosphere"]:AddRightSection("Ambient Physics")

-- Misc - Layout skeleton only
local MiscTab = Window:AddTab({ Title = "Misc", Icon = "more_horiz" })
local MiscSubs = createSubTabs(MiscTab, { "Utilities", "Game", "Debug" })
local Misc_1_L = MiscSubs["Utilities"]:AddLeftSection("Server Actions")
local Misc_1_R = MiscSubs["Utilities"]:AddRightSection("Connection State")
local Misc_2_L = MiscSubs["Game"]:AddLeftSection("General Tools")
local Misc_2_R = MiscSubs["Game"]:AddRightSection("Hotkeys & Keybinds")
local Misc_3_L = MiscSubs["Debug"]:AddLeftSection("Diagnostics")
local Misc_3_R = MiscSubs["Debug"]:AddRightSection("Console & Logs")

-- ==================== 7. HUD Elements (Custom Watermark & Keybind List) ====================
local KeybindList = Window:AddKeybindList({
    Title = "Keybinds",
    Position = "Left",
    ShowAll = true,
})

local hud = Window.Gui:FindFirstChild("HUD") or Window._hudLayer or Window.Gui

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local userId = player and player.UserId or 0
local userName = player and player.Name or "Unknown"

local MarketplaceService = game:GetService("MarketplaceService")
local gameName = "Unknown Game"
pcall(function()
    local info = MarketplaceService:GetProductInfo(game.PlaceId)
    if info and info.Name then gameName = info.Name end
end)

local executor = "Unknown"
if typeof(identifyexecutor) == "function" then
    executor = identifyexecutor()
elseif typeof(getexecutorname) == "function" then
    executor = getexecutorname()
end

local customWatermark = Instance.new("Frame")
customWatermark.Name = "LY_CustomWatermark"
customWatermark.AnchorPoint = Vector2.new(1, 0)
customWatermark.Position = UDim2.new(1, -20, 0, 78)
customWatermark.Size = UDim2.new(0, 0, 0, 36)
customWatermark.AutomaticSize = Enum.AutomaticSize.X
customWatermark.BackgroundColor3 = Color3.fromRGB(28, 26, 34)
customWatermark.BackgroundTransparency = 0.2
customWatermark.BorderSizePixel = 0
customWatermark.ZIndex = 10
customWatermark.Parent = hud

local wmScale = customWatermark:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
wmScale.Name = "LY_WatermarkScale"
wmScale.Scale = 1.0
wmScale.Parent = customWatermark

local wmCorner = Instance.new("UICorner")
wmCorner.CornerRadius = UDim.new(0, 18)
wmCorner.Parent = customWatermark

local wmStroke = Instance.new("UIStroke")
wmStroke.Color = Color3.fromRGB(90, 85, 105)
wmStroke.Transparency = 0.4
wmStroke.Thickness = 1
wmStroke.Parent = customWatermark

local wmPad = Instance.new("UIPadding")
wmPad.PaddingLeft = UDim.new(0, 14)
wmPad.PaddingRight = UDim.new(0, 16)
wmPad.PaddingTop = UDim.new(0, 0)
wmPad.PaddingBottom = UDim.new(0, 0)
wmPad.Parent = customWatermark

local wmLayout = Instance.new("UIListLayout")
wmLayout.FillDirection = Enum.FillDirection.Horizontal
wmLayout.VerticalAlignment = Enum.VerticalAlignment.Center
wmLayout.SortOrder = Enum.SortOrder.LayoutOrder
wmLayout.Padding = UDim.new(0, 10)
wmLayout.Parent = customWatermark

local function createSep(order)
    local sep = Instance.new("Frame")
    sep.Name = "Sep_" .. order
    sep.Size = UDim2.new(0, 1, 0, 16)
    sep.BackgroundColor3 = Color3.fromRGB(110, 105, 125)
    sep.BackgroundTransparency = 0.5
    sep.BorderSizePixel = 0
    sep.LayoutOrder = order
    sep.Parent = customWatermark
    return sep
end

-- 1. Title
local titleLbl = Instance.new("TextLabel")
titleLbl.Name = "Title"
titleLbl.Text = "LY Hub"
titleLbl.Font = Enum.Font.GothamBold
titleLbl.TextSize = 13
titleLbl.TextColor3 = Color3.fromRGB(208, 188, 255)
titleLbl.BackgroundTransparency = 1
titleLbl.AutomaticSize = Enum.AutomaticSize.X
titleLbl.Size = UDim2.new(0, 0, 1, 0)
titleLbl.LayoutOrder = 1
titleLbl.Parent = customWatermark

local sep1 = createSep(2)

-- 2. Avatar + Player ID
local avatarBlock = Instance.new("Frame")
avatarBlock.Name = "AvatarBlock"
avatarBlock.BackgroundTransparency = 1
avatarBlock.AutomaticSize = Enum.AutomaticSize.X
avatarBlock.Size = UDim2.new(0, 0, 1, 0)
avatarBlock.LayoutOrder = 3
avatarBlock.Parent = customWatermark

local abLayout = Instance.new("UIListLayout")
abLayout.FillDirection = Enum.FillDirection.Horizontal
abLayout.VerticalAlignment = Enum.VerticalAlignment.Center
abLayout.Padding = UDim.new(0, 6)
abLayout.Parent = avatarBlock

local avatarImg = Instance.new("ImageLabel")
avatarImg.Name = "AvatarImg"
avatarImg.Size = UDim2.fromOffset(22, 22)
avatarImg.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(userId) .. "&w=48&h=48"
avatarImg.BackgroundTransparency = 1
avatarImg.Parent = avatarBlock

local imgCorner = Instance.new("UICorner")
imgCorner.CornerRadius = UDim.new(1, 0)
imgCorner.Parent = avatarImg

local imgStroke = Instance.new("UIStroke")
imgStroke.Color = Color3.fromRGB(160, 150, 180)
imgStroke.Transparency = 0.3
imgStroke.Thickness = 1
imgStroke.Parent = avatarImg

local userLbl = Instance.new("TextLabel")
userLbl.Name = "UserLbl"
userLbl.Text = userName .. " (" .. tostring(userId) .. ")"
userLbl.Font = Enum.Font.GothamMedium
userLbl.TextSize = 12
userLbl.TextColor3 = Color3.fromRGB(235, 230, 240)
userLbl.BackgroundTransparency = 1
userLbl.AutomaticSize = Enum.AutomaticSize.X
userLbl.Size = UDim2.new(0, 0, 1, 0)
userLbl.Parent = avatarBlock

local sep2 = createSep(4)

-- 3. Game Name (無 emoji)
local gameBlock = Instance.new("Frame")
gameBlock.Name = "GameBlock"
gameBlock.BackgroundTransparency = 1
gameBlock.AutomaticSize = Enum.AutomaticSize.X
gameBlock.Size = UDim2.new(0, 0, 1, 0)
gameBlock.LayoutOrder = 5
gameBlock.Parent = customWatermark

local gbLayout = Instance.new("UIListLayout")
gbLayout.FillDirection = Enum.FillDirection.Horizontal
gbLayout.VerticalAlignment = Enum.VerticalAlignment.Center
gbLayout.Padding = UDim.new(0, 4)
gbLayout.Parent = gameBlock

local gameLbl = Instance.new("TextLabel")
gameLbl.Name = "GameLbl"
gameLbl.Text = gameName
gameLbl.Font = Enum.Font.GothamMedium
gameLbl.TextSize = 12
gameLbl.TextColor3 = Color3.fromRGB(210, 205, 220)
gameLbl.BackgroundTransparency = 1
gameLbl.AutomaticSize = Enum.AutomaticSize.X
gameLbl.Size = UDim2.new(0, 0, 1, 0)
gameLbl.Parent = gameBlock

local sep3 = createSep(6)

-- 4. Executor (無 emoji)
local execBlock = Instance.new("Frame")
execBlock.Name = "ExecBlock"
execBlock.BackgroundTransparency = 1
execBlock.AutomaticSize = Enum.AutomaticSize.X
execBlock.Size = UDim2.new(0, 0, 1, 0)
execBlock.LayoutOrder = 7
execBlock.Parent = customWatermark

local ebLayout = Instance.new("UIListLayout")
ebLayout.FillDirection = Enum.FillDirection.Horizontal
ebLayout.VerticalAlignment = Enum.VerticalAlignment.Center
ebLayout.Padding = UDim.new(0, 4)
ebLayout.Parent = execBlock

local execLbl = Instance.new("TextLabel")
execLbl.Name = "ExecLbl"
execLbl.Text = executor
execLbl.Font = Enum.Font.GothamBold
execLbl.TextSize = 12
execLbl.TextColor3 = Color3.fromRGB(160, 210, 255)
execLbl.BackgroundTransparency = 1
execLbl.AutomaticSize = Enum.AutomaticSize.X
execLbl.Size = UDim2.new(0, 0, 1, 0)
execLbl.Parent = execBlock

local sep4 = createSep(8)

-- 5. FPS
local fpsBlock = Instance.new("Frame")
fpsBlock.Name = "FPSBlock"
fpsBlock.BackgroundTransparency = 1
fpsBlock.AutomaticSize = Enum.AutomaticSize.X
fpsBlock.Size = UDim2.new(0, 0, 1, 0)
fpsBlock.LayoutOrder = 9
fpsBlock.Parent = customWatermark

local fpsLayout = Instance.new("UIListLayout")
fpsLayout.FillDirection = Enum.FillDirection.Horizontal
fpsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
fpsLayout.Padding = UDim.new(0, 4)
fpsLayout.Parent = fpsBlock

local fpsLbl = Instance.new("TextLabel")
fpsLbl.Name = "FPSLbl"
fpsLbl.Text = "240 FPS"
fpsLbl.Font = Enum.Font.GothamMedium
fpsLbl.TextSize = 12
fpsLbl.TextColor3 = Color3.fromRGB(200, 195, 210)
fpsLbl.BackgroundTransparency = 1
fpsLbl.AutomaticSize = Enum.AutomaticSize.X
fpsLbl.Size = UDim2.new(0, 0, 1, 0)
fpsLbl.Parent = fpsBlock

local sep5 = createSep(10)

-- 6. Ping
local pingBlock = Instance.new("Frame")
pingBlock.Name = "PingBlock"
pingBlock.BackgroundTransparency = 1
pingBlock.AutomaticSize = Enum.AutomaticSize.X
pingBlock.Size = UDim2.new(0, 0, 1, 0)
pingBlock.LayoutOrder = 11
pingBlock.Parent = customWatermark

local pingLayout = Instance.new("UIListLayout")
pingLayout.FillDirection = Enum.FillDirection.Horizontal
pingLayout.VerticalAlignment = Enum.VerticalAlignment.Center
pingLayout.Padding = UDim.new(0, 4)
pingLayout.Parent = pingBlock

local pingLbl = Instance.new("TextLabel")
pingLbl.Name = "PingLbl"
pingLbl.Text = "88 ms"
pingLbl.Font = Enum.Font.GothamMedium
pingLbl.TextSize = 12
pingLbl.TextColor3 = Color3.fromRGB(200, 195, 210)
pingLbl.BackgroundTransparency = 1
pingLbl.AutomaticSize = Enum.AutomaticSize.X
pingLbl.Size = UDim2.new(0, 0, 1, 0)
pingLbl.Parent = pingBlock

local sep6 = createSep(12)

-- 7. Elapsed Time (無 emoji)
local timeBlock = Instance.new("Frame")
timeBlock.Name = "TimeBlock"
timeBlock.BackgroundTransparency = 1
timeBlock.AutomaticSize = Enum.AutomaticSize.X
timeBlock.Size = UDim2.new(0, 0, 1, 0)
timeBlock.LayoutOrder = 13
timeBlock.Parent = customWatermark

local tbLayout = Instance.new("UIListLayout")
tbLayout.FillDirection = Enum.FillDirection.Horizontal
tbLayout.VerticalAlignment = Enum.VerticalAlignment.Center
tbLayout.Padding = UDim.new(0, 4)
tbLayout.Parent = timeBlock

local timeLbl = Instance.new("TextLabel")
timeLbl.Name = "TimeLbl"
timeLbl.Text = "00:00:00"
timeLbl.Font = Enum.Font.GothamBold
timeLbl.TextSize = 12
timeLbl.TextColor3 = Color3.fromRGB(235, 230, 245)
timeLbl.BackgroundTransparency = 1
timeLbl.AutomaticSize = Enum.AutomaticSize.X
timeLbl.Size = UDim2.new(0, 0, 1, 0)
timeLbl.Parent = timeBlock

-- State & Dynamic Update Logic
local wmState = {
    Avatar = true,
    User = true,
    Game = true,
    Executor = true,
    FPS = true,
    Ping = true,
    Time = true,
    Master = true,
}

local function refreshWatermark()
    if not wmState.Master then
        customWatermark.Visible = false
        return
    end
    customWatermark.Visible = true

    avatarImg.Visible = wmState.Avatar
    userLbl.Visible = wmState.User
    local hasUserBlock = wmState.Avatar or wmState.User
    avatarBlock.Visible = hasUserBlock
    sep1.Visible = hasUserBlock

    gameBlock.Visible = wmState.Game
    sep2.Visible = wmState.Game and hasUserBlock

    execBlock.Visible = wmState.Executor
    sep3.Visible = wmState.Executor and (wmState.Game or hasUserBlock)

    fpsBlock.Visible = wmState.FPS
    sep4.Visible = wmState.FPS and (wmState.Executor or wmState.Game or hasUserBlock)

    pingBlock.Visible = wmState.Ping
    sep5.Visible = wmState.Ping and (wmState.FPS or wmState.Executor or wmState.Game or hasUserBlock)

    timeBlock.Visible = wmState.Time
    sep6.Visible = wmState.Time and (wmState.Ping or wmState.FPS or wmState.Executor or wmState.Game or hasUserBlock)
end

local startTick = os.time()
local lastStatUpdate = 0
local hudActive = true

local hudUpdateConn = RunService.RenderStepped:Connect(function()
    if not hudActive then return end
    local now = tick()
    if now - lastStatUpdate >= 0.5 then
        lastStatUpdate = now
        if wmState.FPS then
            fpsLbl.Text = string.format("%d FPS", math.floor(workspace:GetRealPhysicsFPS()))
        end
        if wmState.Ping then
            pcall(function()
                pingLbl.Text = string.format("%d ms", math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()))
            end)
        end
    end
    if wmState.Time then
        local elapsed = math.floor(os.time() - startTick)
        local h = math.floor(elapsed / 3600)
        local m = math.floor((elapsed % 3600) / 60)
        local s = elapsed % 60
        timeLbl.Text = string.format("%02d:%02d:%02d", h, m, s)
    end
end)

-- ==================== Watermark Dragging System (Hold-to-drag, no sticking) ====================
local UserInputService = game:GetService("UserInputService")
local wmDragging = false
local wmDragStart = nil
local wmStartPos = nil

customWatermark.Active = true

local wmInputConn = customWatermark.InputBegan:Connect(function(input)
    -- Only allow dragging when main UI is open
    if not (Window.Visible and not Window.Minimized) then return end

    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        wmDragging = true
        wmDragStart = input.Position

        if customWatermark.AnchorPoint.X ~= 0 or customWatermark.AnchorPoint.Y ~= 0 then
            local absX = customWatermark.AbsolutePosition.X
            local absY = customWatermark.AbsolutePosition.Y
            local hudY = hud.AbsolutePosition.Y
            customWatermark.AnchorPoint = Vector2.new(0, 0)
            customWatermark.Position = UDim2.fromOffset(absX, absY - hudY)
        end
        wmStartPos = customWatermark.Position
    end
end)

local saveLastPositions = nil

-- Global input ended: instantly stop dragging upon release to prevent sticking
local wmEndConn = UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        if wmDragging then
            wmDragging = false
            wmDragStart = nil
            wmStartPos = nil
            if saveLastPositions then saveLastPositions() end
        else
            wmDragging = false
            wmDragStart = nil
            wmStartPos = nil
        end
    end
end)

local wmMoveConn = UserInputService.InputChanged:Connect(function(input)
    if not wmDragging then return end

    -- Abort if window is closed or mouse button is released
    if not (Window.Visible and not Window.Minimized) then
        wmDragging = false
        return
    end

    if input.UserInputType == Enum.UserInputType.MouseMovement then
        if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
            wmDragging = false
            return
        end
    end

    if (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) and wmDragStart and wmStartPos then
        local delta = input.Position - wmDragStart
        local newX = wmStartPos.X.Offset + delta.X
        local newY = wmStartPos.Y.Offset + delta.Y

        local cam = workspace.CurrentCamera
        local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
        local wmWidth = customWatermark.AbsoluteSize.X
        local wmHeight = customWatermark.AbsoluteSize.Y

        newX = math.clamp(newX, 8, vp.X - wmWidth - 8)
        newY = math.clamp(newY, 8, vp.Y - wmHeight - 8)

        customWatermark.Position = UDim2.fromOffset(newX, newY)
    end
end)

-- ==================== Keybinds Dragging System (Only movable when UI is open) ====================
local kb = hud:FindFirstChild("Keybinds")
local kbScale = nil

if kb then
    kbScale = kb:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
    kbScale.Name = "LY_KeybindScale"
    kbScale.Scale = 1.0
    kbScale.Parent = kb

    pcall(function()
        for _, c in ipairs(getconnections(kb.InputBegan)) do
            c:Disable()
        end
    end)
end

local kbDragging = false
local kbDragStart = nil
local kbStartPos = nil

local kbInputConn = nil
local kbEndConn = nil
local kbMoveConn = nil

if kb then
    kb.Active = true
    kbInputConn = kb.InputBegan:Connect(function(input)
        -- Only allow dragging when main UI is open!
        if not (Window.Visible and not Window.Minimized) then return end

        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            kbDragging = true
            kbDragStart = input.Position

            if kb.AnchorPoint.X ~= 0 or kb.AnchorPoint.Y ~= 0 then
                local absX = kb.AbsolutePosition.X
                local absY = kb.AbsolutePosition.Y
                local hudY = hud.AbsolutePosition.Y
                kb.AnchorPoint = Vector2.new(0, 0)
                kb.Position = UDim2.fromOffset(absX, absY - hudY)
            end
            kbStartPos = kb.Position
        end
    end)

    kbEndConn = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if kbDragging then
                kbDragging = false
                kbDragStart = nil
                kbStartPos = nil
                if saveLastPositions then saveLastPositions() end
            else
                kbDragging = false
                kbDragStart = nil
                kbStartPos = nil
            end
        end
    end)

    kbMoveConn = UserInputService.InputChanged:Connect(function(input)
        if not kbDragging then return end

        if not (Window.Visible and not Window.Minimized) then
            kbDragging = false
            return
        end

        if input.UserInputType == Enum.UserInputType.MouseMovement then
            if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
                kbDragging = false
                return
            end
        end

        if (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) and kbDragStart and kbStartPos then
            local delta = input.Position - kbDragStart
            local newX = kbStartPos.X.Offset + delta.X
            local newY = kbStartPos.Y.Offset + delta.Y

            local cam = workspace.CurrentCamera
            local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
            local kbWidth = kb.AbsoluteSize.X
            local kbHeight = kb.AbsoluteSize.Y

            newX = math.clamp(newX, 8, vp.X - kbWidth - 8)
            newY = math.clamp(newY, 8, vp.Y - kbHeight - 8)

            kb.Position = UDim2.fromOffset(newX, newY)
        end
    end)
end

-- ==================== Persistent Watermark & Keybinds Position Memory ====================
local POSITION_SAVE_FILE = "LYHub/last_positions.json"

saveLastPositions = function()
    pcall(function()
        if not isfolder("LYHub") then makefolder("LYHub") end
        local data = {
            wmPosition = {
                AnchorX = customWatermark.AnchorPoint.X,
                AnchorY = customWatermark.AnchorPoint.Y,
                ScaleX = customWatermark.Position.X.Scale,
                OffsetX = customWatermark.Position.X.Offset,
                ScaleY = customWatermark.Position.Y.Scale,
                OffsetY = customWatermark.Position.Y.Offset,
            },
            kbPosition = kb and {
                AnchorX = kb.AnchorPoint.X,
                AnchorY = kb.AnchorPoint.Y,
                ScaleX = kb.Position.X.Scale,
                OffsetX = kb.Position.X.Offset,
                ScaleY = kb.Position.Y.Scale,
                OffsetY = kb.Position.Y.Offset,
            } or nil,
        }
        writefile(POSITION_SAVE_FILE, HttpService:JSONEncode(data))
    end)
end

local function loadLastPositions()
    local success = pcall(function()
        if isfile(POSITION_SAVE_FILE) then
            local raw = readfile(POSITION_SAVE_FILE)
            local data = HttpService:JSONDecode(raw)
            if typeof(data) == "table" then
                if data.wmPosition and typeof(data.wmPosition) == "table" then
                    if data.wmPosition.ScaleX ~= nil then
                        customWatermark.AnchorPoint = Vector2.new(data.wmPosition.AnchorX or 0, data.wmPosition.AnchorY or 0)
                        customWatermark.Position = UDim2.new(data.wmPosition.ScaleX, data.wmPosition.OffsetX, data.wmPosition.ScaleY, data.wmPosition.OffsetY)
                    elseif data.wmPosition.X ~= nil then
                        customWatermark.AnchorPoint = Vector2.new(0, 0)
                        customWatermark.Position = UDim2.fromOffset(data.wmPosition.X, data.wmPosition.Y)
                    end
                end
                if data.kbPosition and typeof(data.kbPosition) == "table" and kb then
                    if data.kbPosition.ScaleX ~= nil then
                        kb.AnchorPoint = Vector2.new(data.kbPosition.AnchorX or 0, data.kbPosition.AnchorY or 0)
                        kb.Position = UDim2.new(data.kbPosition.ScaleX, data.kbPosition.OffsetX, data.kbPosition.ScaleY, data.kbPosition.OffsetY)
                    elseif data.kbPosition.X ~= nil then
                        kb.AnchorPoint = Vector2.new(0, 0)
                        kb.Position = UDim2.fromOffset(data.kbPosition.X, data.kbPosition.Y)
                    end
                end
            end
        end
    end)
    return success
end

-- Immediately restore positions from last session
loadLastPositions()

Window.OnUnload:Connect(function()
    pcall(function() if saveLastPositions then saveLastPositions() end end)
    hudActive = false
    pcall(function() hudUpdateConn:Disconnect() end)
    pcall(function() wmInputConn:Disconnect() end)
    pcall(function() wmEndConn:Disconnect() end)
    pcall(function() wmMoveConn:Disconnect() end)
    pcall(function() customWatermark:Destroy() end)
    pcall(function() if kbInputConn then kbInputConn:Disconnect() end end)
    pcall(function() if kbEndConn then kbEndConn:Disconnect() end end)
    pcall(function() if kbMoveConn then kbMoveConn:Disconnect() end end)
end)

-- ==================== 8. SETTINGS (Themes / Config / HUD) ====================
local SettingsTab = Window:AddSettingsTab() or Window.Tabs[#Window.Tabs]
local SettingsSubs = createSubTabs(SettingsTab, { "Themes", "Config", "HUD" })

local colorLeft = SettingsSubs["Themes"].Left
local colorRight = SettingsSubs["Themes"].Right
local configLeft = SettingsSubs["Config"].Left
local configRight = SettingsSubs["Config"].Right

-- Move Appearance, Theme editor, Background into "Themes" dual columns
local appFrame = SettingsTab.Instance:FindFirstChild("Appearance")
local themeFrame = SettingsTab.Instance:FindFirstChild("Theme editor")
local bgFrame = SettingsTab.Instance:FindFirstChild("Background")

if appFrame then
    appFrame.LayoutOrder = 1
    appFrame.Size = UDim2.new(1, 0, 0, 0)
    appFrame.Parent = colorLeft
end
if themeFrame then
    themeFrame.LayoutOrder = 1
    themeFrame.Size = UDim2.new(1, 0, 0, 0)
    themeFrame.Parent = colorRight
end
if bgFrame then
    bgFrame.LayoutOrder = 2
    bgFrame.Size = UDim2.new(1, 0, 0, 0)
    bgFrame.Parent = colorRight
end

-- Move Configuration and Interface into "Config" dual columns
local cfgFrame = SettingsTab.Instance:FindFirstChild("Configuration")
local ifaceFrame = SettingsTab.Instance:FindFirstChild("Interface")
local origHudFrame = SettingsTab.Instance:FindFirstChild("HUD")

if cfgFrame then
    cfgFrame.LayoutOrder = 1
    cfgFrame.Size = UDim2.new(1, 0, 0, 0)
    cfgFrame.Parent = configLeft
end
if ifaceFrame then
    ifaceFrame.LayoutOrder = 2
    ifaceFrame.Size = UDim2.new(1, 0, 0, 0)
    ifaceFrame.Parent = configLeft
end
if origHudFrame then
    origHudFrame.Visible = false
    origHudFrame.Parent = nil
end

-- ==================== Visual & Appearance Config System ====================
local VISUAL_CONFIG_FOLDER = "LYHub/VisualConfigs"
local AUTOLOAD_FILE = "LYHub/VisualConfigs/autoload.txt"

local function getVisualConfigs()
    local configs = {}
    pcall(function()
        if not isfolder("LYHub") then makefolder("LYHub") end
        if not isfolder(VISUAL_CONFIG_FOLDER) then makefolder(VISUAL_CONFIG_FOLDER) end
        local files = listfiles(VISUAL_CONFIG_FOLDER)
        for _, path in ipairs(files) do
            local name = path:match("([^/\\]+)%.json$")
            if name then
                table.insert(configs, name)
            end
        end
    end)
    if #configs == 0 then
        table.insert(configs, "default_visuals")
    end
    return configs
end

local function saveVisualConfig(configName)
    if not configName or configName == "" then return false, "Invalid name" end
    local data = {
        uiTransparency = math.round(Window.Instance.BackgroundTransparency * 100),
        uiScale = math.round(uiScale.Scale * 100),
        watermarkScale = math.round(wmScale.Scale * 100),
        keybindsScale = kbScale and math.round(kbScale.Scale * 100) or 100,
        backdropEnabled = backdropSettings.Enabled,
        backdropTransparency = math.round(backdropSettings.Transparency * 100),
        snowEnabled = snowSettings.Enabled,
        snowSpeed = math.round(snowSettings.SpeedMultiplier * 100),
        snowSize = snowSettings.BaseSize,
        snowCount = snowSettings.Count,
        customCursor = cursorSettings.Enabled,
        cursorScale = cursorSettings.Scale,
        wmState = {
            Avatar = wmState.Avatar,
            User = wmState.User,
            Game = wmState.Game,
            Executor = wmState.Executor,
            FPS = wmState.FPS,
            Ping = wmState.Ping,
            Time = wmState.Time,
            Master = wmState.Master,
        },
        wmPosition = {
            AnchorX = customWatermark.AnchorPoint.X,
            AnchorY = customWatermark.AnchorPoint.Y,
            ScaleX = customWatermark.Position.X.Scale,
            OffsetX = customWatermark.Position.X.Offset,
            ScaleY = customWatermark.Position.Y.Scale,
            OffsetY = customWatermark.Position.Y.Offset,
        },
        kbPosition = kb and {
            AnchorX = kb.AnchorPoint.X,
            AnchorY = kb.AnchorPoint.Y,
            ScaleX = kb.Position.X.Scale,
            OffsetX = kb.Position.X.Offset,
            ScaleY = kb.Position.Y.Scale,
            OffsetY = kb.Position.Y.Offset,
        } or nil,
    }
    
    local success, err = pcall(function()
        if not isfolder("LYHub") then makefolder("LYHub") end
        if not isfolder(VISUAL_CONFIG_FOLDER) then makefolder(VISUAL_CONFIG_FOLDER) end
        local json = HttpService:JSONEncode(data)
        writefile(VISUAL_CONFIG_FOLDER .. "/" .. configName .. ".json", json)
    end)
    if not success then return false, err end
    return true
end

local function loadVisualConfig(configName)
    local filePath = VISUAL_CONFIG_FOLDER .. "/" .. configName .. ".json"
    if not isfile(filePath) then return false, "Config not found" end
    
    local content = readfile(filePath)
    local success, data = pcall(function()
        return HttpService:JSONDecode(content)
    end)
    if not success or typeof(data) ~= "table" then return false, "Corrupted config" end
    
    -- Apply UI Transparency
    if data.uiTransparency ~= nil then
        local t = data.uiTransparency / 100
        Window.Instance.BackgroundTransparency = t
        if Window._pages then
            Window._pages.BackgroundTransparency = math.clamp(t + 0.1, 0, 0.9)
        end
    end
    
    -- Apply UI Scale
    if data.uiScale ~= nil then
        uiScale.Scale = data.uiScale / 100
    end
    
    -- Apply Watermark Scale
    if data.watermarkScale ~= nil then
        wmScale.Scale = data.watermarkScale / 100
    end
    
    -- Apply Keybinds Scale
    if data.keybindsScale ~= nil and kbScale then
        kbScale.Scale = data.keybindsScale / 100
    end
    
    -- Apply Backdrop Settings
    if data.backdropEnabled ~= nil then
        backdropSettings.Enabled = data.backdropEnabled
        local isOpen = Window.Visible and not Window.Minimized
        backdrop.Visible = isOpen and data.backdropEnabled
    end
    if data.backdropTransparency ~= nil then
        backdropSettings.Transparency = data.backdropTransparency / 100
        if backdropSettings.Enabled and Window.Visible and not Window.Minimized then
            backdrop.BackgroundTransparency = backdropSettings.Transparency
        end
    end
    
    -- Apply Snow Settings
    if data.snowEnabled ~= nil then
        snowSettings.Enabled = data.snowEnabled
        local isOpen = Window.Visible and not Window.Minimized
        snowContainer.Visible = isOpen and data.snowEnabled
    end
    if data.snowSpeed ~= nil then
        snowSettings.SpeedMultiplier = data.snowSpeed / 100
    end
    if data.snowSize ~= nil then
        updateSnowSize(data.snowSize)
    end
    if data.snowCount ~= nil then
        updateSnowCount(data.snowCount)
    end
    
    -- Apply Custom Cursor Settings
    if data.customCursor ~= nil then
        cursorSettings.Enabled = data.customCursor
        if updateCursorState then
            updateCursorState()
        end
    end
    if data.cursorScale ~= nil then
        cursorSettings.Scale = data.cursorScale
        if cursorScale then
            cursorScale.Scale = data.cursorScale / 100
        end
    end
    
    -- Apply Watermark State
    if data.wmState and typeof(data.wmState) == "table" then
        for k, v in pairs(data.wmState) do
            wmState[k] = v
        end
        refreshWatermark()
    end
    
    -- Apply Positions
    if data.wmPosition and typeof(data.wmPosition) == "table" then
        if data.wmPosition.ScaleX ~= nil then
            customWatermark.AnchorPoint = Vector2.new(data.wmPosition.AnchorX or 0, data.wmPosition.AnchorY or 0)
            customWatermark.Position = UDim2.new(data.wmPosition.ScaleX, data.wmPosition.OffsetX, data.wmPosition.ScaleY, data.wmPosition.OffsetY)
        elseif data.wmPosition.X ~= nil then
            customWatermark.AnchorPoint = Vector2.new(0, 0)
            customWatermark.Position = UDim2.fromOffset(data.wmPosition.X, data.wmPosition.Y)
        end
    end
    if data.kbPosition and typeof(data.kbPosition) == "table" and kb then
        if data.kbPosition.ScaleX ~= nil then
            kb.AnchorPoint = Vector2.new(data.kbPosition.AnchorX or 0, data.kbPosition.AnchorY or 0)
            kb.Position = UDim2.new(data.kbPosition.ScaleX, data.kbPosition.OffsetX, data.kbPosition.ScaleY, data.kbPosition.OffsetY)
        elseif data.kbPosition.X ~= nil then
            kb.AnchorPoint = Vector2.new(0, 0)
            kb.Position = UDim2.fromOffset(data.kbPosition.X, data.kbPosition.Y)
        end
    end
    if saveLastPositions then
        pcall(saveLastPositions)
    end
    
    -- Sync Sliders and Toggles in Settings -> HUD
    pcall(function()
        local flags = Window.Flags
        if flags then
            if data.uiTransparency and flags["Sett_UIPanelTransparency"] then flags["Sett_UIPanelTransparency"]:Set(data.uiTransparency) end
            if data.uiScale and flags["Sett_UIPanelScale"] then flags["Sett_UIPanelScale"]:Set(data.uiScale) end
            if data.watermarkScale and flags["Sett_WatermarkScale"] then flags["Sett_WatermarkScale"]:Set(data.watermarkScale) end
            if data.keybindsScale and flags["Sett_KeybindScale"] then flags["Sett_KeybindScale"]:Set(data.keybindsScale) end
            if data.backdropEnabled ~= nil and flags["Sett_BackdropEnabled"] then flags["Sett_BackdropEnabled"]:Set(data.backdropEnabled) end
            if data.backdropTransparency and flags["Sett_BackdropTransparency"] then flags["Sett_BackdropTransparency"]:Set(data.backdropTransparency) end
            if data.snowEnabled ~= nil and flags["Sett_SnowEnabled"] then flags["Sett_SnowEnabled"]:Set(data.snowEnabled) end
            if data.snowSpeed and flags["Sett_SnowSpeed"] then flags["Sett_SnowSpeed"]:Set(data.snowSpeed) end
            if data.snowSize and flags["Sett_SnowSize"] then flags["Sett_SnowSize"]:Set(data.snowSize) end
            if data.snowCount and flags["Sett_SnowCount"] then flags["Sett_SnowCount"]:Set(data.snowCount) end
            if data.customCursor ~= nil and flags["Sett_CustomCursorEnabled"] then flags["Sett_CustomCursorEnabled"]:Set(data.customCursor) end
            if data.cursorScale and flags["Sett_CursorScale"] then flags["Sett_CursorScale"]:Set(data.cursorScale) end
            
            if data.wmState then
                if data.wmState.Avatar ~= nil and flags["HUD_ShowAvatar"] then flags["HUD_ShowAvatar"]:Set(data.wmState.Avatar) end
                if data.wmState.User ~= nil and flags["HUD_ShowUserId"] then flags["HUD_ShowUserId"]:Set(data.wmState.User) end
                if data.wmState.Game ~= nil and flags["HUD_ShowGame"] then flags["HUD_ShowGame"]:Set(data.wmState.Game) end
                if data.wmState.Executor ~= nil and flags["HUD_ShowExecutor"] then flags["HUD_ShowExecutor"]:Set(data.wmState.Executor) end
                if data.wmState.FPS ~= nil and flags["HUD_ShowFPS"] then flags["HUD_ShowFPS"]:Set(data.wmState.FPS) end
                if data.wmState.Ping ~= nil and flags["HUD_ShowPing"] then flags["HUD_ShowPing"]:Set(data.wmState.Ping) end
                if data.wmState.Time ~= nil and flags["HUD_ShowSessionTime"] then flags["HUD_ShowSessionTime"]:Set(data.wmState.Time) end
                if data.wmState.Master ~= nil and flags["HUD_MasterToggle"] then flags["HUD_MasterToggle"]:Set(data.wmState.Master) end
            end
        end
    end)
    
    return true
end

local function resetVisualDefaults()
    Window.Instance.BackgroundTransparency = 0.15
    if Window._pages then Window._pages.BackgroundTransparency = 0.25 end
    
    uiScale.Scale = 1.0
    wmScale.Scale = 1.0
    if kbScale then kbScale.Scale = 1.0 end
    
    backdropSettings.Enabled = true
    backdropSettings.Transparency = 0.55
    if Window.Visible and not Window.Minimized then
        backdrop.Visible = true
        backdrop.BackgroundTransparency = 0.55
    end
    
    snowSettings.Enabled = true
    snowSettings.SpeedMultiplier = 1.0
    updateSnowSize(5)
    updateSnowCount(45)
    if Window.Visible and not Window.Minimized then
        snowContainer.Visible = true
    end

    cursorSettings.Enabled = true
    cursorSettings.Scale = 100
    if cursorScale then cursorScale.Scale = 1.0 end
    if updateCursorState then
        updateCursorState()
    end
    
    wmState.Avatar = true
    wmState.User = true
    wmState.Game = true
    wmState.Executor = true
    wmState.FPS = true
    wmState.Ping = true
    wmState.Time = true
    wmState.Master = true
    refreshWatermark()
    
    customWatermark.AnchorPoint = Vector2.new(1, 0)
    customWatermark.Position = UDim2.new(1, -20, 0, 78)
    if kb then
        kb.Position = UDim2.new(0, 20, 0.5, 0)
        kb.AnchorPoint = Vector2.new(0, 0.5)
    end
    if saveLastPositions then
        pcall(saveLastPositions)
    end
    
    pcall(function()
        local flags = Window.Flags
        if flags then
            if flags["Sett_UIPanelTransparency"] then flags["Sett_UIPanelTransparency"]:Set(15) end
            if flags["Sett_UIPanelScale"] then flags["Sett_UIPanelScale"]:Set(100) end
            if flags["Sett_WatermarkScale"] then flags["Sett_WatermarkScale"]:Set(100) end
            if flags["Sett_KeybindScale"] then flags["Sett_KeybindScale"]:Set(100) end
            if flags["Sett_BackdropEnabled"] then flags["Sett_BackdropEnabled"]:Set(true) end
            if flags["Sett_BackdropTransparency"] then flags["Sett_BackdropTransparency"]:Set(55) end
            if flags["Sett_SnowEnabled"] then flags["Sett_SnowEnabled"]:Set(true) end
            if flags["Sett_SnowSpeed"] then flags["Sett_SnowSpeed"]:Set(100) end
            if flags["Sett_SnowSize"] then flags["Sett_SnowSize"]:Set(5) end
            if flags["Sett_SnowCount"] then flags["Sett_SnowCount"]:Set(45) end
            if flags["Sett_CustomCursorEnabled"] then flags["Sett_CustomCursorEnabled"]:Set(true) end
            if flags["Sett_CursorScale"] then flags["Sett_CursorScale"]:Set(100) end
            if flags["HUD_ShowAvatar"] then flags["HUD_ShowAvatar"]:Set(true) end
            if flags["HUD_ShowUserId"] then flags["HUD_ShowUserId"]:Set(true) end
            if flags["HUD_ShowGame"] then flags["HUD_ShowGame"]:Set(true) end
            if flags["HUD_ShowExecutor"] then flags["HUD_ShowExecutor"]:Set(true) end
            if flags["HUD_ShowFPS"] then flags["HUD_ShowFPS"]:Set(true) end
            if flags["HUD_ShowPing"] then flags["HUD_ShowPing"]:Set(true) end
            if flags["HUD_ShowSessionTime"] then flags["HUD_ShowSessionTime"]:Set(true) end
            if flags["HUD_MasterToggle"] then flags["HUD_MasterToggle"]:Set(true) end
        end
    end)
end

-- Build "Visual Configuration" section inside Settings -> Config Right Column
local currentVisConfigName = "default_visuals"
local selectedVisConfig = "default_visuals"

local visCfgSec = SettingsSubs["Config"]:AddRightSection("Visual Configuration")

visCfgSec:AddInput({
    Title = "Visual Config Name",
    Default = "default_visuals",
    Placeholder = "Enter profile name...",
    Callback = function(val)
        if val and val ~= "" then
            currentVisConfigName = val
        end
    end,
})

local visCfgDropdown = visCfgSec:AddDropdown({
    Title = "Saved Visual Profiles",
    Values = getVisualConfigs(),
    Default = getVisualConfigs()[1] or "default_visuals",
    Callback = function(val)
        selectedVisConfig = val
        currentVisConfigName = val
    end,
})

visCfgSec:AddButton({
    Title = "Save Visual Config",
    Description = "Save current appearance, sizing, effects, & HUD setup",
    Callback = function()
        local success, err = saveVisualConfig(currentVisConfigName)
        if success then
            selectedVisConfig = currentVisConfigName
            visCfgDropdown:SetOptions(getVisualConfigs())
            visCfgDropdown:Set(currentVisConfigName)
            Window:Notify({
                Title = "Visual Config",
                Content = "Saved visual profile: " .. currentVisConfigName,
                Icon = "check"
            })
        else
            Window:Notify({
                Title = "Visual Config Error",
                Content = "Failed to save: " .. tostring(err),
                Icon = "error"
            })
        end
    end,
})

visCfgSec:AddButton({
    Title = "Load Visual Config",
    Description = "Apply selected appearance and HUD profile",
    Callback = function()
        local target = selectedVisConfig or currentVisConfigName
        local success, err = loadVisualConfig(target)
        if success then
            Window:Notify({
                Title = "Visual Config",
                Content = "Loaded visual profile: " .. target,
                Icon = "check"
            })
        else
            Window:Notify({
                Title = "Visual Config Error",
                Content = "Failed to load: " .. tostring(err),
                Icon = "error"
            })
        end
    end,
})

visCfgSec:AddButton({
    Title = "Delete Visual Config",
    Description = "Delete the selected visual profile from disk",
    Callback = function()
        local target = selectedVisConfig or currentVisConfigName
        local filePath = VISUAL_CONFIG_FOLDER .. "/" .. target .. ".json"
        if isfile(filePath) then
            delfile(filePath)
            local list = getVisualConfigs()
            visCfgDropdown:SetOptions(list)
            selectedVisConfig = list[1] or "default_visuals"
            visCfgDropdown:Set(selectedVisConfig)
            Window:Notify({
                Title = "Visual Config",
                Content = "Deleted profile: " .. target,
                Icon = "delete"
            })
        else
            Window:Notify({
                Title = "Visual Config",
                Content = "Profile file does not exist",
                Icon = "warning"
            })
        end
    end,
})

visCfgSec:AddButton({
    Title = "Set as Autoload Visuals",
    Description = "Auto-load this visual profile on script startup",
    Callback = function()
        local target = selectedVisConfig or currentVisConfigName
        writefile(AUTOLOAD_FILE, target)
        Window:Notify({
            Title = "Visual Autoload",
            Content = "Profile '" .. target .. "' set to autoload on startup!",
            Icon = "bolt"
        })
    end,
})

visCfgSec:AddButton({
    Title = "Clear Autoload Visuals",
    Description = "Remove auto-loading on script startup",
    Callback = function()
        if isfile(AUTOLOAD_FILE) then
            delfile(AUTOLOAD_FILE)
        end
        Window:Notify({
            Title = "Visual Autoload",
            Content = "Autoload cleared.",
            Icon = "trash"
        })
    end,
})

visCfgSec:AddButton({
    Title = "Reset to Visual Defaults",
    Description = "Reset all sizes, sliders, and effects to defaults",
    Callback = function()
        resetVisualDefaults()
        Window:Notify({
            Title = "Visual Config",
            Content = "Visual appearance reset to default values.",
            Icon = "refresh"
        })
    end,
})

visCfgSec:AddParagraph({
    Title = "Visual Config Storage",
    Content = "Saves UI scale, transparency, watermark scale & position, keybinds scale & position, background dimming, and snowfall effects independently from gameplay feature configs."
})

-- "HUD" subcategory: Data Display Toggles (Dual-Column Layout)
local hudDataSec_L = SettingsSubs["HUD"]:AddLeftSection("Player & Game Info")
hudDataSec_L:AddToggle({
    Title = "Show Avatar Headshot",
    Default = true,
    Flag = "HUD_ShowAvatar",
    Callback = function(val)
        wmState.Avatar = val
        refreshWatermark()
    end,
})
hudDataSec_L:AddToggle({
    Title = "Show Username & ID",
    Default = true,
    Flag = "HUD_ShowUserId",
    Callback = function(val)
        wmState.User = val
        refreshWatermark()
    end,
})
hudDataSec_L:AddToggle({
    Title = "Show Game Name",
    Default = true,
    Flag = "HUD_ShowGame",
    Callback = function(val)
        wmState.Game = val
        refreshWatermark()
    end,
})
hudDataSec_L:AddToggle({
    Title = "Show Executor Name",
    Default = true,
    Flag = "HUD_ShowExecutor",
    Callback = function(val)
        wmState.Executor = val
        refreshWatermark()
    end,
})

local hudDataSec_R = SettingsSubs["HUD"]:AddRightSection("Performance & Status")
hudDataSec_R:AddToggle({
    Title = "Show FPS",
    Default = true,
    Flag = "HUD_ShowFPS",
    Callback = function(val)
        wmState.FPS = val
        refreshWatermark()
    end,
})
hudDataSec_R:AddToggle({
    Title = "Show Ping",
    Default = true,
    Flag = "HUD_ShowPing",
    Callback = function(val)
        wmState.Ping = val
        refreshWatermark()
    end,
})
hudDataSec_R:AddToggle({
    Title = "Show Session Time",
    Default = true,
    Flag = "HUD_ShowTime",
    Callback = function(val)
        wmState.Time = val
        refreshWatermark()
    end,
})
hudDataSec_R:AddToggle({
    Title = "Watermark Master Toggle",
    Default = true,
    Flag = "HUD_MasterToggle",
    Callback = function(val)
        wmState.Master = val
        refreshWatermark()
    end,
})

-- Window Appearance and Watermark & Sizing Controls (Dual Column)
local hudScaleSec_L = SettingsSubs["HUD"]:AddLeftSection("Window Appearance")
hudScaleSec_L:AddSlider({
    Title = "UI Transparency",
    Min = 0,
    Max = 80,
    Step = 1,
    Default = 15,
    Suffix = "%",
    Flag = "Sett_UIPanelTransparency",
    Callback = function(percent)
        local t = percent / 100
        Window.Instance.BackgroundTransparency = t
        if Window._pages then
            Window._pages.BackgroundTransparency = math.clamp(t + 0.1, 0, 0.9)
        end
    end,
})
hudScaleSec_L:AddSlider({
    Title = "UI Scale",
    Min = 70,
    Max = 130,
    Step = 1,
    Default = 100,
    Suffix = "%",
    Flag = "Sett_UIPanelScale",
    Callback = function(percent)
        uiScale.Scale = percent / 100
    end,
})
hudScaleSec_L:AddToggle({
    Title = "Enable Custom Cursor",
    Default = true,
    Flag = "Sett_CustomCursorEnabled",
    Callback = function(val)
        cursorSettings.Enabled = val
        if updateCursorState then
            updateCursorState()
        end
    end,
})
hudScaleSec_L:AddSlider({
    Title = "Cursor Scale",
    Min = 70,
    Max = 200,
    Step = 1,
    Default = 100,
    Suffix = "%",
    Flag = "Sett_CursorScale",
    Callback = function(percent)
        cursorSettings.Scale = percent
        if cursorScale then
            cursorScale.Scale = percent / 100
        end
    end,
})

local hudScaleSec_R = SettingsSubs["HUD"]:AddRightSection("Watermark & Sizing")
hudScaleSec_R:AddSlider({
    Title = "Watermark Scale",
    Min = 70,
    Max = 130,
    Step = 1,
    Default = 100,
    Suffix = "%",
    Flag = "Sett_WatermarkScale",
    Callback = function(percent)
        wmScale.Scale = percent / 100
    end,
})
hudScaleSec_R:AddSlider({
    Title = "Keybinds Scale",
    Min = 70,
    Max = 130,
    Step = 1,
    Default = 100,
    Suffix = "%",
    Flag = "Sett_KeybindScale",
    Callback = function(percent)
        if kbScale then
            kbScale.Scale = percent / 100
        end
    end,
})
hudScaleSec_R:AddParagraph({
    Title = "Sizing Information",
    Content = "Independently scale the main UI window, watermark capsule, and keybinds list from 70% to 130%."
})

-- Background Dimming & Snowfall Controls (Dual Column)
local bgDimSec_L = SettingsSubs["HUD"]:AddLeftSection("Background Dimming")
bgDimSec_L:AddToggle({
    Title = "Enable Background Dim",
    Default = true,
    Flag = "Sett_BackdropEnabled",
    Callback = function(val)
        backdropSettings.Enabled = val
        local isOpen = Window.Visible and not Window.Minimized
        if isOpen then
            if val then
                backdrop.Visible = true
                TweenService:Create(backdrop, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    BackgroundTransparency = backdropSettings.Transparency
                }):Play()
            else
                backdrop.Visible = false
            end
        end
    end,
})
bgDimSec_L:AddSlider({
    Title = "Dim Transparency",
    Min = 0,
    Max = 95,
    Step = 1,
    Default = 55,
    Suffix = "%",
    Flag = "Sett_BackdropTransparency",
    Callback = function(percent)
        local t = percent / 100
        backdropSettings.Transparency = t
        local isOpen = Window.Visible and not Window.Minimized
        if isOpen and backdropSettings.Enabled then
            backdrop.BackgroundTransparency = t
        end
    end,
})
bgDimSec_L:AddParagraph({
    Title = "Dimming Info",
    Content = "Toggles background dark overlay when opening UI and adjusts its transparency level."
})

local snowSec_R = SettingsSubs["HUD"]:AddRightSection("Snowfall Effects")
snowSec_R:AddToggle({
    Title = "Enable Snowfall",
    Default = true,
    Flag = "Sett_SnowEnabled",
    Callback = function(val)
        snowSettings.Enabled = val
        local isOpen = Window.Visible and not Window.Minimized
        snowContainer.Visible = isOpen and val
    end,
})
snowSec_R:AddSlider({
    Title = "Snowfall Speed",
    Min = 25,
    Max = 250,
    Step = 1,
    Default = 100,
    Suffix = "%",
    Flag = "Sett_SnowSpeed",
    Callback = function(percent)
        snowSettings.SpeedMultiplier = percent / 100
    end,
})
snowSec_R:AddSlider({
    Title = "Snowflake Size",
    Min = 2,
    Max = 14,
    Step = 1,
    Default = 5,
    Suffix = "px",
    Flag = "Sett_SnowSize",
    Callback = function(size)
        updateSnowSize(size)
    end,
})
snowSec_R:AddSlider({
    Title = "Snowflake Count",
    Min = 10,
    Max = 120,
    Step = 1,
    Default = 45,
    Suffix = "",
    Flag = "Sett_SnowCount",
    Callback = function(count)
        updateSnowCount(count)
    end,
})
snowSec_R:AddParagraph({
    Title = "Snowfall Info",
    Content = "Controls background falling snow particles: toggle effect, falling speed, particle size, and density."
})

-- ==================== 9. Interactive Settings Search System ====================
if searchInputBox and searchDropdown then
    local searchableSettings = {
        { name = "Show Avatar Headshot", path = "Settings > HUD", subtab = "HUD" },
        { name = "Show Username & ID", path = "Settings > HUD", subtab = "HUD" },
        { name = "Show Game Name", path = "Settings > HUD", subtab = "HUD" },
        { name = "Show Executor Name", path = "Settings > HUD", subtab = "HUD" },
        { name = "Show FPS", path = "Settings > HUD", subtab = "HUD" },
        { name = "Show Ping", path = "Settings > HUD", subtab = "HUD" },
        { name = "Show Session Time", path = "Settings > HUD", subtab = "HUD" },
        { name = "Watermark Master Toggle", path = "Settings > HUD", subtab = "HUD" },
        { name = "UI Transparency", path = "Settings > HUD > Window Appearance", subtab = "HUD" },
        { name = "UI Scale", path = "Settings > HUD > Window Appearance", subtab = "HUD" },
        { name = "Enable Custom Cursor", path = "Settings > HUD > Window Appearance", subtab = "HUD" },
        { name = "Cursor Scale", path = "Settings > HUD > Window Appearance", subtab = "HUD" },
        { name = "Watermark Scale", path = "Settings > HUD > Watermark & Sizing", subtab = "HUD" },
        { name = "Keybinds Scale", path = "Settings > HUD > Watermark & Sizing", subtab = "HUD" },
        { name = "Enable Background Dim", path = "Settings > HUD > Background Dimming", subtab = "HUD" },
        { name = "Dim Transparency", path = "Settings > HUD > Background Dimming", subtab = "HUD" },
        { name = "Enable Snowfall", path = "Settings > HUD > Snowfall Effects", subtab = "HUD" },
        { name = "Snowfall Speed", path = "Settings > HUD > Snowfall Effects", subtab = "HUD" },
        { name = "Snowflake Size", path = "Settings > HUD > Snowfall Effects", subtab = "HUD" },
        { name = "Snowflake Count", path = "Settings > HUD > Snowfall Effects", subtab = "HUD" },
        { name = "Appearance / Dark Mode", path = "Settings > Themes", subtab = "Themes" },
        { name = "Theme Editor / Colors", path = "Settings > Themes", subtab = "Themes" },
        { name = "Background Image", path = "Settings > Themes", subtab = "Themes" },
        { name = "Configuration Manager", path = "Settings > Config", subtab = "Config" },
        { name = "Visual Configuration", path = "Settings > Config", subtab = "Config" },
        { name = "Save Visual Config", path = "Settings > Config", subtab = "Config" },
        { name = "Load Visual Config", path = "Settings > Config", subtab = "Config" },
        { name = "Delete Visual Config", path = "Settings > Config", subtab = "Config" },
        { name = "Set as Autoload Visuals", path = "Settings > Config", subtab = "Config" },
        { name = "Clear Autoload Visuals", path = "Settings > Config", subtab = "Config" },
        { name = "Reset to Visual Defaults", path = "Settings > Config", subtab = "Config" },
    }

    local function performJump(item)
        local nav = Window.Instance.Body.Navigation
        local settBtn = nav:FindFirstChild("Settings")
        if settBtn then
            for _, conn in ipairs(getconnections(settBtn.Activated)) do
                conn:Fire()
            end
        else
            Window:SelectTab(SettingsTab)
        end
        task.wait(0.12)
        if item.subtab then
            local subBtn = Window.Instance:FindFirstChild("SubBtn_" .. item.subtab, true)
            if subBtn then
                for _, conn in ipairs(getconnections(subBtn.Activated)) do
                    conn:Fire()
                end
            end
        end
        task.wait(0.12)
        local pages = Window.Instance.Body.Pages
        local settingsPage = pages:FindFirstChild("Settings") or SettingsTab.Instance
        local targetRow = nil
        if settingsPage then
            for _, d in ipairs(settingsPage:GetDescendants()) do
                if (d:IsA("TextLabel") or d:IsA("TextBox")) and string.find(d.Text:lower(), item.name:lower(), 1, true) then
                    local p = d.Parent
                    while p and p ~= settingsPage do
                        if p.ClassName == "Frame" and p.Parent and (p.Parent.Name == "LeftCol" or p.Parent.Name == "RightCol" or p.Parent:IsA("ScrollingFrame")) then
                            targetRow = p
                            break
                        end
                        p = p.Parent
                    end
                    if targetRow then break end
                end
            end
            if targetRow and settingsPage:IsA("ScrollingFrame") then
                local relY = targetRow.AbsolutePosition.Y - settingsPage.AbsolutePosition.Y + settingsPage.CanvasPosition.Y
                settingsPage.CanvasPosition = Vector2.new(0, math.max(0, relY - 40))

                local highlight = Instance.new("UIStroke")
                highlight.Name = "LY_SearchHighlight"
                highlight.Color = Color3.fromRGB(180, 160, 255)
                highlight.Thickness = 2
                highlight.Transparency = 0
                highlight.Parent = targetRow

                TweenService:Create(highlight, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    Transparency = 1,
                    Thickness = 4
                }):Play()
                task.delay(1.3, function() pcall(function() highlight:Destroy() end) end)
            end
        end
        searchDropdown.Visible = false
    end

    local clearBtn = searchInputBox.Parent:FindFirstChild("ClearBtn")

    searchInputBox:GetPropertyChangedSignal("Text"):Connect(function()
        local query = searchInputBox.Text:lower():match("^%s*(.-)%s*$")
        if clearBtn then
            clearBtn.Visible = (searchInputBox.Text ~= "")
        end
        if not query or query == "" then
            searchDropdown.Visible = false
            return
        end

        local matches = {}
        for _, item in ipairs(searchableSettings) do
            if string.find(item.name:lower(), query, 1, true) or string.find(item.path:lower(), query, 1, true) then
                table.insert(matches, item)
                if #matches >= 6 then break end
            end
        end

        for _, child in ipairs(searchDropdown:GetChildren()) do
            if child:IsA("TextButton") or child:IsA("Frame") then
                child:Destroy()
            end
        end

        if #matches == 0 then
            local emptyLabel = Instance.new("TextLabel")
            emptyLabel.Size = UDim2.new(1, 0, 0, 32)
            emptyLabel.BackgroundTransparency = 1
            emptyLabel.Text = "No matching settings found"
            emptyLabel.TextColor3 = Color3.fromRGB(140, 135, 155)
            emptyLabel.TextSize = 12
            emptyLabel.Font = Enum.Font.Gotham
            emptyLabel.ZIndex = 61
            emptyLabel.Parent = searchDropdown
            searchDropdown.Visible = true
            return
        end

        for i, item in ipairs(matches) do
            local itemBtn = Instance.new("TextButton")
            itemBtn.Name = "Res_" .. i
            itemBtn.Size = UDim2.new(1, 0, 0, 36)
            itemBtn.BackgroundColor3 = Color3.fromRGB(34, 31, 42)
            itemBtn.AutoButtonColor = true
            itemBtn.Text = ""
            itemBtn.ZIndex = 61
            itemBtn.Parent = searchDropdown

            local ic = Instance.new("UICorner")
            ic.CornerRadius = UDim.new(0, 6)
            ic.Parent = itemBtn

            local titleLbl = Instance.new("TextLabel")
            titleLbl.BackgroundTransparency = 1
            titleLbl.Size = UDim2.new(1, -12, 0, 18)
            titleLbl.Position = UDim2.new(0, 8, 0, 2)
            titleLbl.Text = item.name
            titleLbl.TextColor3 = Color3.fromRGB(240, 240, 255)
            titleLbl.TextSize = 13
            titleLbl.Font = Enum.Font.GothamMedium
            titleLbl.TextXAlignment = Enum.TextXAlignment.Left
            titleLbl.ZIndex = 62
            titleLbl.Parent = itemBtn

            local pathLbl = Instance.new("TextLabel")
            pathLbl.BackgroundTransparency = 1
            pathLbl.Size = UDim2.new(1, -12, 0, 14)
            pathLbl.Position = UDim2.new(0, 8, 0, 19)
            pathLbl.Text = item.path
            pathLbl.TextColor3 = Color3.fromRGB(150, 145, 165)
            pathLbl.TextSize = 11
            pathLbl.Font = Enum.Font.Gotham
            pathLbl.TextXAlignment = Enum.TextXAlignment.Left
            pathLbl.ZIndex = 62
            pathLbl.Parent = itemBtn

            itemBtn.Activated:Connect(function()
                task.spawn(performJump, item)
            end)
        end
        searchDropdown.Visible = true
    end)
end

Window:LoadAutoloadConfig()

-- Autoload Visual Config if configured
pcall(function()
    if isfile(AUTOLOAD_FILE) then
        local autoName = readfile(AUTOLOAD_FILE):match("^%s*(.-)%s*$")
        if autoName and autoName ~= "" and isfile(VISUAL_CONFIG_FOLDER .. "/" .. autoName .. ".json") then
            loadVisualConfig(autoName)
            print("[LY Hub] Autoloaded visual config:", autoName)
        end
    end
end)

Window:Notify({ Title = "LY Hub", Content = "Interface loaded successfully! Press RightShift to toggle.", Icon = "badge" })
