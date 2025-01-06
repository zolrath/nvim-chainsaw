local M = {}
--------------------------------------------------------------------------------

---The config should map a filetype to a function that takes the node under
---the cursor and returns a number representing the shift in line number where
---the log statement should be inserted instead. For example, `-1` means to
---insert above the current line, and `0` means below the current line. If not
---return value is provided, will return below the current line.
---@type table<string, fun(node: TSNode): integer?>
M.ftConfig = {
	lua = function(node)
		local parent = node:parent()
		local grandparent = parent and parent:parent()
		if not parent or not grandparent then return end

		-- return statement
		local exprNode
		if parent:type() == "expression_list" then exprNode = parent end
		if grandparent:type() == "expression_list" then exprNode = grandparent end
		if exprNode and exprNode:parent() and exprNode:parent():type() == "return_statement" then
			return -1
		end

		-- multiline assignment
		if grandparent:type() == "assignment_statement" then
			local assignmentExtraLines = grandparent:end_() - grandparent:start()
			return assignmentExtraLines
		end
	end,
	javascript = function(node)
		local parent = node:parent()
		if not parent then return end

		-- return statement
		local inReturnStatement = parent:type() == "return_statement"
			or (parent:parent() and parent:parent():type() == "return_statement")
		if inReturnStatement then return -1 end

		-- multiline assignment
		local isAssignment = parent:type() == "variable_declarator"
			or parent:type() == "assignment_expression"
		if isAssignment then
			local assignmentExtraLines = parent:end_() - parent:start()
			return assignmentExtraLines
		end
	end,
	python = function(node)
		local parent = node:parent()
		if not parent then return end

		local grandparent = parent:parent()

		-- return statement
		local inReturnStatement = parent:type() == "return_statement"
			or (grandparent and grandparent:type() == "return_statement")
		if inReturnStatement then return -1 end

		-- need to check with statement next

		-- for statement with multiple lines
		if parent:type() == "for_statement" then
			local right = parent:field("right")[1]
			return (right:end_() - right:start()) - (node:start() - parent:start())
		end
		if grandparent and grandparent:type() == "for_statement" then
			local right = grandparent:field("right")[1]
			return (right:end_() - right:start()) - (node:start() - grandparent:start())
		end

		-- function parameters
		if parent:type() == "parameters" then
			return (parent:end_() - parent:start()) - (node:start() - parent:start())
		end
		if grandparent and grandparent:type() == "parameters" then
			return (grandparent:end_() - grandparent:start()) - (node:start() - grandparent:start())
		end

		-- multiline assignment
		-- traverse parent nodes until we encounter the surrounding expression_statement
		local expression_root = node:parent()
		while expression_root do
			if expression_root:type() == "expression_statement" then
				local assignmentExtraLines = (expression_root:end_() - expression_root:start())
					- (node:start() - expression_root:start())
				return assignmentExtraLines
			end
			expression_root = expression_root:parent()
		end
	end,
}

require("chainsaw.config.config").supersetInheritance(M.ftConfig)

--------------------------------------------------------------------------------
return M
