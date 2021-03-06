--[[
    lama is a MUD server made in Lua.
    Copyright (C) 2013 Curtis Erickson

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

--- Extension of the table library.
-- @author milkmanjack
module("ext.table", package.seeall)

--- Provides a hard copy of a table, meaning all indexes within the table are copied.
-- @param t Table to copy.
-- @return A hard copy of the given table.
function table.copy(t)
	local c = {}
	for i,v in pairs(t) do
		c[i] = v
	end

	return c
end

--- Removes a value from a table as opposed to an index.
-- @param t Table to be modified.
-- @param value Value to be removed.
-- @return true on successful removal.<br/>false otherwise.
function table.removeValue(t, value)
	for i,v in pairs(t) do
		if v == value then
			table.remove(t, i)
			return true
		end
	end

	return false
end

--- Converts the members of a table into a string, using tostring()
-- to convert the individual members, placing delimiters between
-- each member.
-- @param t Table to be converted.
-- @param delimiter Delimiter placed between each value in the table.
-- @return String form of the table.
function table.tostring(t,delimiter)
	delimiter	= delimiter or ","

	-- empty table?
	local first	= next(t)
	if not first then
		return ""
	end

	-- one entry table?
	local second = next(t, first)
	if not second then
		return tostring(t[first])
	end

	-- unique iterator that starts at the second entry
	local iterator = function()
		local i = second
		return function()
			local index, value = i, t[i]
			i = next(t, i)
			return index, value
		end
	end

	-- generate the rest of the string
	local msg = tostring(t[first])
	for i,v in iterator() do
		msg = string.format("%s%s%s", msg, delimiter, tostring(v))
	end

	return msg
end