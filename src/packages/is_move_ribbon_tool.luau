
--[[
	is move ribbon tool
	indicates if the provided ribbon tool is a move tool
]]

local function is_move_ribbon_tool(ribbon_tool: Enum.RibbonTool): boolean
	return ribbon_tool == Enum.RibbonTool.Rotate or
		ribbon_tool == Enum.RibbonTool.Select or
		ribbon_tool == Enum.RibbonTool.Scale or
		ribbon_tool == Enum.RibbonTool.Move
end

return is_move_ribbon_tool
