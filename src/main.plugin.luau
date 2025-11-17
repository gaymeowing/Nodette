local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local plugtilly = require("./packages/plugtilly")

local TOOLBAR = plugin:CreateToolbar(plugtilly.name(plugin))
local CREATE_NODE = plugtilly.create_toolbar_button(plugin, TOOLBAR, {
	id = "Create Node",
	tooltip = "Creates a new node",
	icon = Content.fromAssetId(78705581677742),
})
local CREATE_NODE_HUB = plugtilly.create_toolbar_button(plugin, TOOLBAR, {
	id = "Create Node Hub",
	tooltip = "Creates a new Node Hub at the mouse position with the inputted size",
	icon = Content.fromAssetId(78705581677742),
})
local INPUT_SCREEN_GUI = Instance.new("ScreenGui")
local INPUT_GUI: GuiObject = Instance.new("Frame")
local FOLDER_NAME = "Nodes"
local WEB_FOLDER: Folder

local function RESIZE_LINE_HANDLE(line: BoxHandleAdornment, start: vector, finish: vector)
	line.Size = vector.create(0.4, 0.4, vector.magnitude(start - finish))
	line.CFrame = CFrame.new(vector.lerp(start, finish, 0.5), finish)
end

local function GET_OR_CREATE_FOLDER()
	local found_folder = Workspace:FindFirstChild(FOLDER_NAME) :: Folder?

	if not found_folder then
		WEB_FOLDER = Instance.new("Folder")
		WEB_FOLDER.Name = FOLDER_NAME
		WEB_FOLDER.Parent = Workspace
		return
	end
	WEB_FOLDER = found_folder
end

CREATE_NODE_HUB.Click:Connect(GET_OR_CREATE_FOLDER)
CREATE_NODE.Click:Connect(GET_OR_CREATE_FOLDER)

local KEYCODE_TO_NUMBER = table.freeze({
	[Enum.KeyCode.KeypadOne] = 1,
	[Enum.KeyCode.KeypadTwo] = 2,
	[Enum.KeyCode.KeypadThree] = 3,
	[Enum.KeyCode.KeypadFour] = 4,
	[Enum.KeyCode.KeypadFive] = 5,
	[Enum.KeyCode.KeypadSix] = 6,
	[Enum.KeyCode.KeypadSeven] = 7,
	[Enum.KeyCode.KeypadEight] = 8,
	[Enum.KeyCode.KeypadNine] = 9,
	[Enum.KeyCode.KeypadZero] = 0,
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.Seven] = 7,
	[Enum.KeyCode.Eight] = 8,
	[Enum.KeyCode.Nine] = 9,
	[Enum.KeyCode.Zero] = 0,
})

CREATE_NODE_HUB.Click:Connect(function()
	INPUT_SCREEN_GUI.Enabled = true
	local nodes_per_side_input = ""
	local input_began_connection: RBXScriptConnection
	local main_thread = coroutine.running()

	input_began_connection = INPUT_GUI.InputBegan:Connect(function(input)
		local number = KEYCODE_TO_NUMBER[input.KeyCode]
		print(input.KeyCode)

		if number then
			nodes_per_side_input ..= tostring(number)
		else
			input_began_connection:Disconnect()
			task.spawn(main_thread)
		end
	end)
	coroutine.yield()

	local nodes_per_side = tonumber(nodes_per_side_input)

	if (nodes_per_side and nodes_per_side < 2) or not nodes_per_side then
		INPUT_SCREEN_GUI.Enabled = false
		return
	end



	INPUT_SCREEN_GUI.Enabled = false
end)

do

	INPUT_SCREEN_GUI.Name = plugtilly.name(plugin)
	INPUT_SCREEN_GUI.Parent = CoreGui

	INPUT_GUI.Size = UDim2.fromScale(1, 1)
	INPUT_GUI.Transparency = 1
	INPUT_GUI.Parent = INPUT_SCREEN_GUI

end
