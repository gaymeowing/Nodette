
local PluginDebugService = game:GetService("PluginDebugService")
local CollectionService = game:GetService("CollectionService")
local StudioService = game:GetService("StudioService")
local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")
local Workspace = game:GetService("Workspace")
local is_interacting_with_ribbon_tools = require("./packages/is_interacting_with_ribbon_tools")
local is_move_ribbon_tool = require("./packages/is_move_ribbon_tool")
local plugin_mouse_tracker = require("./packages/plugin_mouse_tracker")
local plugtilly = require("./packages/plugtilly")

local SHOW_NODES_EXPLICITLY_ENABLED = plugtilly.place_setting(plugin, "ShowNodesEnabled", false)
local TOOLBAR = plugin:CreateToolbar(plugtilly.name(plugin))
local SELECT_WEB_ICON = Content.fromAssetId(78705581677742)
local CREATE_WEB_ID = "Create Web Folder"
local SELECT_WEB_ID = "Select Web"
local CREATE_NODE = plugtilly.create_toolbar_toggle_button(plugin, TOOLBAR, {
	id = "Create Node",
	tooltip = "Creates a new node",
	icon = Content.fromAssetId(78705581677742),
})
local CREATE_HUB_NODE = plugtilly.create_toolbar_toggle_button(plugin, TOOLBAR, {
	id = "Create Hub Node",
	tooltip = "Creates a new multi-node",
	icon = Content.fromAssetId(78705581677742),
})
local SELECT_WEB = plugtilly.create_toolbar_button(plugin, TOOLBAR, {
	id = SELECT_WEB_ID,
	tooltip = "Opens a menu to select the node web to be edited",
	icon = SELECT_WEB_ICON,
})
local SHOW_NODES = plugtilly.create_toolbar_toggle_button(plugin, TOOLBAR, {
	id = "Show Nodes",
	tooltip = "Shows node map visuals",
	icon = Content.fromAssetId(78705581677742),
	toggled = SHOW_NODES_EXPLICITLY_ENABLED(),
})
local CREATE_WEB_FOLDER = plugin:CreatePluginAction(
	CREATE_WEB_ID,
	CREATE_WEB_ID,
	"Creates a new Node Web Folder parented to Workspace and selects it",
	Content.fromAssetId(78705581677742).Uri,
	true
)
local SELECT_WEB_MENU: PluginMenu

local LAST_SELECTED_WEB_TAG = `__NODETTE_LAST_SELECTED_WEB USER({StudioService:GetUserId()})`
local NODE_PART_TO_HANDLES = {} :: { [BasePart]: { HandleAdornment } }
local LOADED_WEBS = {} :: { [string]: Folder | { Folder } }
local IS_DEBUGGING = plugin.Parent == PluginDebugService
local ON_CLICK_CONNECTION: RBXScriptConnection
local SHOULD_RECOMPUTE_WEBS_MENU = false
local DEFAULT_WEB_FOLDER_NAME = "Nodes"
local CURRENT_WEB_FOLDER: Folder
local WEB_TAG = "__NODETTE_WEB"

local function CREATE_NODE_PART(cframe: CFrame): BasePart
	local node = Instance.new("Part")

	if not IS_DEBUGGING then
		node.Transparency = 1
	end

	node.BottomSurface = Enum.SurfaceType.Smooth
	node.TopSurface = Enum.SurfaceType.Smooth
	node.Size = vector.one :: any
	node.CFrame = cframe
	node.Anchored = true
	node.Name = "Node"
	node.Parent = CURRENT_WEB_FOLDER
	return node
end

local function SNAP_POSITION_TO_GRID(position: vector, grid_size: number): vector
	local divided_position = position // grid_size

	return (divided_position * grid_size) + vector.create(0.5, 0.5, 0.5)
end

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
	if plugin_mouse_tracker.is_tracking_position() and not (CREATE_HUB_NODE.toggled and CREATE_NODE.toggled) then
		plugin_mouse_tracker.untrack_position()
	end
end

local function TRACK_MOUSE()
	if not plugin_mouse_tracker.is_tracking_position() then
		plugin_mouse_tracker.track_position(plugin)
	end
end

local function on_node_creator_clicked(button: plugtilly.PluginToggleButton, f: () -> ())
	local other_button = if button == CREATE_NODE then CREATE_HUB_NODE else CREATE_NODE

	button:on_toggle(function(toggled)
		if toggled then
			if other_button.toggled then
				other_button:toggle(false)
			end

			-- activating and reactivating to disable anything besides the move ribbon tools from also being selected
			local selected_ribbon_tool = plugin:GetSelectedRibbonTool()
			plugin:Activate(true)
			plugin:Deactivate()

			if is_move_ribbon_tool(selected_ribbon_tool) then
				plugin:SelectRibbonTool(selected_ribbon_tool, UDim2.new())
			end

			ON_CLICK_CONNECTION = plugin_mouse_tracker.on_click(f)
			TRACK_MOUSE()
		else
			if not SHOW_NODES_EXPLICITLY_ENABLED() then
				SHOW_NODES:toggle(false)
			end

			ON_CLICK_CONNECTION:Disconnect()
			UNTRACK_MOUSE()
		end
	end)
end

on_node_creator_clicked(CREATE_HUB_NODE, function()
	-- aaa
end)

on_node_creator_clicked(CREATE_NODE, function()
	if not CURRENT_WEB_FOLDER then
		warn("[NODETTE]: Cannot create nodes without a Web Folder selected")
		return
	end
	local result = plugin_mouse_tracker.cast_into_world()

	if not result then
		return
	end

	if is_interacting_with_ribbon_tools(plugin) then
		return
	end
	local result_instance = result.Instance

	if table.find(Selection:Get(), result_instance) then
		return
	end

	local stop_recording = plugtilly.create_recording(plugin, "Create Node")
	CREATE_NODE_PART(CFrame.new(SNAP_POSITION_TO_GRID(result.Position :: any, StudioService.GridSize) :: any))
	stop_recording(Enum.FinishRecordingOperation.Commit)
end)

SHOW_NODES:on_toggle(function(toggled, is_from_click)
	if is_from_click then
		SHOW_NODES_EXPLICITLY_ENABLED(toggled)
	end
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
	local stop_recording = plugtilly.create_recording(plugin, "Create Web Folder")
	local folder = Instance.new("Folder")
	folder.Name = DEFAULT_WEB_FOLDER_NAME
	folder:AddTag(WEB_TAG)
	folder.Parent = Workspace
	stop_recording(Enum.FinishRecordingOperation.Commit)
	ON_WEB_SELECTED(folder)
	Selection:Set({ folder })
end)

do -- web handling

	local last_selected_webs = CollectionService:GetTagged(LAST_SELECTED_WEB_TAG)
	local last_selected_web = last_selected_webs[1]

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
			warn("[NODETTE]: Cannot add", instance, "as a Web Folder because it is not a 'Folder'")
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

	for _, instance in last_selected_webs do
		on_last_selected_web_added(instance)
	end

	for _, instance in CollectionService:GetTagged(WEB_TAG) do
		on_web_added(instance)
	end
	SHOULD_RECOMPUTE_WEBS_MENU = true

	is_interacting_with_ribbon_tools(plugin)

end
