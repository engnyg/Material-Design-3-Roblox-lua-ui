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
    Seed = Color3.fromHex("#6750A4"),    -- 主題種子色，整套配色由它生成
    ToggleKey = Enum.KeyCode.RightShift, -- 顯示／隱藏視窗
    ConfigFolder = "MyHub",              -- 設定檔存放資料夾（executor workspace）
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

Window:AddSettingsTab()      -- 內建設定頁：深色模式、主題色、切換鍵、設定檔存讀
Window:LoadAutoloadConfig()  -- 放在腳本最後，載入「自動載入」設定檔

Window:Notify({ Title = "Loaded", Content = "按 RightShift 隱藏／顯示", Icon = "check_circle" })
```

完整示範（每種元件、對話框、通知、設定頁）見 [`examples/executor.lua`](examples/executor.lua)。

### 視窗功能

- **可拖曳**的 M3 視窗：頂部 App Bar（標題／副標題／縮小／關閉）、左側 Navigation Drawer 分頁、右側可捲動內容區。
- **切換鍵**（預設 RightShift）隱藏／顯示；關閉鈕會跳出 M3 對話框讓你選「隱藏」或「卸載（Unload）」。
- **手機支援**：觸控裝置會自動出現可拖曳的浮動按鈕來開關視窗；螢幕太小時視窗會自動等比縮小（`UIScale`）。
- **防偵測／相容性**：ScreenGui 優先放進 `gethui()`，其次 `CoreGui`，最後才是 `PlayerGui`；有 `syn.protect_gui` / `protectgui` 會自動套用；ScreenGui 名稱隨機。
- **重複執行不會疊視窗**：同一個 `Title`（或 `Id`）的視窗再次建立時，舊的會先被卸載（透過 `getgenv()` 記錄）。
- **真正的 Material 圖標**：支援 `writefile` + `getcustomasset` 的 executor 會自動下載 Google 官方 Material Icons 字型（Apache-2.0）並載入，不需要上傳任何資產；不支援時改用 Roblox 客戶端內建的 BuilderIcons 字型（免下載），再不行才退回簡單符號，不會出現方塊字。
- **外部圖片**：所有 `Icon` / `Logo` / 通知的 `Image` 都可以直接填網址，會自動下載並透過 `getcustomasset` 載入（見下方「載入外部圖片」）。
- **設定檔**：`Window:SaveConfig(name)` / `LoadConfig(name)` / `ListConfigs()` / `DeleteConfig(name)` / `SetAutoLoad(name)`，存成 JSON（Color3、KeyCode 會自動序列化）。
- **即時換色**：`Window.Theme:SetMode("Light")`、`Window.Theme:SetSeedColor(color)`，整個視窗立即重新上色。
- **Callback 錯誤不會弄壞 UI**：所有 Callback 都在 `xpcall` 中執行，錯誤只會 `warn` 出來。
- `Window.OnUnload:Connect(fn)`：UI 被卸載時停止你的迴圈／連線。

### 元件（Tab 與 Section 都能呼叫）

| 方法 | 主要參數 | 值（`.Value` / Callback 參數） |
| --- | --- | --- |
| `AddButton` | `Title`、`Description`、`Icon`、`Callback` | —（`:Fire()` 手動觸發） |
| `AddToggle` | `Default`、`Flag`、`Callback` | `boolean` |
| `AddSlider` | `Min`、`Max`、`Step`、`Default`、`Suffix` | `number`（右側數值可直接輸入） |
| `AddInput` | `Placeholder`、`Default`、`Numeric`、`Finished`、`ClearOnSubmit` | `string` |
| `AddDropdown` | `Options`、`Default`、`Multi`、`Searchable` | 單選 `string`／多選 `{string}`；`:SetOptions(list)` 更新選項 |
| `AddKeybind` | `Default`、`Mode`（`Press`/`Toggle`/`Hold`）、`Callback`、`ChangedCallback` | `Enum.KeyCode`（點一下再按鍵；Esc 取消、Backspace 清除） |
| `AddColorPicker` | `Default`、`Callback` | `Color3`（SV 方塊 + 色相條 + HEX 輸入） |
| `AddLabel` | 文字或 `{ Text, Color }` | `:Set(text)` |
| `AddParagraph` | `Title`、`Content` | `:Set({ Title, Content })` |
| `AddDivider` | — | — |

所有元件共通：`:Set(value, silent?)`、`:Get()`、`:OnChanged(fn)`、`:SetTitle()`、`:SetDescription()`、`:SetVisible()`、`:Destroy()`；有 `Flag` 的元件可從 `Window.Flags[flag]` 取得。為了方便移植其他 UI 庫的腳本，`AddX` 也都有 `CreateX` 別名（`CreateToggle`、`CreateSlider`…），`AddTextbox` / `AddBind` 也可用。

`Window` 其他方法：`AddTab`、`SelectTab(tab | index | title)`、`Notify{ Title, Content, Icon, Duration }`、`Dialog{ Title, Content, Buttons = {{ Title, Variant, Callback }} }`、`SetVisible`、`Toggle`、`Minimize`、`SetToggleKey`、`SetTitle`、`SetSubtitle`、`Destroy`（別名 `Unload`）。

### 載入外部圖片（`MD3.Assets`）

做法參考 [NeverLose](https://github.com/engnyg/NeverLose)：`game:HttpGet` 下載圖片 → `writefile` 存進 executor workspace（`MD3/assets/`）→ `getcustomasset` 轉成可以放進 `ImageLabel.Image` 的內容 ID。下載過的檔案會留在磁碟上，之後直接讀取；同一次執行內也會快取。

```lua
-- 任何 Image 都能用
imageLabel.Image = MD3.Assets.Resolve("https://raw.githubusercontent.com/<你>/<repo>/main/assets/logo.png")

-- MD3 的 Icon / Logo 參數都會自動經過 Assets.Resolve
local Window = MD3:CreateWindow({ Title = "My Hub", Logo = "https://.../logo.png" })
Window:AddTab({ Title = "Combat", Icon = "https://.../sword.png" }) -- 圖片分頁圖示（會套主題色）
Window:Notify({ Title = "Hi", Image = "https://.../avatar.png" })      -- 彩色圖片（不套色）
MD3.Button.new({ Text = "Go", Icon = "https://.../go.png" })

MD3.Assets.Preload({ "https://.../a.png", "https://.../b.png" }) -- 腳本開頭先背景下載
```

`Assets.Resolve` 接受：網址（`http(s)://`）、`rbxassetid://…`／`rbxasset://…`／`rbxthumb://…`、純數字 ID（`123456` → `rbxassetid://123456`）、或 workspace 內已有的檔案路徑（`"MyHub/icon.png"`）。下載失敗（例如拿到 GitHub 的 404 HTML 頁）或 executor 不支援 `getcustomasset` 時回傳 `""`（不顯示圖片），不會丟錯。GitHub 圖片請用 `raw.githubusercontent.com/...` 或 `github.com/.../blob/main/xxx.png?raw=true` 這種直接下載的網址。

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
- `Executor/IconFont.lua`：`MD3.IconFont.Load()` 下載 `MaterialIcons-Regular.ttf` → 寫進 workspace → 產生 Roblox font family JSON → 用 `getcustomasset` 載入，並自動呼叫 `Icons.SetFont`。`CreateWindow` 預設會做這件事（`IconFont = false` 可關閉）。
- `Window/Window.lua`、`Window/Tab.lua`：視窗、分頁與 Section。
- `Window/Elements/*`：各個視窗元件；列表項目版面（標題／說明／右側控制項）共用 `Elements/Base.lua`。
- `Window/Themer.lua`：把一般 Instance 屬性綁到主題色角色，換主題時自動重新上色。
- `Window/Config.lua`、`Window/Notifier.lua`：設定檔序列化與堆疊式通知。

## 圖標（不用 emoji）

**在 executor 上不用做任何事**：`CreateWindow` 會自動用 `MD3.IconFont.Load()` 下載並載入官方字型（需要 executor 支援 `writefile` 與 `getcustomasset`）。

**沒有 Material 字型時**（executor 不支援 `getcustomasset`、或在 Studio 還沒設定字型），圖標會改用 Roblox 客戶端本身就有的 **BuilderIcons** 字型（`rbxasset://LuaPackages/Packages/_Index/BuilderIcons/BuilderIcons/BuilderIcons.json`，Roblox App 介面用的那套）。它是連字（ligature）字型——文字 `gear` 會畫成齒輪——`Icons.lua` 內建了 Material 名稱到 BuilderIcons 名稱的對照表（`settings` → `gear`、`close` → `x`…）。也可以直接用任何 BuilderIcons 圖標：`Icon = "builder:sword"`。不想用可以呼叫 `MD3.Icons.SetBuilderIconsEnabled(false)`。優先順序：Material 字型 → BuilderIcons → 簡單符號。

以下是在 Studio／自己遊戲裡使用 Material 字型的做法。

Roblox 沒有內建 Material Symbols 字型，所以要顯示「真正的」M3 平面圖標，本質上一定要一個圖標字型資產——沒有捷徑。`Icons.lua` 幫你把這件事做成一次性設定：

1. 到 [google/material-design-icons](https://github.com/google/material-design-icons)（Apache-2.0）下載 Material Symbols/Icons 的 `.ttf`。
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
