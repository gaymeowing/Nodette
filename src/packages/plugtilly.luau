
--[[
	plugtilly
	roblox plugin utility
]]

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local RunService = game:GetService("RunService")

export type FinishRecording = (operation: Enum.FinishRecordingOperation, options: {}?) -> ()

export type DockWidgetPluginGuiInfo = {
	initally_enabled_should_override_restore: boolean,
	inital_dock_state: Enum.InitialDockState,
	initally_enabled: boolean,
	inital_size: vector,
	min_size: vector?,
	title: string?,
}

export type ToggledCallback = (toggled: boolean, is_from_click: true?) -> ()

type PluginToggleButtonPrototype = {
	on_click: (plugin_toggle_button: PluginToggleButton, f: () -> ()) -> RBXScriptConnection,
	on_toggle: (plugin_toggle_button: PluginToggleButton, f: ToggledCallback) -> (() -> ()),
	toggle: (plugin_toggle_button: PluginToggleButton, new_state: boolean) -> (),
	__index: PluginToggleButtonPrototype
}

export type PluginToggleButton = setmetatable<{
	read callbacks: { ToggledCallback },
	read instance: PluginToolbarButton,
	toggled: boolean,
}, PluginToggleButtonPrototype>

export type PluginInterfaceInfo = {
	clickable_when_viewport_hidden: boolean?,
	enabled: boolean?,
	--[[
		The text to be displayed as a tooltip for the PluginToolbarButton, and as the statusTip for the PluginAction
	]]
	tooltip: string,
	icon: Content,
	name: string?,
	id: string,
}

export type PluginInterfaceActionInfo = PluginInterfaceInfo & {
	allow_binding: boolean?,
	icon_name: string?,
}

export type Setting<V> = (value: V?) -> V

local function SWAP_REMOVE<V>(t: { V }, v: V)
	local index = table.find(t, v)

	if index then
		if index ~= #t then
			t[index] = t[#t]
		end
		t[#t] = nil
	end
end

local plugin_toggle_button_prototype = {} :: PluginToggleButtonPrototype
plugin_toggle_button_prototype.__index = plugin_toggle_button_prototype

function plugin_toggle_button_prototype.toggle(plugin_toggle_button, new_state)
	plugin_toggle_button.instance:SetActive(new_state)
	plugin_toggle_button.toggled = new_state

	for _, f in plugin_toggle_button.callbacks do
		f(new_state)
	end
end

function plugin_toggle_button_prototype.on_toggle(plugin_toggle_button, f)
	local callbacks = plugin_toggle_button.callbacks
	table.insert(callbacks, f)

	return function()
		SWAP_REMOVE(callbacks, f)
	end
end

function plugin_toggle_button_prototype.on_click(plugin_toggle_button, f)
	return plugin_toggle_button.instance.Click:Connect(f)
end

local function UNPACK_INTERFACE_INFO(info: PluginInterfaceInfo): (string, string, string, string, boolean)
	local enabled = info.enabled
	local id = info.id

	return id, info.tooltip, info.icon.Uri :: string, info.name or id,
		if enabled ~= nil then enabled else true
end

local function CREATE_TOOLBAR_BUTTON(
	toolbar: PluginToolbar, id: string, tooltip: string, icon: string,
	name: string, enabled: boolean, info: PluginInterfaceInfo
): PluginToolbarButton
	local button = toolbar:CreateButton(id, tooltip, icon, name)

	if info.clickable_when_viewport_hidden then
		button.ClickableWhenViewportHidden = true
	end

	button.Enabled = enabled
	return button
end

--[[
	Gives the actual name of the plugin, as plugins that are loaded in via
	the plugins folder have "user_" appended to the beginning and ".rbxm" or ".rbxmx"
 	appended at the end of their instance name.

	Also replaces dashes in the name with spaces, because of how some operating systems
	don't allow spaces in file names. So "user_PBR-Surface-Applier.rbxm" becomes "PBR Surface Applier".
]]
local function GET_NAME(plugin: Plugin): string
	local name = plugin.Name

	if string.sub(name, 1, 5) == "user_" then
		local extention_start = string.find(name, ".", 1, true) :: number
		name = string.sub(name, 6, #name - (#name - extention_start + 1))
	end

	return (string.gsub(name, "%-", " "))
end

local plugtilly = {
	name = GET_NAME,
}

--[[
	Wrapper for Plugin:CreateDockWidgetPluginGui() that instead uses a table for info,
	and also will automatically set the name of the DockWidgetPluginGui based on the plugins name
	and the title if provided in the info table.
	It also sets the DockWidgetPluginGui to have the ZIndexBehavior of Sibling, and to not ResetOnSpawn.
]]
function plugtilly.create_dock_widget_plugin_gui(
	plugin: Plugin, id: string, info: DockWidgetPluginGuiInfo
): DockWidgetPluginGui
	local plugin_name = GET_NAME(plugin)
	local inital_size = info.inital_size
	local min_size = info.min_size or inital_size
	local title = info.title

	local gui = plugin:CreateDockWidgetPluginGui(
		id, DockWidgetPluginGuiInfo.new(
			info.inital_dock_state, info.initally_enabled,
			info.initally_enabled_should_override_restore,
			inital_size.x, inital_size.y,
			min_size.x, min_size.y
		)
	)

	if title then
		gui.Name = `{plugin_name} "{title}"`
		gui.Title = title
	else
		gui.Title = plugin_name
		gui.Name = plugin_name
	end

	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.ResetOnSpawn = false
	return gui
end

--[[
	Wrapper around Plugin:GetSetting() and Plugin:SetSetting(),
	that gives single function that when called it'll give you the current setting value,
	and calling it with an argument will also set the setting.
]]
function plugtilly.place_setting<V>(plugin: Plugin, key: string, default: V): Setting<V>
	-- don't save for places that have no place id
	if game.PlaceId == 0 then
		local value = default

		return function(...)
			if select("#", ...) ~= 0 then
				value = select(1, ...)
			end

			return value
		end
	end

	local setting_values = plugin:GetSetting(key) :: { [string]: V }
	local string_place_id = tostring(game.PlaceId)

	if setting_values then
		if setting_values[string_place_id] == nil then
			setting_values[string_place_id] = default
			plugin:SetSetting(key, setting_values)
		end
	else
		plugin:SetSetting(key, {
			[string_place_id] = default
		})
	end

	return function(...)
		if select("#", ...) ~= 0 then
			-- the or is here incase someone edits the json file studio keeps for plugin settings
			local value_per_place = (plugin:GetSetting(key) or {}) :: { [string]: V }
			local value = select(1, ...)
			value_per_place[string_place_id] = value
			plugin:SetSetting(key, value_per_place)
			return value
		end

		return plugin:GetSetting(key)[string_place_id]
	end
end

--[[
	Wrapper around Plugin:GetSetting() and Plugin:SetSetting(),
	that gives single function that when called it'll give you the current setting value,
	and calling it with an argument will also set the setting.
]]
function plugtilly.setting<V>(plugin: Plugin, key: string, default: V): Setting<V>
	if plugin:GetSetting(key) == nil then
		plugin:SetSetting(key, default)
	end

	return function(...)
		if select("#", ...) ~= 0 then
			local value = select(1, ...)
			plugin:SetSetting(key, value)
			return value
		end

		return plugin:GetSetting(key)
	end
end

function plugtilly.create_toolbar_toggle_button(
	plugin: Plugin, toolbar: PluginToolbar, info: PluginInterfaceActionInfo & { toggled: boolean? }
): PluginToggleButton
	local id, tooltip, icon, name, enabled = UNPACK_INTERFACE_INFO(info)
	local toolbar_button = CREATE_TOOLBAR_BUTTON(toolbar, id, tooltip, icon, name, enabled, info)
	local callbacks = {} :: { ToggledCallback }
	local toggled = info.toggled or false
	local toggle_button = setmetatable({
		instance = toolbar_button,
		callbacks = callbacks,
		toggled = toggled,
	}, plugin_toggle_button_prototype)

	toolbar_button.Click:Connect(function()
		local toggled = not toggle_button.toggled
		toolbar_button:SetActive(toggled)
		toggle_button.toggled = toggled

		for _, f in callbacks do
			f(toggled, true)
		end
	end)

	if toggled then
		toolbar_button:SetActive(true)
	end

	return toggle_button
end

function plugtilly.create_toolbar_button(
	plugin: Plugin, toolbar: PluginToolbar, info: PluginInterfaceActionInfo
): PluginToolbarButton
	local id, tooltip, icon, name, enabled = UNPACK_INTERFACE_INFO(info)
	return CREATE_TOOLBAR_BUTTON(toolbar, id, tooltip, icon, name, enabled, info)
end

function plugtilly.create_menu_button(
	plugin: Plugin, toolbar: PluginToolbar, info: PluginInterfaceInfo
): PluginMenuButton
	local id, tooltip, icon, name, enabled = UNPACK_INTERFACE_INFO(info)
	local button = CREATE_TOOLBAR_BUTTON(toolbar, id, tooltip, icon, name, enabled, info)
	local menu = plugin:CreatePluginMenu(id, name, icon)

	button.Click:Connect(function()
		menu:ShowAsync()
	end)

	return table.freeze(setmetatable({
		button = button,
		menu = menu,
	}, plugin_menu_button_prototype)) :: any
end

function plugtilly.try_create_recording(
	plugin: Plugin, action_name: string, display_name: string?
): FinishRecording?
	local identifier = ChangeHistoryService:TryBeginRecording(action_name, display_name)

	if not identifier then
		local name = GET_NAME(plugin)

		if RunService:IsEdit() then
			warn(`[{name}]: Could not start recording changes for action '{action_name or display_name}'`)
		else
			warn(`[{name}]: Cannot do action '{action_name or display_name}' during a playtest.`)
		end
		return nil
	end

	return function(operation, options)
		ChangeHistoryService:FinishRecording(identifier :: any, operation, options :: any)
	end
end


function plugtilly.create_recording(plugin: Plugin, action_name: string, display_name: string?): FinishRecording
	local identifier = ChangeHistoryService:TryBeginRecording(action_name, display_name)

	if not identifier then
		local name = GET_NAME(plugin)

		if RunService:IsEdit() then
			error(`[{name}]: Could not start recording changes for action '{display_name or action_name}'`, 2)
		else
			error(`[{name}]: Cannot do action '{display_name or action_name}' during a playtest.`, 2)
		end
	end

	return function(operation, options)
		ChangeHistoryService:FinishRecording(identifier :: any, operation, options :: any)
	end
end

return table.freeze(plugtilly)
