
--[[
	is interacting with ribbon tools
	detects if the user is interacting with the ribbon tools (move, rotate, transform, scale)
]]

local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local on_gui_state_changed = require("./on_gui_state_changed")

local DRAGGER_GUI = CoreGui:WaitForChild("DraggerUI")
local IS_INTERACTING_WITH_RIBBON_TOOLS = false
local SELECTED_RIBBON_TOOL: Enum.RibbonTool
local HAS_ImplementationUI1 = false
local PLUGIN: Plugin

local function is_interacting_with_ribbon_tools(plugin: Plugin): boolean
	PLUGIN = plugin
	return IS_INTERACTING_WITH_RIBBON_TOOLS
end

local function is_ImplementationUI1(instance: Instance): boolean
	return instance:IsA("Folder") and instance.Name == "ImplementationUI1"
end

DRAGGER_GUI.ChildRemoved:Connect(function(child)
	if is_ImplementationUI1(child) then
		HAS_ImplementationUI1 = false
	end

	if SELECTED_RIBBON_TOOL == Enum.RibbonTool.Select then

	else

	end
end)

DRAGGER_GUI.ChildAdded:Connect(function(child)
	if is_ImplementationUI1(child) then
		HAS_ImplementationUI1 = true
	end

	if SELECTED_RIBBON_TOOL == Enum.RibbonTool.Select then

	else


	end
end)

RunService.RenderStepped:Connect(function()
	if PLUGIN then
		SELECTED_RIBBON_TOOL = PLUGIN:GetSelectedRibbonTool()
	end
end)

return is_interacting_with_ribbon_tools
