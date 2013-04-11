--- Cloneable that is used to represent objects on a Map.
-- @author milkmanjack
module("obj.MapObject", package.seeall)

local Cloneable	= require("obj.Cloneable")

--- Cloneable that is used to represent objects on a Map.
-- @class table
-- @name MapObject
-- @field name Name of the MapObject.
-- @field description Complete description of the MapObject.
-- @field map Map that the MapObject is a part of.
-- @field loc MapObject that the MapObject inhabits.
local MapObject	= Cloneable.clone()

-- mapobject settings
MapObject.name			= "mapobject"
MapObject.description	= "a map object"

-- runtime data
MapObject.map		= nil -- the map we are a part of
MapObject.loc		= nil -- the MapObject we're located in/on (usually a MapTile, but can be a MapObject too)

--- Contains all of the MapObjects inhabiting this MapObject.
-- @class table
-- @name MapObject.contents
MapObject.contents	= nil -- things contained within a mapobject

--- Creates a unique contents table per MapObject.
-- Also has the potential to assign a Map and MapObject location to move the
-- MapObject to.
-- @param map Map to be moved to.
-- @param loc MapObject loc to be moved to.
function MapObject:initialize(map,loc)
	self.contents = {}
	if map then
		self:moveToMap(map)
	end

	if loc then
		self:setLoc(loc)
	end
end

--- String identifier for this mob.
-- @return Returns a string in format of "&lt;MapObject's name&gt;".
function MapObject:toString()
	return self.name
end

--- Moves a MapObject into a Map.
-- @param map The map to be moved to.
function MapObject:moveToMap(map)
	local oldMap = self.map
	self.map = map

	-- mutuality
	if oldMap and oldMap:contains(self) then
		-- our current location cannot be in the old map.
		-- if it is, clear it.
		if self:getLoc():getMap() == oldMap then
			self:setLoc(nil)
		end

		oldMap:removeFromContents(self)
	end

	-- mutuality
	if map and not map:contains(self) then
		map:addToContents(self)
	end
end

--- Attempts to make a MapObject step into a new tile in the given direction.
-- Uses move() to actuall do the moving, so it does respect MapObject:permitEntrance(self).
-- @param direction Direction to move in. Always a member of the Direction table.
-- @return true on successful step.<br/>false otherwise.
function MapObject:step(direction)
	local newLoc = self.map:getStep(self, direction)
	if newLoc then
		return self:move(newLoc)
	end

	return false
end

--- Respects result of permitEntrance before setting location directly.
-- @param mapObject MapObject to be moved into.
-- @return true on successful move.<br/>false otherwise.
function MapObject:move(mapObject)
	if not mapObject:permitEntrance(self) then
		return false
	end

	self:setLoc(mapObject)
	return true
end

--- Directly assigns a new location to the MapObject.
-- @param mapObject MapObject to be our new location.
function MapObject:setLoc(mapObject)
	local oldLoc = self:getLoc()
	self.loc = mapObject

	-- mutuality
	if oldLoc and oldLoc:contains(self) then
		oldLoc:removeFromContents(self)
	end

	-- mutuality
	if mapObject and not mapObject:contains(self) then
		mapObject:addToContents(self)
		local targetMap = mapObject:getMap()
		if self:getMap() ~= targetMap then
			self:moveToMap(targetMap)
		end
	end
end

--- Attempts to set our location to the tile at the XYZ location.
-- @param x
-- @param y
-- @param z
function MapObject:setXYZLoc(x,y,z)
	local tile = self.map:getTile(x,y,z)
	if not tile then
		self:setLoc()
  else
    self:setLoc(tile)
  end
end

--- Check if this MapObject will perment the given MapObject to enter.
-- @param mapObject MapObject to check eligiblity of.
-- @param true on permitted entrance.<br/>false otherwise.
function MapObject:permitEntrance(mapObject)
	return true
end

--- Fires when a MapObject is added to our contents.
-- @param mapObject MapObject added to our contents.
function MapObject:onEnter(mapObject)
end

-- Check if a MapObject is in our contents.
-- @param mapObject MapObject we might be containing.
-- @return true if we contain the given MapObject.<br/>false otherwise.
function MapObject:contains(mapObject)
	for i,v in ipairs(self.contents) do
		if v == mapObject then
			return true
		end
	end

	return false
end

--- Adds a MapObject to our contents and fires self:onEnter(mapObject).
-- @param mapObject MapObject to be added to our contents.
function MapObject:addToContents(mapObject)
	table.insert(self.contents, mapObject)

	-- mutuality
	if mapObject:getLoc() ~= self then
		mapObject:setLoc(self)
	end

	self:onEnter(mapObject)
end

--- Removes a MapObject from our contents.
-- @param mapObject MapObject to be removed from our contents.
function MapObject:removeFromContents(mapObject)
	for i,v in ipairs(self.contents) do
		if v == mapObject then
			table.remove(self.contents, i)
		end
	end

	-- mutuality
	if mapObject:getLoc() == self then
		mapObject:setLoc(nil)
	end
end

--- Assign a name.
-- @param name Name to assign.
function MapObject:setName(name)
	self.name = name
end

--- Assign a description.
-- @param description Descrition to assign.
function MapObject:setDescription(description)
	self.description = description
end

--- Get current name.
-- @return Current name.
function MapObject:getName()
	return self.name
end

--- Get current description.
-- @return Current description.
function MapObject:getDescription()
	return self.description
end

--- Get map we're currently occupying.
-- @return Current map.
function MapObject:getMap()
	return self.map
end

--- Get contents list.
-- @return Contents list.
function MapObject:getContents()
	return self.contents
end

--- Get current MapObject location.
-- @return Current location.
function MapObject:getLoc()
	return self.loc
end

--- Get the X of the tile we occupy.
-- @return Current x loc or nil.
function MapObject:getX()
	return self.loc and self.loc:getX() or nil
end

--- Get the Y of the tile we occupy.
-- @return Current y loc or nil.
function MapObject:getY()
	return self.loc and self.loc:getY() or nil
end

--- Get the Z of the tile we occupy.
-- @return Current z loc or nil.
function MapObject:getZ()
	return self.loc and self.loc:getZ() or nil
end

return MapObject
