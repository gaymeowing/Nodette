
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")
local StudioService = game:GetService("StudioService")
local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local plugtilly = require("./packages/plugtilly")

local TOOLBAR = plugin:CreateToolbar(plugtilly.name(plugin))
local SELECT_WEB_ICON = Content.fromAssetId(78705581677742)
local CREATE_WEB_ID = "Create Web Folder"
local SELECT_WEB_ID = "Select Web"
local CREATE_NODE = plugtilly.create_toolbar_button(plugin, TOOLBAR, {
	id = "Create Node",
	tooltip = "Creates a new node",
	icon = Content.fromAssetId(78705581677742),
})
local CREATE_HUB_NODE = plugtilly.create_toolbar_button(plugin, TOOLBAR, {
	id = "Create Hub Node",
	tooltip = "Creates a new multi-node",
	icon = Content.fromAssetId(78705581677742),
})
local SELECT_WEB = plugtilly.create_toolbar_button(plugin, TOOLBAR, {
	id = SELECT_WEB_ID,
	tooltip = "Opens a menu to select the node web to be edited",
	icon = SELECT_WEB_ICON,
})
local SHOW_NODES = plugtilly.create_toolbar_button(plugin, TOOLBAR, {
	id = "Show Nodes",
	tooltip = "Shows node map visuals",
	icon = Content.fromAssetId(78705581677742),
})
local CREATE_WEB_FOLDER = plugin:CreatePluginAction(
	CREATE_WEB_ID, CREATE_WEB_ID,
	"Creates a new Node Web Folder parented to Workspace and selects it",
	Content.fromAssetId(78705581677742).Uri,
	true
)
local SELECT_WEB_MENU: PluginMenu

local SHOW_NODES_EXPLICITLY_ENABLED = plugtilly.place_setting(plugin, "ShowNodesEnabled", false)
local LAST_SELECTED_WEB_TAG = `__NODETTE_LAST_SELECTED_WEB USER({StudioService:GetUserId()})`
local LOADED_WEBS = {} :: { [string]: Folder | { Folder } }
local MOUSE_TRACKING_CONNECTION: RBXScriptConnection
local SHOULD_RECOMPUTE_WEBS_MENU = false
local DEFAULT_WEB_FOLDER_NAME = "Nodes"
local MOUSE_TRACKING_OBJECT: GuiObject
local CREATE_HUB_NODE_ENABLED = false
local CREATE_NODE_ENABLED = false
local SHOW_NODES_ENABLED = false
local CURRENT_WEB_FOLDER: Folder
local WEB_TAG = "__NODETTE_WEB"
local MOUSE_X = 0
local MOUSE_Y = 0

local function RESIZE_LINE_HANDLE(line: BoxHandleAdornment, start: vector, finish: vector)
	line.Size = vector.create(0.4, 0.4, vector.magnitude(start - finish))
	line.CFrame = CFrame.new(vector.lerp(start, finish, 0.5), finish)
end

local function UNLOAD_WEB(folder: Instance, name: string)
	local folder_or_folders = LOADED_WEBS[name]

	if not folder_or_folders then
		return
	end

	if type(folder_or_folders) ~= "table" then
		LOADED_WEBS[name] = nil
	else
		if #folder_or_folders == 1 then
			LOADED_WEBS[name] = nil
		end
		local folder_index = table.find(folder_or_folders, folder) :: number

		if #folder_or_folders == 2 then
			LOADED_WEBS[name] = if folder_index == 1 then folder_or_folders[2] else folder_or_folders[1]
		elseif #folder_or_folders == folder_index then
			folder_or_folders[folder_index] = nil
		else
			folder_or_folders[folder_index] = folder_or_folders[#folder_or_folders]
			folder_or_folders[#folder_or_folders] = nil
		end
	end
	SHOULD_RECOMPUTE_WEBS_MENU = true
end

local function LOAD_WEB(folder: Folder, name: string)
	local loaded_foler = LOADED_WEBS[name]

	if loaded_foler then
		if type(loaded_foler) == "table" then
			table.insert(loaded_foler, folder)
		else
			LOADED_WEBS[name] = { loaded_foler, folder }
		end
	else
		LOADED_WEBS[name] = folder
	end
end

local function ON_WEB_SELECTED(folder: Folder)
	if CURRENT_WEB_FOLDER then
		CURRENT_WEB_FOLDER:RemoveTag(LAST_SELECTED_WEB_TAG)
	end

	CURRENT_WEB_FOLDER = folder
	folder:AddTag(LAST_SELECTED_WEB_TAG)
end

local function UNTRACK_MOUSE()
	if not (CREATE_HUB_NODE_ENABLED and CREATE_NODE_ENABLED) then
		MOUSE_TRACKING_CONNECTION:Disconnect()
		MOUSE_TRACKING_CONNECTION = nil :: any
	end
end

local function TRACK_MOUSE()
	if not MOUSE_TRACKING_CONNECTION then
		MOUSE_TRACKING_CONNECTION = MOUSE_TRACKING_OBJECT.MouseMoved:Connect(function(x, y)
			print(x, y)
			MOUSE_X = x
			MOUSE_Y = y
		end)
	end
end

CREATE_HUB_NODE.Click:Connect(function()
	if CREATE_HUB_NODE_ENABLED then
		CREATE_HUB_NODE_ENABLED = false
		SHOW_NODES_ENABLED = false
		UNTRACK_MOUSE()

		if not SHOW_NODES_EXPLICITLY_ENABLED() then
			SHOW_NODES:SetActive(false)
			-- do cleanup stuff here
		end
	else
		CREATE_HUB_NODE_ENABLED = true
		CREATE_NODE_ENABLED = false
		SHOW_NODES_ENABLED = true

		CREATE_NODE:SetActive(false)
		SHOW_NODES:SetActive(true)
		TRACK_MOUSE()
	end

	CREATE_HUB_NODE:SetActive(CREATE_HUB_NODE_ENABLED)
end)

CREATE_NODE.Click:Connect(function()
	if CREATE_NODE_ENABLED then
		CREATE_NODE_ENABLED = false
		SHOW_NODES_ENABLED = false
		UNTRACK_MOUSE()

		if not SHOW_NODES_EXPLICITLY_ENABLED() then
			SHOW_NODES:SetActive(false)
		end
	else
		CREATE_HUB_NODE_ENABLED = false
		CREATE_NODE_ENABLED = true
		SHOW_NODES_ENABLED = true

		CREATE_HUB_NODE:SetActive(false)
		SHOW_NODES:SetActive(true)
		TRACK_MOUSE()
	end

	CREATE_NODE:SetActive(CREATE_NODE_ENABLED)
end)

SHOW_NODES.Click:Connect(function()
	if SHOW_NODES_EXPLICITLY_ENABLED() then
		SHOW_NODES_EXPLICITLY_ENABLED(false)
	else
		SHOW_NODES_EXPLICITLY_ENABLED(true)
	end

	SHOW_NODES:SetActive(SHOW_NODES_EXPLICITLY_ENABLED())
end)

do -- select web

	local function add_web_to_menu(folder: Folder, name: string, id: number)
		local action = SELECT_WEB_MENU:AddNewAction(tostring(id), name)
		action.Triggered:Connect(function()
			ON_WEB_SELECTED(folder)
			Selection:Set({ folder })
		end)
	end

	RunService.RenderStepped:Connect(function()
		if not SHOULD_RECOMPUTE_WEBS_MENU then
			return
		end

		if SELECT_WEB_MENU then
			SELECT_WEB_MENU:ClearAllChildren()
			SELECT_WEB_MENU:Destroy()
		end

		SELECT_WEB_MENU = plugin:CreatePluginMenu(SELECT_WEB_ID, nil, SELECT_WEB_ICON.Uri)
		local id = 0

		for name, folder_or_folders in LOADED_WEBS do
			if type(folder_or_folders) ~= "table" then
				add_web_to_menu(folder_or_folders, name, id)
				id += 1
			else
				for _, folder in folder_or_folders do
					add_web_to_menu(folder, name, id)
					id += 1
				end
			end
		end

		SELECT_WEB_MENU:AddSeparator()
		SELECT_WEB_MENU:AddAction(CREATE_WEB_FOLDER)
		SHOULD_RECOMPUTE_WEBS_MENU = false
	end)

	SELECT_WEB.Click:Connect(function()
		SELECT_WEB:SetActive(true)
		SELECT_WEB_MENU:ShowAsync()
		SELECT_WEB:SetActive(false)
	end)
end

CREATE_WEB_FOLDER.Triggered:Connect(function()
	local folder = Instance.new("Folder")
	folder.Name = DEFAULT_WEB_FOLDER_NAME
	folder:AddTag(WEB_TAG)
	folder.Parent = Workspace
	ChangeHistoryService:SetWaypoint("Create Web Folder")
	ON_WEB_SELECTED(folder)
	Selection:Set({ folder })
end)

do
	local last_selected_web = CollectionService:GetTagged(LAST_SELECTED_WEB_TAG)[1]

	if last_selected_web then
		CURRENT_WEB_FOLDER = last_selected_web :: Folder
	end

	local function on_last_selected_web_added(instance: Instance)
		if CURRENT_WEB_FOLDER ~= instance then
			instance:RemoveTag(LAST_SELECTED_WEB_TAG)
		end
	end

	local function on_web_added(instance: Instance): boolean
		if not instance:IsA("Folder") then
			warn("")
			return false
		end
		local old_name = instance.Name

		instance:GetPropertyChangedSignal("Name"):Connect(function()
			local new_name = instance.Name

			SHOULD_RECOMPUTE_WEBS_MENU = true
			UNLOAD_WEB(instance, old_name)
			LOAD_WEB(instance, new_name)
			old_name = new_name
		end)
		LOAD_WEB(instance, old_name)

		return true
	end

	CollectionService:GetInstanceAddedSignal(LAST_SELECTED_WEB_TAG):Connect(on_last_selected_web_added)
	CollectionService:GetInstanceAddedSignal(WEB_TAG):Connect(function(instance)
		local success = on_web_added(instance)

		if success then
			SHOULD_RECOMPUTE_WEBS_MENU = true
		end
	end)
	CollectionService:GetInstanceRemovedSignal(WEB_TAG):Connect(function(instance)
		UNLOAD_WEB(instance, instance.Name)
		SHOULD_RECOMPUTE_WEBS_MENU = true
	end)

	for _, instance in CollectionService:GetTagged(LAST_SELECTED_WEB_TAG) do
		on_last_selected_web_added(instance)
	end

	for _, instance in CollectionService:GetTagged(WEB_TAG) do
		on_web_added(instance)
	end
	SHOULD_RECOMPUTE_WEBS_MENU = true

	local screen_gui = Instance.new("ScreenGui")
	screen_gui.Name = plugtilly.name(plugin)
	screen_gui.Parent = CoreGui

	MOUSE_TRACKING_OBJECT = Instance.new("Frame")
	MOUSE_TRACKING_OBJECT.Name = "MouseTrackingGuiObject"
	MOUSE_TRACKING_OBJECT.Size = UDim2.fromScale(1, 1)
	MOUSE_TRACKING_OBJECT.Transparency = 1
	MOUSE_TRACKING_OBJECT.Active = false
	MOUSE_TRACKING_OBJECT.Parent = screen_gui

	plugin.Unloading:Connect(function()
		screen_gui:Destroy()
	end)
end
