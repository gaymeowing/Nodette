
--[[
	on gui state changed
	wrapper around GuiObject:GetPropertyChangedSignal("GuiState"):Connect()
]]

local function on_gui_state_changed(
	gui_object: GuiObject,
	f: (gui_object: GuiObject, new_gui_state: Enum.GuiState) -> ()
): RBXScriptConnection
	return gui_object:GetPropertyChangedSignal("GuiObject"):Connect(function()
		f(gui_object, gui_object.GuiState)
	end)
end

return on_gui_state_changed
