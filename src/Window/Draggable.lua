local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local function isPress(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function isMove(input)
	return input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch
end

return function(maid, handle: GuiObject, target: GuiObject, onClick, onDragEnd, options)
	options = options or {}
	local smooth = options.Smooth ~= false
	local clampScreen = options.ClampScreen ~= false

	local dragging, dragInput, startInput = false, nil, nil
	local startPos = target.Position
	local targetOffset = Vector2.new(target.Position.X.Offset, target.Position.Y.Offset)
	local moved = false

	local function getScreenClamp(ox, oy)
		local cam = workspace.CurrentCamera
		local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
		if target.AnchorPoint.X == 0.5 and target.AnchorPoint.Y == 0.5 then
			local halfW = target.AbsoluteSize.X / 2
			local halfH = target.AbsoluteSize.Y / 2
			local minX = -vp.X * 0.5 + halfW + 10
			local maxX = vp.X * 0.5 - halfW - 10
			local minY = -vp.Y * 0.5 + halfH + 10
			local maxY = vp.Y * 0.5 - halfH - 10
			return math.clamp(ox, minX, maxX), math.clamp(oy, minY, maxY)
		else
			local w = target.AbsoluteSize.X
			local h = target.AbsoluteSize.Y
			return math.clamp(ox, 8, math.max(8, vp.X - w - 8)), math.clamp(oy, 8, math.max(8, vp.Y - h - 8))
		end
	end

	maid:GiveTask(handle.InputBegan:Connect(function(input)
		if isPress(input) then
			dragging, moved = true, false
			dragInput = input
			startInput = input.Position
			startPos = target.Position
			targetOffset = Vector2.new(target.Position.X.Offset, target.Position.Y.Offset)
		end
	end))

	maid:GiveTask(UserInputService.InputChanged:Connect(function(input)
		if not dragging or not isMove(input) then
			return
		end
		if input.UserInputType == Enum.UserInputType.Touch and dragInput and dragInput.UserInputType == Enum.UserInputType.Touch and input ~= dragInput then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement and not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
			dragging = false
			return
		end
		local delta = input.Position - startInput
		if delta.Magnitude > 4 then
			moved = true
		end
		local rawX = startPos.X.Offset + delta.X
		local rawY = startPos.Y.Offset + delta.Y
		if clampScreen then
			local cx, cy = getScreenClamp(rawX, rawY)
			targetOffset = Vector2.new(cx, cy)
		else
			targetOffset = Vector2.new(rawX, rawY)
		end
		if not smooth then
			target.Position = UDim2.new(startPos.X.Scale, targetOffset.X, startPos.Y.Scale, targetOffset.Y)
		end
	end))

	maid:GiveTask(UserInputService.InputEnded:Connect(function(input)
		if dragging and isPress(input) then
			dragging = false
			if not moved and onClick then
				onClick()
			elseif moved and onDragEnd then
				onDragEnd()
			end
		end
	end))

	if smooth then
		maid:GiveTask(RunService.RenderStepped:Connect(function(dt)
			local curX = target.Position.X.Offset
			local curY = target.Position.Y.Offset
			local dist = math.sqrt((curX - targetOffset.X) ^ 2 + (curY - targetOffset.Y) ^ 2)
			if dist > 0.4 then
				local factor = 1 - math.exp(-14 * dt)
				local newX = curX + (targetOffset.X - curX) * factor
				local newY = curY + (targetOffset.Y - curY) * factor
				target.Position = UDim2.new(startPos.X.Scale, math.round(newX), startPos.Y.Scale, math.round(newY))
			end
		end))
	end
end
