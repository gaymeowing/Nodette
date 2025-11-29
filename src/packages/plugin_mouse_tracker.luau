
--[[
	plugin mouse tracker
	utility for tracking the position of the plugin mouse without using a PluginMouse
]]

local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local StudioService = game:GetService("StudioService")

type GizmoRaycastResult = typeof(StudioService.GizmoRaycast({} :: any, Vector3.one, Vector3.one))

type RaycastResult = typeof(Workspace.Raycast({} :: any, Vector3.one, Vector3.one))

type TrackerGui = ScreenGui & {
	TrackingGuiObject: Frame,
}

local PLUGINS_WITH_UNLOADING_CONNECTIONS = {} :: { [Plugin]: true? }
local TOTAL_TRACKING_ATTRIBUTE_NAME = "TotalLoadedPluginsTracking"
local SCREEN_GUI_NAME = "PluginMousePositionTrackerGui"
local MOUSE_TRACKING_CONNECTION: RBXScriptConnection?
local GUI_OBJECT_NAME = "TrackingGuiObject"
local SCREEN_GUI: ScreenGui
local GUI_OBJECT: GuiObject
local MOUSE_X = 0
local MOUSE_Y = 0

local function GET_RAY_FOR_POSITION(camera: Camera, depth: number?): Ray
	if not MOUSE_TRACKING_CONNECTION then
		error("[PLUGIN MOUSE POSITION]: Cannot call get whilst not tracking")
	end
	return camera:ScreenPointToRay(MOUSE_X, MOUSE_Y, depth)
end

local function cast_into_world(
	viewport_frame_or_params: ViewportFrame | RaycastParams,
	params_or_depth: RaycastParams | number?,
	depth: number?
): RaycastResult
	if (not viewport_frame_or_params) or typeof(viewport_frame_or_params) == "RaycastParams" then
		local ray = GET_RAY_FOR_POSITION(Workspace.CurrentCamera, params_or_depth :: any)
		return Workspace:Raycast(ray.Origin, ray.Direction * 15_000, viewport_frame_or_params)
	else
		local world_root = viewport_frame_or_params:FindFirstChildWhichIsA("WorldRoot")

		if not world_root then
			warn("[PLUGIN MOUSE TRACKER]: ViewportFrame", viewport_frame_or_params, "doesnt have a child which is a WorldRoot")
			error("[PLUGIN MOUSE TRACKER]: An error occured, please see previous warning for details")
		end
		local ray = GET_RAY_FOR_POSITION(viewport_frame_or_params.CurrentCamera, depth :: any)
		return world_root:Raycast(ray.Origin, ray.Direction * 15_000, params_or_depth :: any)
	end
end

local plugin_mouse_tracker = {
	cast_into_world = cast_into_world :: ((params: RaycastParams?, depth: number?) -> RaycastResult)
		& ((viewport_frame: ViewportFrame, params: RaycastParams?, depth: number?) -> RaycastResult)
}

function plugin_mouse_tracker.get_ray_for_position(camera: Camera?, depth: number?): Ray
	return GET_RAY_FOR_POSITION(camera or Workspace.CurrentCamera, depth)
end

function plugin_mouse_tracker.gizmo_cast(params: RaycastParams?, depth: number?): GizmoRaycastResult
	local ray = GET_RAY_FOR_POSITION(Workspace.CurrentCamera, depth)
	return StudioService:GizmoRaycast(ray.Origin, ray.Direction * 15_000, params)
end

function plugin_mouse_tracker.untrack_position()
	if not MOUSE_TRACKING_CONNECTION then
		error("[PLUGIN MOUSE TRACKER]: Cannot call untrack_position when not tracking mouse position")
	end
	MOUSE_TRACKING_CONNECTION:Disconnect()
	MOUSE_TRACKING_CONNECTION = nil
end

function plugin_mouse_tracker.track_position(plugin: Plugin)
	if MOUSE_TRACKING_CONNECTION then
		error("[PLUGIN MOUSE TRACKER]: Cannot call track_position whilst already tracking mouse position")
	end

	if not PLUGINS_WITH_UNLOADING_CONNECTIONS[plugin] then
		PLUGINS_WITH_UNLOADING_CONNECTIONS[plugin] = true
		plugin.Unloading:Connect(function()
			local amount_of_plugins_tracking = SCREEN_GUI:GetAttribute(TOTAL_TRACKING_ATTRIBUTE_NAME)

			if amount_of_plugins_tracking == 1 then
				SCREEN_GUI:Destroy()
			end
			PLUGINS_WITH_UNLOADING_CONNECTIONS[plugin] = nil
		end)
	end

	MOUSE_TRACKING_CONNECTION = GUI_OBJECT.MouseMoved:Connect(function(x, y)
		MOUSE_X = x
		MOUSE_Y = y
	end)
end

function plugin_mouse_tracker.on_click(f: () -> ()): RBXScriptConnection
	return GUI_OBJECT:GetPropertyChangedSignal("GuiState"):Connect(function()
		if GUI_OBJECT.GuiState == Enum.GuiState.Press then
			f()
		end
	end)
end

function plugin_mouse_tracker.is_tracking_position(): boolean
	return MOUSE_TRACKING_CONNECTION ~= nil
end

function plugin_mouse_tracker.get_position(): (number, number)
	if not MOUSE_TRACKING_CONNECTION then
		error("[PLUGIN MOUSE TRACKER]: Cannot call get_position whilst not tracking")
	end
	return MOUSE_X, MOUSE_Y
end

do

	SCREEN_GUI = CoreGui:FindFirstChild(SCREEN_GUI_NAME) :: any

	if SCREEN_GUI then
		SCREEN_GUI = SCREEN_GUI
		GUI_OBJECT = SCREEN_GUI.TrackingGuiObject
		local total_plugins_tracking = SCREEN_GUI:GetAttribute(TOTAL_TRACKING_ATTRIBUTE_NAME)

		if total_plugins_tracking then
			SCREEN_GUI:SetAttribute(TOTAL_TRACKING_ATTRIBUTE_NAME, total_plugins_tracking + 1)
		else
			SCREEN_GUI:SetAttribute(TOTAL_TRACKING_ATTRIBUTE_NAME, 1)
		end
	else
		SCREEN_GUI = Instance.new("ScreenGui")
		SCREEN_GUI:SetAttribute(TOTAL_TRACKING_ATTRIBUTE_NAME, 1)
		SCREEN_GUI.ZIndexBehavior = Enum.ZIndexBehavior.Global
		SCREEN_GUI.ScreenInsets = Enum.ScreenInsets.None
		SCREEN_GUI.ClipToDeviceSafeArea = false
		SCREEN_GUI.DisplayOrder = -math.huge
		SCREEN_GUI.Name = SCREEN_GUI_NAME
		SCREEN_GUI.ResetOnSpawn = false

		GUI_OBJECT = Instance.new("Frame")
		GUI_OBJECT.Size = UDim2.fromScale(1, 1)
		GUI_OBJECT.BackgroundTransparency = 1
		GUI_OBJECT.Name = GUI_OBJECT_NAME
		GUI_OBJECT.ZIndex = -math.huge
		GUI_OBJECT.Interactable = true
		GUI_OBJECT.Active = false
		GUI_OBJECT.Parent = SCREEN_GUI
		SCREEN_GUI.Parent = CoreGui
	end

end

return table.freeze(plugin_mouse_tracker)
