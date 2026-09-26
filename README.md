# MD3 — Roblox Luau 版 Material Design 3 UI 庫

一個從零打造的 Material Design 3（M3）UI 庫，純 Luau 撰寫、不依賴任何外部套件或圖片素材。**主要給 Roblox 腳本執行器（executor）使用**：一行 `loadstring` 載入後，就能用 `CreateWindow → Tab → Section → AddToggle / AddSlider …` 的方式快速組出 M3 風格的腳本介面；底層的 16 個 M3 元件也能單獨使用，或照舊用 [Rojo](https://rojo.space/) 同步進 Roblox Studio。

## Executor 快速開始

```lua
local MD3 = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/engnyg/Material-Design-3-Roblox-lua-ui/main/dist/MaterialDesign3.luau"
))()

local Window = MD3:CreateWindow({
    Title = "My Hub",
    Subtitle = "v1.0",
    Icon = "widgets",                    -- Material 圖標名稱，或圖片（網址／rbxassetid）
    Logo = "https://raw.githubusercontent.com/<你>/<repo>/main/logo.png", -- 彩色 Logo 圖片（不套色，可省略）
    Mode = "Dark",                       -- "Light" | "Dark"
    ThemeColor = Color3.fromHex("#6750A4"), -- 主題色，整套配色由它生成
    Preset = nil,                        -- 內建主題，例如 "NeverLose"（見下方主題編輯器）
    IconColor = nil,                     -- 所有圖標的顏色（Color3，可省略）
    TextColor = nil,                     -- 所有文字的顏色（Color3，可省略；說明文字會自動用淡一點的同色）
    ToggleKey = Enum.KeyCode.RightShift, -- 顯示／隱藏視窗
    ConfigFolder = "MyHub",              -- 設定檔存放資料夾（executor workspace）
    IconStyle = "Outlined",              -- 圖標樣式："Outlined"（預設）| "Filled" | "Round" | "Sharp"
    LoadingScreen = true,                -- 啟動時的載入動畫；false 關閉
    Background = nil,                    -- 自訂背景圖片：網址／rbxassetid／素材 ID（見下方）
    BackgroundTransparency = 0.4,        -- 背景圖片透明度（0 = 圖片完全不透明）
    BackgroundBlur = 0,                  -- 背景圖片模糊度，0-24 px
    Silent = false,                      -- true：安靜啟動（見下方）
    KeybindNotify = true,                -- 按自己設定的快捷鍵時跳通知；false 全部關閉
})

local Main = Window:AddTab({ Title = "Main", Icon = "home" })
local Combat = Main:AddSection("Combat")

Combat:AddToggle({
    Title = "Auto farm",
    Description = "自動打怪",
    Default = false,
    Flag = "AutoFarm",                   -- 有 Flag 的元件會被存進設定檔
    Callback = function(on) print("AutoFarm:", on) end,
})

Combat:AddSlider({ Title = "WalkSpeed", Min = 16, Max = 200, Default = 16, Step = 1, Flag = "WS",
    Callback = function(v) game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = v end })

Window:AddSettingsTab()      -- 內建設定頁：深色模式、主題色、圖標樣式、主題編輯器、切換鍵、設定檔存讀
Window:LoadAutoloadConfig()  -- 放在腳本最後，載入「自動載入」設定檔

Window:Notify({ Title = "Loaded", Content = "按 RightShift 隱藏／顯示", Icon = "check_circle" })
```

完整示範（每種元件、對話框、通知、設定頁、hub_v3 次分類與特效）見 [`examples/executor.lua`](examples/executor.lua)。

### Hub v3 視覺與進階架構

本版本完整整合了 `hub_v3.luau` 的所有現代介面架構與視覺特效，全部透過原生配置開啟：

- **頂部滑動導航欄**：分頁按鈕居中橫向排列，當切換 Tab 時自動以滑動膠囊（`NavSlideIndicator`）平滑過渡。
- **次級分類與左右雙欄佈局 (`AddSubTabs`)**：
  ```lua
  local MainSubs = MainTab:AddSubTabs({ "Overview", "Statistics", "Info" })
  local LeftSec = MainSubs.Overview:AddLeftSection("General")
  local RightSec = MainSubs.Overview:AddRightSection("System")
  ```
  自動生成左欄（LeftCol）、右欄（RightCol）與垂直分隔線（DividerLine）。
- **即時設定搜尋框與懸浮結果跳轉 (`Search = true`)**：
  頂部左側提供即時搜尋輸入框。所有加入的元件（Toggle、Slider、Dropdown 等）會**自動註冊搜尋索引與路徑**，點擊搜尋結果自動切換到目標分頁／次分類並跳轉滾動、附帶紫光脈衝動畫（Highlight）。
- **指數平滑拖拽跟隨 (`Draggable`)**：視窗採用平滑阻尼跟隨，且具備螢幕邊界自動夾緊（Clamp）防脫出機制。
- **全螢幕柔和暗化遮罩 (`Backdrop = true`)**：UI 顯示與切換時平滑淡入／淡出背景遮罩；可用 `Window:SetBackdrop(enabled, transparency)` 動態開關。
- **落雪粒子系統 (`Snowfall = true`)**：UI 背後呈現左右物理擺動的飄雪特效；可用 `Window:SetSnowfall(enabled, count, speed, size)` 動態調節。
- **客製化主題彩色游標 (`CustomCursor = true`)**：UI 開啟時自動隱藏原生游標並顯示隨主題色 Tint 的光標；可用 `Window:SetCustomCursor(enabled, scale)` 動態控制。
- **即時縮放與透明度**：支援 `Window:SetScale(scale)`、`Window:SetTransparency(transparency)`。
- **增強型 Watermark HUD**：
  ```lua
  local Watermark = Window:AddWatermark({ Title = "My Hub", Position = "TopLeft" })
  Watermark:AddAvatar()    -- 玩家頭像圓像
  Watermark:AddPlayer()    -- 玩家使用者名稱
  Watermark:AddGame()      -- 遊戲名稱
  Watermark:AddExecutor()  -- 執行器名稱
  Watermark:AddFPS()       -- 即時 FPS
  Watermark:AddPing()      -- 即時 Ping
  Watermark:AddClock()     -- 即時時鐘
  ```

### 視窗功能

- **可拖曳**的 M3 視窗：頂部 App Bar（標題／副標題／縮小／關閉）、左側 Navigation Drawer 分頁、右側可捲動內容區。
- **載入動畫**：腳本啟動時先顯示一張 M3 卡片（圖標、標題、副標題、進度條、狀態文字），等 Material 圖標圖片下載好（最多等 5 秒）、至少顯示 1.2 秒後淡出，視窗再放大出現。不會卡住腳本：`CreateWindow` 立刻回傳，你照常建立分頁，載入期間按切換鍵只會記住要不要顯示。
  - **開關**：腳本裡 `LoadingScreen = false` 直接關掉（設定頁也不會出現開關）；玩家可以在設定頁 Interface 區塊用「Loading animation」開關，存在 `ConfigFolder/loading.txt`，**下次執行**生效（程式裡用 `Window:SetLoadingScreenEnabled(bool)`／`GetLoadingScreenEnabled()`）。
  - **自訂**：`LoadingScreen = { Title = "My Hub", Subtitle = "Loading...", Icon = "widgets", Duration = 2 }`（`Duration` 是最少顯示秒數）。
  - `Window.Loaded` 在視窗出現後觸發一次、`Window.IsLoaded` 表示是否載入完成（`if not Window.IsLoaded then Window.Loaded:Wait() end`）；`Window:SkipLoading()` 立刻結束載入動畫。
- **安靜啟動（`Silent = true`）**：啟動時什麼都不跳出來——不播載入動畫、視窗一開始先藏著（按切換鍵，或觸控裝置上的浮動按鈕打開）、`LoadAutoloadConfig()` 自動載入設定檔時照樣套用但不跳「Config loaded」通知、快捷鍵也不跳通知。其他功能照常運作；你自己呼叫的 `Window:Notify(...)` 還是會顯示，HUD 也照常顯示（不想要就別建立，或用 `SetHUDVisible(false)`）。`Window.Silent` 可以讀取目前是否為安靜模式。
- **可調大小**：拖右下角的把手縮放視窗（最小 420×280），放開後自動記住，下次執行會還原（存在 `ConfigFolder/window.json`；`RememberSize = false` 可關閉）。程式裡用 `Window:SetSize(w, h)`／`GetSize()`／`ResetSize()`；設定頁也有「Reset window size」。
- **切換鍵**（預設 RightShift）隱藏／顯示（不跳通知）；關閉鈕會跳出 M3 對話框讓你選「隱藏」或「卸載（Unload）」。
- **快捷鍵通知**：按下自己用 `AddKeybind` 設定的快捷鍵時，右下角跳一個 2 秒的小通知：Toggle 模式「Fly — Enabled (F)」／「Disabled (F)」、Press 模式「Dash — Activated (Q)」；Hold 模式預設不跳。同一個快捷鍵連按時舊的通知會先關掉。每個快捷鍵可用 `Notify = true/false`（或 `:SetNotify()`）單獨設定；整個視窗用 `KeybindNotify = false`（或 `Window:SetKeybindNotify(false)`）全部關掉；安靜模式不跳。UI 切換鍵（含設定頁的「Toggle UI」）永遠不跳。
- **手機支援**：觸控裝置會自動出現可拖曳的浮動按鈕來開關視窗；螢幕太小時視窗會自動等比縮小（`UIScale`）。
- **防偵測／相容性**：ScreenGui 優先放進 `gethui()`，其次 `CoreGui`，最後才是 `PlayerGui`；有 `syn.protect_gui` / `protectgui` 會自動套用；ScreenGui 名稱隨機。
- **重複執行不會疊視窗**：同一個 `Title`（或 `Id`）的視窗再次建立時，舊的會先被卸載（透過 `getgenv()` 記錄）。
- **真正的 Material 圖標**：跟 NeverLose 載入圖片的方式一樣（`HttpGet` → `writefile` → `getcustomasset`），把 Google 官方 Material Icons 預先畫成的圖片（sprite sheet，每種樣式一張 PNG）下載並載入，不需要上傳任何資產。預設是 M3 風格的**線條版（Outlined）**，可用 `IconStyle` 或設定頁換成 `Filled`（實心）、`Round`（圓角）或 `Sharp`（直角）；載入失敗或 executor 不支援時改用 Roblox 客戶端內建的 BuilderIcons 字型（免下載），再不行才退回簡單符號，不會出現方塊字或中文字。
- **外部圖片**：所有 `Icon` / `Logo` / 通知的 `Image` 都可以直接填網址，會自動下載並透過 `getcustomasset` 載入（見下方「載入外部圖片」）。
- **設定檔**：`Window:SaveConfig(name)` / `LoadConfig(name)` / `ListConfigs()` / `DeleteConfig(name)` / `SetAutoLoad(name)`，存成 JSON（Color3、KeyCode 會自動序列化）。
- **即時換色**：`Window.Theme:SetMode("Light")`、`Window.Theme:SetThemeColor(color)`、`Window.Theme:SetIconColor(color)`、`Window.Theme:SetTextColor(color)`，整個視窗立即重新上色。設定頁的 Appearance 區塊也有 **Theme color／Icon color／Text color** 三個選色器可以直接調（「Reset icon & text colors」還原）。
- **主題編輯器**：設定頁內建，可以單獨改每個顏色（含圖標顏色），見下方「主題編輯器」。
- **Callback 錯誤不會弄壞 UI**：所有 Callback 都在 `xpcall` 中執行，錯誤只會 `warn` 出來。
- `Window.OnUnload:Connect(fn)`：UI 被卸載時停止你的迴圈／連線。

### 元件（Tab 與 Section 都能呼叫）

| 方法 | 主要參數 | 值（`.Value` / Callback 參數） |
| --- | --- | --- |
| `AddButton` | `Title`、`Description`、`Icon`、`IconColor`、`Callback` | —（`:Fire()` 手動觸發） |
| `AddToggle` | `Default`、`Flag`、`Callback` | `boolean` |
| `AddSlider` | `Min`、`Max`、`Step`、`Default`、`Suffix` | `number`（右側數值可直接輸入） |
| `AddInput` | `Placeholder`、`Default`、`Numeric`、`Finished`、`ClearOnSubmit` | `string` |
| `AddDropdown` | `Options`、`Default`、`Multi`、`Searchable` | 單選 `string`／多選 `{string}`；`:SetOptions(list)` 更新選項 |
| `AddKeybind` | `Default`、`Mode`（`Press`/`Toggle`/`Hold`）、`Callback`、`ChangedCallback`、`Notify`（按下時跳通知，Hold 預設關） | `Enum.KeyCode`（點一下再按鍵；Esc 取消、Backspace 清除） |
| `AddColorPicker` | `Default`、`Transparency`（給了就多一條透明度條）、`Callback` | `Color3`（點標題列展開／收合，有動畫；SV 方塊 + 色相條 + HEX 輸入；`:SetExpanded(bool)`）；有透明度時 Callback 收到 `(color, transparency)`、`.Transparency` 為目前值、`:SetTransparency(t)` |
| `AddLabel` | 文字或 `{ Text, Color }` | `:Set(text)` |
| `AddParagraph` | `Title`、`Content` | `:Set({ Title, Content })` |
| `AddDivider` | — | — |

所有元件共通：`:Set(value, silent?)`、`:Get()`、`:OnChanged(fn)`、`:SetTitle()`、`:SetDescription()`、`:SetVisible()`、`:Destroy()`；有 `Flag` 的元件可從 `Window.Flags[flag]` 取得。為了方便移植其他 UI 庫的腳本，`AddX` 也都有 `CreateX` 別名（`CreateToggle`、`CreateSlider`…），`AddTextbox` / `AddBind` 也可用。

**從另一個腳本控制已經開著的視窗**：`Window` 只是主腳本裡的變數，另一個腳本拿不到（會出現 `attempt to index nil with 'SetBackground'`）。用標題取回它：

```lua
local MD3 = loadstring(game:HttpGet("https://raw.githubusercontent.com/engnyg/Material-Design-3-Roblox-lua-ui/main/dist/MaterialDesign3.luau"))()
local Window = MD3:GetWindow("My Hub")   -- CreateWindow 的 Title（或 Id）；沒開著就是 nil
if Window then
    Window:SetBackground("https://.../bg.png")
end
```

`Window` 其他方法：`AddTab`、`SelectTab(tab | index | title)`、`AddThemeEditor(tab?)`、`SetIconStyle(style)`、`Notify{ Title, Content, Icon, Duration }`、`Dialog{ Title, Content, Buttons = {{ Title, Variant, Callback }} }`、`AddWatermark`／`AddKeybindList`／`AddIndicator`／`SetHUDVisible`／`SetHUDTransparency`（見下方 HUD）、`SetBackground`／`SetBackgroundTransparency`／`GetBackground`、`SkipLoading`、`SetLoadingScreenEnabled`／`GetLoadingScreenEnabled`、`SetVisible`、`Toggle`、`Minimize`、`SetToggleKey`、`SetTitle`、`SetSubtitle`、`Destroy`（別名 `Unload`）。

### HUD（浮水印、快捷鍵列表、狀態指示）

HUD 是畫在螢幕上的常駐資訊，**視窗隱藏或縮小時照樣顯示**，跟著視窗的主題配色，每一塊都能用滑鼠／手指拖到想要的位置，視窗卸載時一起清掉。手機等小螢幕會自動等比縮小。

```lua
-- 浮水印：標題（預設用視窗的標題和圖標）+ FPS／Ping／時間
local Watermark = Window:AddWatermark({
    Title = "My Hub",          -- 省略 = 視窗標題；false = 不顯示標題
    Position = "TopLeft",      -- 位置預設名稱或 UDim2（見下方）
    FPS = true,                -- 每 0.5 秒更新
    Ping = true,               -- 毫秒，跟 Roblox 開發者主控台的數值一樣
    Clock = true,              -- 本地時間；也可以給 os.date 格式，例如 Clock = "%H:%M"
})

-- 自訂區塊（NeverLose 寫法 AddBlock(圖標, 文字) 也可以）
local Status = Watermark:AddBlock({ Icon = "bolt", Text = "Idle", Callback = function() print("clicked") end })
Status:SetText("Running")
Status:SetIconColor("Tertiary")   -- 主題色角色或 Color3
Status:OnClick(function() Window:Toggle() end) -- 點一下（沒拖動）才觸發；別名 :Input(fn)

-- 快捷鍵列表：自動列出 AddKeybind 建立的快捷鍵
local Binds = Window:AddKeybindList({
    Title = "Keybinds",
    Position = "Left",
    ShowAll = false,           -- false：只列「開著」的 Toggle 快捷鍵和「按住中」的 Hold 快捷鍵，沒有時自動隱藏
                               -- true：列出所有已綁定的快捷鍵，開著的會亮起來
})

-- 狀態指示：左下角的小膠囊，全部疊在一起
local Auto = Window:AddIndicator({ Text = "AUTO", Icon = "bolt", Color = "Primary" })
Auto:SetText("OFF")
Auto:SetColor("Error")           -- 主題色角色（Primary、Tertiary、Error、OnSurface…）或 Color3
Auto:SetVisible(false)           -- 別名 :SetRender(false)

Window:SetHUDVisible(false)      -- 一次隱藏／顯示所有 HUD

-- 透明度：跟視窗分開，0 = 不透明、1 = 全透明
Window:SetHUDTransparency(0.4, 0)   -- (背景, 文字與圖標)；nil = 那部分不變
Watermark:SetTransparency(0.8)      -- 只調這一塊（浮水印、快捷鍵列表、單一狀態指示都有）
Auto:SetTransparency(nil, 0.5)      -- 背景跟著整體設定，只改文字
```

- **位置**：`Position` 可填 `"TopLeft"`、`"Top"`、`"TopRight"`、`"Left"`、`"Right"`、`"BottomLeft"`、`"Bottom"`、`"BottomRight"`，或 `UDim2`（左上角座標）。預設：浮水印左上、快捷鍵列表左側中間、狀態指示左下。所有狀態指示共用一個堆疊，位置以第一個的 `Position` 為準。
- **快捷鍵列表**會即時跟著變化：切換開關、按住／放開、重新綁定、刪除快捷鍵都會馬上更新。Press 模式的快捷鍵沒有「開著」的狀態，只在 `ShowAll = true` 時出現。沒綁按鍵的快捷鍵不會列出。Toggle 模式可以用 `keybind:SetState(true)` 從程式同步狀態（不觸發 Callback）。
- **透明度跟視窗分開**：HUD 有自己的背景透明度（底色、外框、分隔線、按鍵標籤）和文字透明度（文字、圖標），主題編輯器把視窗的 Rows、Text 等調成半透明**不會**影響 HUD，反過來也一樣。`Window:SetHUDTransparency(背景, 文字)` 調整整個 HUD、`GetHUDTransparency()` 讀取；每一塊還能用 `:SetTransparency(背景, 文字)` 單獨覆寫（給 `nil` 就回到整體設定），建立時也能給 `BackgroundTransparency`／`TextTransparency`。整體 HUD 透明度存在主題裡（`HUDBackground`／`HUDText` 兩個顏色角色的透明度），會跟著設定檔、`Copy theme` 一起存。HUD 的顏色預設跟視窗一樣，想分開也可以：`Window.Theme:SetOverride("HUDBackground", Color3.fromRGB(20, 20, 28))`、`"HUDText"`、`"HUDOutline"`。
- **設定頁**：先建立 HUD 再呼叫 `Window:AddSettingsTab()`，設定頁會多一個 **HUD** 區塊：「Show HUD」開關（Flag `MD3_ShowHUD`，會存進設定檔）、「Background transparency」和「Text transparency」兩個滑桿（0–100%）。
- 物件方法：浮水印 `:AddBlock`、`:AddFPS`、`:AddPing`、`:AddClock(format?)`、`:SetVisible`、`:SetTransparency`、`:Destroy`，`.TitleBlock` 是標題區塊；區塊 `:SetText`、`:GetText`、`:SetIcon`、`:SetIconColor`、`:SetTextColor`、`:SetVisible`、`:OnClick`、`:Destroy`；快捷鍵列表 `:SetVisible`、`:SetShowAll`、`:SetTitle`、`:SetTransparency`、`:Destroy`、`.Count`（目前列出幾個）；狀態指示 `:SetText`、`:GetText`、`:SetIcon`、`:SetColor`、`:SetVisible`、`:SetTransparency`、`:Destroy`。

### 載入外部圖片（`MD3.Assets`）

做法參考 [NeverLose](https://github.com/engnyg/NeverLose)：`game:HttpGet` 下載圖片 → `writefile` 存進 executor workspace（`MD3/assets/`）→ `getcustomasset` 轉成可以放進 `ImageLabel.Image` 的內容 ID。下載過的檔案會留在磁碟上，之後直接讀取；同一次執行內也會快取。

```lua
-- 任何 Image 都能用
imageLabel.Image = MD3.Assets.Resolve("https://raw.githubusercontent.com/<你>/<repo>/main/assets/logo.png")

-- MD3 的 Icon / Logo 參數都會自動經過 Assets.Resolve
local Window = MD3:CreateWindow({ Title = "My Hub", Logo = "https://.../logo.png" })
Window:AddTab({ Title = "Combat", Icon = "https://.../sword.png" }) -- 圖片分頁圖示（會套主題色，圖片必須是白色）
Window:Notify({ Title = "Hi", Image = "https://.../avatar.png" })      -- 彩色圖片（不套色）
MD3.Button.new({ Text = "Go", Icon = "https://.../go.png" })

MD3.Assets.Preload({ "https://.../a.png", "https://.../b.png" }) -- 腳本開頭先背景下載
```

> **`Icon` 圖片要用白色的。** `Icon` 會用 `ImageColor3` 套上主題色，而 `ImageColor3` 是「相乘」：白色 × 主題色 = 主題色，但黑色 × 任何顏色還是黑色。Google 官方 repo 的 PNG 圖標都是黑色的，直接拿來當 `Icon` 會一直是黑的——請改用白色版本（例如 [`assets/examples/extension.png`](assets/examples/extension.png)），或直接用 Material 圖標名稱（`Icon = "home"`）。彩色圖片請放 `Logo`／通知的 `Image`，這兩個不套色。

`Assets.Resolve` 接受：網址（`http(s)://`）、`rbxassetid://…`／`rbxasset://…`／`rbxthumb://…`、純數字 ID（`123456` → `rbxassetid://123456`）、或 workspace 內已有的檔案路徑（`"MyHub/icon.png"`）。下載失敗（例如拿到 GitHub 的 404 HTML 頁）或 executor 不支援 `getcustomasset` 時回傳 `""`（不顯示圖片），不會丟錯。GitHub 圖片請用 `raw.githubusercontent.com/...` 或 `github.com/.../blob/main/xxx.png?raw=true` 這種直接下載的網址。

### 自訂背景

視窗可以放一張背景圖片或一段**影片**，鋪滿整個視窗（圓角跟視窗一樣、自動裁切填滿），在所有內容後面：

```lua
local Window = MD3:CreateWindow({
    Title = "My Hub",
    Background = "https://raw.githubusercontent.com/<你>/<repo>/main/bg.png", -- 或 "rbxassetid://123"、123
    BackgroundTransparency = 0.4,  -- 0 = 圖片完全不透明；越大越透出視窗原本的底色
})

Window:SetBackground("rbxassetid://123456", 0.3) -- 換圖（第二個參數可省略）；失敗會保留原本的背景並回傳 false, 原因
Window:SetBackground("https://raw.githubusercontent.com/engnyg/Material-Design-3-Roblox-lua-ui/main/assets/background/lystore.webm") -- 影片背景
Window:SetBackgroundTransparency(0.6)
Window:SetBackgroundBlur(8)                      -- 模糊度 0-24 px（0 = 清晰）；Window:GetBackgroundBlur()
Window:SetBackground(nil)                        -- 移除
local source, transparency, kind = Window:GetBackground() -- kind："Image" | "Video"
```

- **影片背景**：`.webm` 網址或檔案會自動當影片播放（循環、靜音），視窗隱藏時暫停、打開時繼續；透明度、設定頁、設定檔跟圖片共用。Roblox 上傳的影片素材 ID 看不出是影片，要指定：`Window:SetBackground("rbxassetid://123", nil, "Video")`（`CreateWindow` 用 `BackgroundKind = "Video"`）。影片能不能播要看 executor 支不支援用 `getcustomasset` 載入 `.webm`：檔案下載成功但 Roblox 播不了時（例如 Delta Mobile 會在主控台印出 `Failed to load rbxasset://…webm`），會自動拿掉影片背景並跳通知，這時請改用 PNG／JPG 圖片背景。
- **模糊**：`BackgroundBlur`／`SetBackgroundBlur(px)`／設定頁的「Image blur」滑桿（0–24 px，存進設定檔 `MD3_BackgroundBlur`）。Roblox 的 UI 沒有內建模糊（`BlurEffect` 只模糊 3D 畫面），所以這裡是把圖片畫成 13 份、往四周錯開後平均疊起來做出柔和的模糊；0 的時候只有原本那一張圖，不增加負擔。只作用在圖片，**影片背景不會模糊**（每一份都要各自解碼影片，太吃效能）。
- **GIF 不支援**：Roblox 不能播、也不能顯示 GIF。想要動態背景，把 GIF 轉成 WebM（例如 `ffmpeg -i bg.gif -c:v libvpx-vp9 -b:v 0 -crf 32 -an bg.webm`，或線上轉檔工具）；靜態背景用 PNG／JPG。WebP 也不支援。
- **格式會檢查**：下載的檔案會看檔頭判斷是 PNG／JPG／WebM；GIF、WebP、網頁（例如 GitHub 的 404 頁面）會被擋下並說明原因。之前版本已經存進 workspace 的 GIF 也會被找出來刪掉。
- **失敗一定會通知**：`CreateWindow` 的 `Background`、設定頁的輸入框、設定檔載入，失敗時都會跳「Background unavailable」通知並寫明原因（安靜模式只在主控台 `warn`）。

- 圖片來源跟其他 `Icon`／`Logo` 一樣走 `MD3.Assets`：網址會自動下載（`HttpGet` → `writefile` → `getcustomasset`），也能用 `rbxassetid://`、純數字 ID 或 workspace 內的檔案。`CreateWindow` 裡的網址在背景下載，不會卡住建立視窗。
- **設定頁**的 Background 區塊：「Background image」輸入框（貼圖片或 `.webm` 網址、ID 後按 Enter；載入失敗會跳通知並還原）、「Image transparency」滑桿、「Image blur」滑桿、「Remove background」按鈕。兩個值會存進設定檔（Flag `MD3_Background`／`MD3_BackgroundTransparency`）。
- 右側內容區（Content panel）和各列（Rows）預設是不透明的，所以圖片主要從標題列、左側分頁欄和邊緣露出來；想讓圖片也透到內容後面，到主題編輯器把 **Content panel**、**Rows** 的透明度調高即可。

### 主題色、圖標、文字顏色

最常調的三個顏色各有一個控制，設定頁 Appearance 區塊可以直接選色，程式裡也能設定：

| 設定頁 | 程式 | 會改到 |
| --- | --- | --- |
| Theme color | `CreateWindow{ ThemeColor = c }`／`Theme:SetThemeColor(c)` | 整套配色（按鈕、開關、選取底色、標題…都由它生成） |
| Icon color | `CreateWindow{ IconColor = c }`／`Theme:SetIconColor(c)` | 所有圖標（一般、標題列、通知、選中分頁） |
| Text color | `CreateWindow{ TextColor = c }`／`Theme:SetTextColor(c)` | 所有文字；說明／副標題等次要文字自動用同色較淡的版本，沒另外設定時圖標也跟著文字色 |

`SetIconColor(nil)`／`SetTextColor(nil)` 還原成自動生成的顏色。要更細（例如只改選中分頁的圖標、只改說明文字）請用下面的主題編輯器。

### 主題編輯器

`Window:AddSettingsTab()` 的設定頁裡有「Theme editor」區塊（也可以用 `Window:AddThemeEditor(tab)` 放進你自己的分頁；不給參數會另開一個「Theme」分頁）：

- **Preset**：快速套用內建主題。Baseline／Blue／Teal／Green／Yellow／Orange／Red／Pink 只換主題色（你自訂的顏色保留）；**NeverLose** 是完整主題，照 [NeverLose](https://github.com/engnyg/NeverLose) 的配色：深色模式、近黑底色（`#08080D`）、石板灰外框（`#2D303A`）、白色文字、`#4E7FFC` 藍色強調色。NeverLose 的強調色直接等於主題色，所以套用後在 Appearance 換「Theme color」，按鈕、開關、選中分頁圖標會一起換成新顏色，底色與文字保持 NeverLose 風格。從 NeverLose 換到別的主題時，它設定的顏色會自動拿掉（你自己改過的保留）；「Reset custom colors」也會完全回到自動生成的配色。
  - **LinoriaLib 的 8 套主題**也都內建了（照 [LinoriaLib](https://github.com/engnyg/LinoriaLib) `addons/ThemeManager.lua` 的顏色）：**Linoria**（它的「Default」，改名避免跟我們的預設混淆）、**BBot**、**Fatality**、**Jester**、**Mint**、**Tokyo Night**、**Ubuntu**、**Quartz**。它們跟 NeverLose 一樣是完整主題：MainColor 當視窗底色與各列、BackgroundColor 當內容區與輸入框、OutlineColor 當外框與選取底色、FontColor 當文字，次要文字 `#8E8E8E`、錯誤色 `#FF3232` 沿用 LinoriaLib 的固定色；強調色（AccentColor）等於主題色，換主題色時會跟著換。用法一樣：`Preset = "Tokyo Night"` 或 `Window.Theme:ApplyPreset("Fatality")`。程式裡：`MD3:CreateWindow({ Preset = "NeverLose" })`（同時給 `ThemeColor`／`Mode` 的話以它們為準）或 `Window.Theme:ApplyPreset("NeverLose")`；清單在 `MD3.Theme.Presets`。
- **每個顏色一個選色器**：Primary、Secondary、Tertiary、Selection（選取底色）、Background、Content panel、Rows、Text、Secondary text、Outline、**Icons**（一般圖標）、**Accent icons**（標題列／通知圖標）、**Selected tab icon**（選中分頁的圖標）、Error。改過的顏色會標「custom」。
- **Reset custom colors**：清掉自訂顏色，回到由主題色自動生成的配色。
- **Copy theme**／**Import theme**：把主題（主題色、深淺模式、自訂顏色）複製成 JSON 分享，或貼上 JSON 匯入。

**每個選色器都有透明度條**（Opacity），包括 Appearance 區塊的 Icon color／Text color：把 Background、Content panel、Rows 調成半透明就能透過視窗看到遊戲畫面；文字、圖標也能調透明度（說明文字、圖標會跟著文字的透明度）。透明度套用在視窗本身（背景、各列、文字、圖標、分頁、下拉選單）；開關、滑桿、按鈕、對話框等元件內部維持不透明。

自訂顏色是疊在主題色生成的配色之上的「覆寫」：換主題色或切換深淺色時，沒改過的顏色會跟著變，改過的保持不變；改了某個底色（例如 Primary、Background）而沒另外指定它上面的文字色時，文字色會自動選黑或白以保持可讀。自訂顏色和透明度會存進設定檔（Flag `MD3_ThemeOverrides`），`Copy theme` 匯出的 JSON 也包含透明度。

程式裡也能直接用：

```lua
local theme = Window.Theme
theme:SetOverride("Primary", Color3.fromRGB(255, 80, 80))  -- 固定某個顏色角色
theme:SetOverride("Icon", Color3.fromRGB(255, 200, 0))     -- 所有一般圖標改成黃色
theme:SetOverride("Primary", nil)                          -- 還原成自動生成
theme:SetOverride("Surface", Color3.fromRGB(16, 16, 24), 0.3) -- 顏色 + 透明度（0 = 不透明、1 = 全透明）
theme:SetTransparency("SurfaceContainerHigh", 0.5)          -- 只改透明度
theme:ClearOverrides()
local data = theme:Export()   -- { Seed = "6750a4", Mode = "Dark", Overrides = { Icon = "ffc800" } }
theme:Import(data)
```

**單一圖標的顏色**：`IconColor` 可以填主題色角色名稱（會跟著主題變）或固定的 `Color3`：

```lua
Window:AddTab({ Title = "Combat", Icon = "bolt", IconColor = Color3.fromRGB(255, 200, 0) })
Main:AddButton({ Title = "Delete", Icon = "delete", IconColor = "Error" })
Window:Notify({ Title = "Saved", Icon = "save", IconColor = "Tertiary" })
MD3:CreateWindow({ Title = "My Hub", Icon = "widgets", AppIconColor = "Tertiary" }) -- 只改標題列圖標
tab:SetIconColor(nil) -- 分頁圖標改回跟著主題
```

### Executor 環境工具（`MD3.Env`）

各家 executor 的全域函式名稱不一，`MD3.Env` 幫你包好並在不支援時安全退回：`GetGuiParent()`、`ProtectGui(gui)`、`ReadFile` / `WriteFile` / `IsFile` / `IsFolder` / `MakeFolder`（可多層）/ `ListFiles` / `DeleteFile`、`HttpGet(url)`、`GetCustomAsset(path)`、`SetClipboard(text)`、`Registry()`，以及 `Env.Name`（`identifyexecutor()`）、`Env.CanUseFiles`、`Env.CanUseCustomAssets`。

## 特色

- **完整的 M3 色彩系統**：從單一種子色（seed color）自動生成 Primary / Secondary / Tertiary / Neutral / Error 色調盤，並依此組出淺色／深色兩套完整的 color role（`Primary`、`OnPrimaryContainer`、`SurfaceContainerHigh`…等），呼應 Material You 的動態配色概念。
  - 說明：色彩生成使用 HSL 近似取代 Google 官方的 HCT/CAM16 色彩空間，外觀已相當接近 M3，但不是逐位元對照的官方演算法。
- **即時換色 / 換主題**：呼叫 `theme:SetSeedColor(...)` 或 `theme:SetMode("Dark")` 後，所有已建立的元件都會透過 `Theme.Changed` 訊號自動重新上色，不需重建 UI。
- **M3 設計 token**：Typography 字級表、Shape 圓角尺度、Motion 動效時長/曲線、Elevation 陰影與 State Layer（hover/press/focus 疊層）、Ripple 水波紋，通通內建。
- **16 個常用元件**：Button、IconButton、FAB、Card、Switch、Checkbox、RadioButton、Slider、TextField、Chip、Dialog、Snackbar、TopAppBar、NavigationBar、ProgressIndicator（線性／環形）、Divider。
- **無外部資源依賴**：陰影、水波紋、進度指示器都是用純 Frame / UIStroke / UIGradient 動態畫出來的，不需要上傳任何圖片資產就能運作。

## 安裝

1. 專案已附上 `default.project.json`，可直接用 Rojo 建置：
   ```bash
   rojo build -o MaterialDesign3.rbxlx
   # 或搭配 Roblox Studio 外掛使用 rojo serve 即時同步
   ```
   `src/` 會同步進 `ReplicatedStorage.MaterialDesign3`，`example/` 會同步成 `StarterPlayerScripts.MD3Example` 示範腳本。
2. 也可以直接把 `src` 資料夾整個丟進你自己的專案（例如 `ReplicatedStorage`），並依需求調整 `default.project.json`。

### 從外部載入（單檔版）

`dist/MaterialDesign3.luau` 是把整個 `src/` 打包成的單一檔案，執行後回傳 `MD3` 表，不依賴任何 `script` 階層。Executor 直接用上面「Executor 快速開始」的 `loadstring(game:HttpGet(...))()` 即可。

在一般 Roblox 遊戲（非 executor）裡要注意：客戶端（LocalScript）不能發 HTTP 請求也不能 `loadstring`，只有伺服器能用 `HttpService:GetAsync` 且須開啟 `ServerScriptService.LoadStringEnabled`。所以要在遊戲的客戶端 UI 使用，最穩的做法是把這個單檔內容貼進一個 ModuleScript（放在 `ReplicatedStorage`）然後 `require` 它。

修改 `src/` 之後重新打包並跑冒煙測試：

```bash
python3 tools/bundle.py                 # 產生 dist/MaterialDesign3.luau
python3 tools/smoke/run.py              # 需要 luau CLI，可用 LUAU=/path/to/luau 指定
```

冒煙測試會用 `loadstring` 載入打包檔（跟 executor 載入同一條路徑），在模擬的 Roblox API 與模擬的 executor 檔案系統上建立並操作全部 16 個元件、executor 視窗的每一種元件、設定檔存讀、切換鍵、重複建立視窗的替換，再切換主題。

## 單獨使用元件（Studio / 自己的遊戲）

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MD3 = require(ReplicatedStorage.MaterialDesign3)

-- 全域主題是一個單例（singleton），修改它會讓所有已建立的元件即時更新
local theme = MD3.Theme.Default()
theme:SetSeedColor(Color3.fromHex("#006C51")) -- 換成你自己的品牌色
theme:SetMode("Dark")                          -- "Light" | "Dark"

local button = MD3.Button.new({
    Text = "繼續",
    Variant = "Filled", -- Filled / Tonal / Outlined / Text / Elevated
    Parent = someScreenGuiOrFrame,
})

button.Activated:Connect(function()
    print("被按下了！")
end)
```

完整範例請看 `example/init.client.lua`，涵蓋文中列出的所有元件。（這份是給 Rojo／Studio 的 LocalScript 範例；executor 請看 `examples/executor.lua`。）

## 元件一覽

| 元件 | 檔案 | 重點 Props |
| --- | --- | --- |
| Button | `Components/Button.lua` | `Variant`（Filled/Tonal/Outlined/Text/Elevated）、`Icon`、`Disabled` |
| IconButton | `Components/IconButton.lua` | `Variant`（Standard/Filled/Tonal/Outlined）、`Toggleable`、`Selected` |
| FAB | `Components/FAB.lua` | `Size`（Small/Standard/Large）、`Extended`、`Color` |
| Card | `Components/Card.lua` | `Variant`（Elevated/Filled/Outlined）、`Interactive` |
| Switch | `Components/Switch.lua` | `Value`、`Disabled` |
| Checkbox | `Components/Checkbox.lua` | `Value`（`true`/`false`/`"Indeterminate"`） |
| RadioButton | `Components/RadioButton.lua` | 單顆用 `.new`，一組互斥選項用 `RadioButton.Group(options, initial, parent, theme)` |
| Slider | `Components/Slider.lua` | `Min`、`Max`、`Step`、`Value` |
| TextField | `Components/TextField.lua` | `Variant`（Outlined/Filled）、`Label`、`SupportingText`、`Error` |
| Chip | `Components/Chip.lua` | `Variant`（Assist/Filter/Input/Suggestion）、`Removable` |
| Dialog | `Components/Dialog.lua` | `Title`、`Text`、`Actions`（陣列，每項含 `Text`/`Variant`/`OnActivated`） |
| Snackbar | `Components/Snackbar.lua` | `:Show(message, action?, duration?)` |
| TopAppBar | `Components/TopAppBar.lua` | `Title`、`NavigationIcon`、`Actions` |
| NavigationBar | `Components/NavigationBar.lua` | `Destinations`、`Selected` |
| ProgressIndicator | `Components/ProgressIndicator.lua` | `ProgressIndicator.Linear{...}` / `ProgressIndicator.Circular{...}`，支援 `Value` 或 `Indeterminate` |
| Divider | `Components/Divider.lua` | `Vertical` |

每個元件都遵循同一套慣例：
- `.Instance` 是底層的 Roblox GuiObject，你可以自由調整 `Size`/`Position`/`LayoutOrder`/`Parent`。
- 互動元件都有對應事件訊號（`.Activated`、`.Changed`、`.Toggled`…），是輕量的自製 Signal（非 BindableEvent，效能較好）。
- `:SetTheme(theme)` 可個別覆寫某元件要用哪個主題（預設吃 `Theme.Default()`）。
- `:Destroy()` 會清掉內部連線與子元件，記得在 UI 銷毀時呼叫。

## 核心模組（`src/Core`）

- `Theme.lua`：色彩系統與主題單例，`Theme.new(seed, mode)` 建新主題，`Theme.Default()` 取得共用單例。
- `Typography.lua`：M3 完整字級表（Display/Headline/Title/Body/Label × Large/Medium/Small），`Typography.Apply(textObject, "TitleLarge")` 一行套用字型/字級/行高。
- `Shape.lua`：圓角 token（None/ExtraSmall/Small/Medium/Large/ExtraLarge/Full）。
- `Motion.lua`：M3 動效時長 token 及對應 Roblox `TweenInfo`（Roblox 的 `TweenInfo` 不支援任意貝茲曲線，這裡取最接近的內建 EasingStyle）。
- `Elevation.lua`：用多層半透明圓角 Frame 疊出來的柔和陰影，不需圖片素材；會自動跟著目標元件的位置/大小同步。
- `StateLayer.lua` / `Ripple.lua`：hover/press/focus 疊層與水波紋回饋。
- `Icons.lua`：Material 平面圖標系統，見下方「圖標（不用 emoji）」。

## Executor 層（`src/Executor`、`src/Window`）

- `Executor/Env.lua`：executor 全域函式的相容層（見上方「Executor 環境工具」）。
- `Executor/Assets.lua`：外部圖片載入（見上方「載入外部圖片」）；所有元件的 `Icon` 參數都透過它解析。
- `Executor/IconImages.lua`：`MD3.IconImages.Load(style?)` 下載該樣式的圖標 sprite sheet（預設 `Outlined`），`CreateWindow` 預設會在背景做這件事（`Icons = false` 可關閉）。
- `Executor/IconFont.lua`（選用）：`MD3.IconFont.Load(folder?, style?)` 下載該樣式的字型 → 寫進 workspace → 產生 Roblox font family JSON → 用 `getcustomasset` 載入，並自動呼叫 `Icons.SetFont`。
- `Window/Window.lua`、`Window/Tab.lua`：視窗、分頁與 Section。
- `Window/Elements/*`：各個視窗元件；列表項目版面（標題／說明／右側控制項）共用 `Elements/Base.lua`。
- `Window/Themer.lua`：把一般 Instance 屬性綁到主題色角色，換主題時自動重新上色。
- `Window/Config.lua`、`Window/Notifier.lua`：設定檔序列化與堆疊式通知。

## 圖標（不用 emoji）

**在 executor 上不用做任何事**：`CreateWindow` 會在背景用 `MD3.IconImages.Load()` 載入圖標圖片（需要 executor 支援 `writefile` 與 `getcustomasset`）。視窗會先立刻出現（圖標暫時是 BuilderIcons／簡單符號），圖片一載入完就原地換成 Material 圖標。

做法跟 [NeverLose](https://github.com/engnyg/NeverLose) 載入圖片一樣：`HttpGet` 下載 PNG → `writefile` 存進 `MD3/assets/` → `getcustomasset` 轉成圖片 ID → 用 `ContentProvider:PreloadAsync` 確認 Roblox 真的載入成功。每個圖標是從同一張 sprite sheet 用 `ImageRectOffset` 切出來，顏色跟著標籤的文字顏色（主題色）走。

| `IconStyle` | 樣式 | 圖片 |
| --- | --- | --- |
| `"Outlined"`（預設） | 線條版，M3 預設外觀 | [`assets/icons/MaterialIconsOutlined.png`](assets/icons/MaterialIconsOutlined.png)（~86 KB） |
| `"Filled"` | 實心版 | `assets/icons/MaterialIconsFilled.png`（~74 KB） |
| `"Round"` | 圓角 | `assets/icons/MaterialIconsRound.png`（~81 KB） |
| `"Sharp"` | 直角 | `assets/icons/MaterialIconsSharp.png`（~71 KB） |

圖片由 [`tools/build_icon_sheets.py`](tools/build_icon_sheets.py) 從官方字型畫出（864×864，12 欄、每格 64 px + 4 px 間隔），對照表在 `src/Core/IconSheet.lua`。載入失敗時（下載到的不是 PNG、或 Roblox 載不進來）會保留原本顯示的樣式，不會壞掉。

> 為什麼不用字型：用 `getcustomasset` 產生的字型檔在部分 executor 上載不起來，而 Material 圖標在字型裡是 Unicode 私用區（PUA）字元——字型沒載入時，繁體中文 Windows 會用系統字型把它們畫成中文字。圖片沒有這個問題。現在沒有任何圖標來源時也不會再輸出 PUA 字元。
>
> 字型版本仍然保留：`MD3.IconFont.Load("MD3", "Outlined")`（Google 只提供 Outlined／Round／Sharp 的 `.otf`，`assets/fonts/` 是用 [`tools/convert_icon_fonts.py`](tools/convert_icon_fonts.py) 轉成的 TrueType 版）。同時載入時圖片優先。

**執行中也能切換**，畫面上已經有的圖標會立刻重畫，不用重建 UI：
- 內建設定頁（`Window:AddSettingsTab()`）的「Appearance → Icon style」下拉選單，選擇會存進設定檔（Flag `MD3_IconStyle`）。
- 程式裡：`Window:SetIconStyle("Round")`（回傳實際顯示的樣式）或 `MD3.IconImages.Load("Round")`；`MD3.IconImages.CurrentStyle` 是目前顯示的樣式。

**沒有 Material 字型時**（executor 不支援 `getcustomasset`、或在 Studio 還沒設定字型），圖標會改用 Roblox 客戶端本身就有的 **BuilderIcons** 字型（`rbxasset://LuaPackages/Packages/_Index/BuilderIcons/BuilderIcons/BuilderIcons.json`，Roblox App 介面用的那套）。它是連字（ligature）字型——文字 `gear` 會畫成齒輪——`Icons.lua` 內建了 Material 名稱到 BuilderIcons 名稱的對照表（`settings` → `gear`、`close` → `x`…）。也可以直接用任何 BuilderIcons 圖標：`Icon = "builder:sword"`。不想用可以呼叫 `MD3.Icons.SetBuilderIconsEnabled(false)`。優先順序：Material 字型 → BuilderIcons → 簡單符號。

以下是在 Studio／自己遊戲裡使用 Material 字型的做法。

Roblox 沒有內建 Material Symbols 字型，所以要顯示「真正的」M3 平面圖標，本質上一定要一個圖標字型資產——沒有捷徑。`Icons.lua` 幫你把這件事做成一次性設定：

1. 下載字型：線條版用本 repo 的 [`assets/fonts/MaterialIconsOutlined-Regular.ttf`](assets/fonts/MaterialIconsOutlined-Regular.ttf)，實心版用 [google/material-design-icons](https://github.com/google/material-design-icons) 的 `font/MaterialIcons-Regular.ttf`（皆為 Apache-2.0）。
2. 在 Roblox Studio 把這個字型檔上傳成 Font 資產，拿到它的 `rbxassetid`。
3. 遊戲啟動時執行一次：
   ```lua
   MD3.Icons.SetFont(Font.new("rbxassetid://<你的字型資產ID>"))
   ```

設定完成後，`Checkbox` 的勾勾／減號、`Chip` 的關閉按鈕都會自動改用 `Icons.lua` 內建的 Material 圖標字碼（`check`、`remove`、`close`…共 110+ 個，字碼取自官方 `MaterialIcons-Regular.codepoints`），純文字字元渲染、可直接套色/縮放，不是圖片、更不是 emoji。在呼叫 `SetFont` 之前，這些元件會先用簡單的幾何符號（`✓`/`−`/`✕`）當退場機制，避免字型未設定時顯示空白方塊；一旦設定字型就會自動切換成真正的 Material 圖標。

需要表裡沒有的圖標時，可以從官方 `MaterialIcons-Regular.codepoints` 查字碼後用 `Icons.Register("name", 0xe000)` 加入；`Icons.CanRender(name)` 可判斷目前能不能畫出該圖標。

`Icons.Glyph("settings")` / `Icons.Apply(textObject, "settings")` 也可以在你自己的 UI 裡直接使用，或用來取代 `Button` / `IconButton` / `FAB` 目前吃的 `Icon = "rbxassetid://..."`（把 `Icon` 換成一個帶有 Material 圖標字型的 `TextLabel` 即可）。

## 已知取捨

- 色彩生成用 HSL 近似 HCT，色階曲線與官方 Material Theme Builder 不會 100% 一致，但保留了 M3 的分層邏輯（13 級色調、container/on-container 配對等）。
- 陰影（`Elevation`）是放在元件旁邊的兄弟節點，所以如果父層有 `UIListLayout`，陰影也會被排版而佔位；目前 executor 視窗只在不受排版影響的地方（主視窗、對話框）使用陰影。
- 陰影用堆疊 Frame 模擬柔邊效果，效果不如向量陰影細緻，但完全不需要外部貼圖資源；若想要更精緻的陰影，可以自行替換 `Elevation.Apply` 的實作改用你上傳的陰影圖。
- `Button` / `IconButton` / `FAB` / `TopAppBar` / `NavigationBar` 的 `Icon` props 目前吃圖片資產（`rbxassetid://...`），因為每個 Roblox 專案的圖示資源都不同；請把你自己上傳的圖示 ID 傳進去，或改用上面的 `Icons.lua` 文字圖標方案。
