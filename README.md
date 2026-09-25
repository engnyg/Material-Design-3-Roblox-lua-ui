# MD3 — Roblox Luau 版 Material Design 3 UI 庫

一個從零打造、可直接用 [Rojo](https://rojo.space/) 同步進 Roblox Studio 的 Material Design 3（M3）UI 元件庫，純 Luau 撰寫、不依賴任何外部套件或圖片素材。

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

## 快速開始

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

完整範例請看 `example/init.client.lua`，涵蓋文中列出的所有元件。

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

## 已知取捨

- 色彩生成用 HSL 近似 HCT，色階曲線與官方 Material Theme Builder 不會 100% 一致，但保留了 M3 的分層邏輯（13 級色調、container/on-container 配對等）。
- 陰影用堆疊 Frame 模擬柔邊效果，效果不如向量陰影細緻，但完全不需要外部貼圖資源；若想要更精緻的陰影，可以自行替換 `Elevation.Apply` 的實作改用你上傳的陰影圖。
- Checkbox 的勾勾／減號是用文字字元（`✓`/`−`）畫的，避免依賴不確定存在的內建圖片資產 ID；如果想用向量圖示，直接把 `Checkbox.lua` 裡的 `TextLabel` 換成你自己的 `ImageLabel` 即可。
- 範例與元件預設沒有帶任何 `rbxassetid://` 圖示，因為每個 Roblox 專案的圖示資源都不同；請把你自己上傳的圖示 ID 傳進 `Icon` / `NavigationIcon` 等 props。
