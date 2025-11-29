
--[[
	is interacting with ribbon tools
	detects if the user is interacting with the ribbon tools (move, rotate, transform, scale)
]]

local CoreGui = game:GetService("CoreGui")

local DRAGGER_ImplementationUI1_NAME = "ImplementationUI1"
-- when hovering over an instance the dragger creates a Highlight instance named "Outline"
local DRAGGER_Outline_NAME = "Outline"
-- DraggerUI is a folder created by studio for holding the adornments used to display the dragger
local DRAGGER_UI_NAME = "DraggerUI"
-- converting to hex strings because comparing color3s directly leads to floating point issues
-- and im lazy
local SELECTED_Z_COLOR = Color3.fromRGB(38, 38, 255):ToHex()
local SELECTED_X_COLOR = Color3.fromRGB(255, 0, 0):ToHex()
local SELECTED_Y_COLOR = Color3.fromRGB(0, 255, 0):ToHex()
local IS_INTERACTING_WITH_RIBBON_TOOLS = false

local function is_interacting_with_ribbon_tools(plugin: Plugin): boolean
	local selected_ribbon_tool = plugin:GetSelectedRibbonTool()

	if selected_ribbon_tool == Enum.RibbonTool.None then
		IS_INTERACTING_WITH_RIBBON_TOOLS = false
		return false
	end
	local dragger_ui = CoreGui:FindFirstChild(DRAGGER_UI_NAME)

	if dragger_ui then
		local outline = dragger_ui:FindFirstChild(DRAGGER_Outline_NAME)

		if outline then
			IS_INTERACTING_WITH_RIBBON_TOOLS = true
		else
			local implementation_folder = dragger_ui:FindFirstChild(DRAGGER_ImplementationUI1_NAME)

			if implementation_folder then
				local didnt_break = true

				for _, adornment in implementation_folder:QueryDescendants("PVAdornment") :: { PVAdornment } do
					local adornment_color = adornment.Color3:ToHex()

					if
						adornment_color == SELECTED_X_COLOR or
						adornment_color == SELECTED_Y_COLOR or
						adornment_color == SELECTED_Z_COLOR
					then
						IS_INTERACTING_WITH_RIBBON_TOOLS = true
						didnt_break = false
						break
					end
				end

				if didnt_break then
					IS_INTERACTING_WITH_RIBBON_TOOLS = false
				end
			else
				IS_INTERACTING_WITH_RIBBON_TOOLS = dragger_ui:FindFirstChild(DRAGGER_UI_NAME) ~= nil
			end
		end
	else
		IS_INTERACTING_WITH_RIBBON_TOOLS = true
	end

	return IS_INTERACTING_WITH_RIBBON_TOOLS
end

return is_interacting_with_ribbon_tools
