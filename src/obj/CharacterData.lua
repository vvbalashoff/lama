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

--- Cloneable that holds data for characters.
-- @author milkmanjack
module("obj.CharacterData", package.seeall)

local Cloneable			= require("obj.Cloneable")

--- Contains character data for mobs.
-- @class table
-- @name CharacterData
-- @field password Character's password.
local CharacterData		= Cloneable.clone()

-- character settings
CharacterData.password	= nil

return CharacterData
