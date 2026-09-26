local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local function isPress(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function isMove(input)
	return input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch
end

local function getEffectiveScale(obj: Instance?): number
	local scale = 1
	local current = obj
	while current and not current:IsA("DataModel") do
		if current:IsA("GuiObject") then
			local uiScale = current:FindFirstChildOfClass("UIScale")
			if uiScale and uiScale.Scale then
				scale = scale * uiScale.Scale
			end
		end
		current = current.Parent
	end
	return math.max(scale, 0.001)
end

-- Shared controller registry per target GuiObject so multiple handles
-- (e.g. watermark background + multiple blocks, indicator stack + chips)
-- share drag state and never fight each other.
local controllers = setmetatable({}, { __mode = "k" })

local function getOrCreateController(target: GuiObject)
	local existing = controllers[target]
	if existing then
		return existing
	end

	local controller = {
		target = target,
		handles = {},
		dragging = false,
		settling = false,
		moved = false,
		dragInput = nil,
		startInput = nil,
		startPos = target.Position,
		targetOffset = Vector2.new(target.Position.X.Offset, target.Position.Y.Offset),
		activeHandle = nil,
		activeConfig = nil,
	}

	local function getScreenClamp(ox: number, oy: number)
		local parent = target.Parent
		local pSize = parent and parent.AbsoluteSize or (workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080))
		local effScale = getEffectiveScale(parent)
		local parentW = pSize.X / effScale
		local parentH = pSize.Y / effScale
		local w = target.AbsoluteSize.X / effScale
		local h = target.AbsoluteSize.Y / effScale

		if target.AnchorPoint.X == 0.5 and target.AnchorPoint.Y == 0.5 then
			local halfW = w / 2
			local halfH = h / 2
			local minX = -parentW * 0.5 + halfW + 8
			local maxX = parentW * 0.5 - halfW - 8
			local minY = -parentH * 0.5 + halfH + 8
			local maxY = parentH * 0.5 - halfH - 8
			return math.clamp(ox, minX, maxX), math.clamp(oy, minY, maxY)
		else
			local minX = 8
			local maxX = math.max(8, parentW - w - 8)
			local minY = 8
			local maxY = math.max(8, parentH - h - 8)
			return math.clamp(ox, minX, maxX), math.clamp(oy, minY, maxY)
		end
	end

	local connChanged = UserInputService.InputChanged:Connect(function(input)
		if not controller.dragging or not isMove(input) then
			return
		end
		if input.UserInputType == Enum.UserInputType.Touch and controller.dragInput and input ~= controller.dragInput then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement and not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
			controller.dragging = false
			return
		end

		local effScale = getEffectiveScale(target.Parent)
		local delta = (input.Position - controller.startInput) / effScale
		if delta.Magnitude > 2 then
			controller.moved = true
		end

		local rawX = controller.startPos.X.Offset + delta.X
		local rawY = controller.startPos.Y.Offset + delta.Y

		local config = controller.activeConfig
		local clampScreen = not config or (config.options and config.options.ClampScreen ~= false)
		if clampScreen then
			local cx, cy = getScreenClamp(rawX, rawY)
			controller.targetOffset = Vector2.new(cx, cy)
		else
			controller.targetOffset = Vector2.new(rawX, rawY)
		end

		local smooth = config and config.options and config.options.Smooth == true
		if not smooth then
			target.Position = UDim2.new(controller.startPos.X.Scale, math.round(controller.targetOffset.X), controller.startPos.Y.Scale, math.round(controller.targetOffset.Y))
		end
	end)

	local connEnded = UserInputService.InputEnded:Connect(function(input)
		if controller.dragging and isPress(input) then
			if input.UserInputType == Enum.UserInputType.Touch and controller.dragInput and input ~= controller.dragInput then
				return
			end
			controller.dragging = false
			local config = controller.activeConfig
			local wasMoved = controller.moved
			local smooth = config and config.options and config.options.Smooth == true
			if not smooth then
				controller.settling = false
				target.Position = UDim2.new(controller.startPos.X.Scale, math.round(controller.targetOffset.X), controller.startPos.Y.Scale, math.round(controller.targetOffset.Y))
			end

			if not wasMoved and config and config.onClick then
				config.onClick()
			elseif wasMoved and config and config.onDragEnd then
				config.onDragEnd()
			end
		end
	end)

	local connRender = RunService.RenderStepped:Connect(function(dt)
		local config = controller.activeConfig
		local smooth = config and config.options and config.options.Smooth == true
		if not smooth or (not controller.dragging and not controller.settling) then
			return
		end
		local curX = target.Position.X.Offset
		local curY = target.Position.Y.Offset
		local dist = math.sqrt((curX - controller.targetOffset.X) ^ 2 + (curY - controller.targetOffset.Y) ^ 2)
		if dist > 0.4 then
			local factor = 1 - math.exp(-24 * dt)
			local newX = curX + (controller.targetOffset.X - curX) * factor
			local newY = curY + (controller.targetOffset.Y - curY) * factor
			target.Position = UDim2.new(controller.startPos.X.Scale, math.round(newX), controller.startPos.Y.Scale, math.round(newY))
		else
			if not controller.dragging then
				controller.settling = false
				target.Position = UDim2.new(controller.startPos.X.Scale, math.round(controller.targetOffset.X), controller.startPos.Y.Scale, math.round(controller.targetOffset.Y))
			end
		end
	end)

	local connDestroying = target.Destroying:Connect(function()
		if controller.cleanup then
			controller.cleanup()
		end
	end)

	controller.cleanup = function()
		connChanged:Disconnect()
		connEnded:Disconnect()
		connRender:Disconnect()
		connDestroying:Disconnect()
		controllers[target] = nil
	end

	controllers[target] = controller
	return controller
end

return function(maid, handle: GuiObject, target: GuiObject, onClick, onDragEnd, options)
	options = options or {}
	local controller = getOrCreateController(target)
	local config = {
		onClick = onClick,
		onDragEnd = onDragEnd,
		options = options,
	}
	controller.handles[handle] = config

	local connBegan = handle.InputBegan:Connect(function(input)
		if not isPress(input) then
			return
		end
		-- In FPS games, don't drag UI when mouse is locked for aiming/shooting.
		if input.UserInputType == Enum.UserInputType.MouseButton1 and UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then
			return
		end
		-- If already dragging (e.g. from another handle on the same target), ignore.
		if controller.dragging then
			return
		end

		controller.dragging = true
		controller.settling = true
		controller.moved = false
		controller.dragInput = input
		controller.startInput = input.Position
		controller.activeHandle = handle
		controller.activeConfig = config

		-- Normalize AnchorPoint to (0, 0) and Position to pure offset for HUD widgets
		-- so presets with Scale (1, 0.5) don't distort or jump during dragging.
		-- Preserve (0.5, 0.5) for the center-anchored main Window.
		if not (target.AnchorPoint.X == 0.5 and target.AnchorPoint.Y == 0.5 and target.Position.X.Scale == 0.5 and target.Position.Y.Scale == 0.5) then
			if target.AnchorPoint ~= Vector2.new(0, 0) or target.Position.X.Scale ~= 0 or target.Position.Y.Scale ~= 0 then
				local parent = target.Parent
				local pAbs = parent and parent.AbsolutePosition or Vector2.new(0, 0)
				local effScale = getEffectiveScale(parent)
				local localX = (target.AbsolutePosition.X - pAbs.X) / effScale
				local localY = (target.AbsolutePosition.Y - pAbs.Y) / effScale
				target.AnchorPoint = Vector2.new(0, 0)
				target.Position = UDim2.fromOffset(math.round(localX), math.round(localY))
			end
		end

		controller.startPos = target.Position
		controller.targetOffset = Vector2.new(target.Position.X.Offset, target.Position.Y.Offset)
	end)

	maid:GiveTask(connBegan)
	maid:GiveTask(function()
		controller.handles[handle] = nil
		if next(controller.handles) == nil then
			controller.cleanup()
		end
	end)
end
