-- Makes `handle` drag `target` around (mouse and touch). `onClick` fires
-- instead when the pointer barely moved, so a draggable button still clicks.
-- `onDragEnd` fires after a real drag (e.g. to save the new position).
local UserInputService = game:GetService("UserInputService")

local function isPress(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function isMove(input)
	return input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch
end

return function(maid, handle: GuiObject, target: GuiObject, onClick, onDragEnd)
	local dragging, dragInput, startPos, startInput = false, nil, nil, nil
	local moved = false

	maid:GiveTask(handle.InputBegan:Connect(function(input)
		if isPress(input) then
			dragging, moved = true, false
			dragInput = input
			startInput = input.Position
			startPos = target.Position
		end
	end))
	maid:GiveTask(UserInputService.InputChanged:Connect(function(input)
		if not dragging or not isMove(input) then
			return
		end
		if input.UserInputType == Enum.UserInputType.Touch and dragInput.UserInputType == Enum.UserInputType.Touch and input ~= dragInput then
			return
		end
		local delta = input.Position - startInput
		if delta.Magnitude > 4 then
			moved = true
		end
		target.Position = UDim2.new(
			startPos.X.Scale,
			startPos.X.Offset + delta.X,
			startPos.Y.Scale,
			startPos.Y.Offset + delta.Y
		)
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
end
