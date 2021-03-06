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

--- Cloneable that holds data about a fireable event, meant to be used with a Scheduler.
-- @author milkmanjack
module("obj.Event", package.seeall)

local Cloneable			= require("obj.Cloneable")

--- Event meant to be used with a Scheduler.
-- @class table
-- @name Event
-- @field destination Timestamp indicating when the event should fire.
-- @field didRun If true, this event has had its initial firing.
-- @field shouldRepeat If true, this event should repeat after the first firing.
-- @field currentRepeat Which cycle we're on.
-- @field repeatMax How many cycles before we stop.
-- @field repeatInterval Added to destination for each repeat.
local Event				= Cloneable.clone()

-- event settings
Event.destination		= 0 -- a timestamp for some point in the future
Event.didRun			= false -- did this event run already?

-- repeating events
Event.shouldRepeat		= false -- should it repeat?
Event.currentRepeat		= 0 -- which cycle we're on
Event.repeatMax			= 0 -- how many times to repeat (0 is infinite)
Event.repeatInterval	= 0 -- what offset from previous execution to repeat

--- This is just a shortcut for initializing a new event.
-- This is to make it as easy as possible to create a new event.
-- @param destination Timestamp indicating when the event should fire.
-- @param fun The function to be fired by the event.
-- @param shouldRepeat If true, this event should repeat after the first firing.
-- @param repeatMax How many cycles before we stop.
-- @param repeatInterval How long between each repeat? (relative amount based on clock)
function Event:initialize(destination, fun, shouldRepeat, repeatMax, repeatInterval)
	self.destination	= destination ~= nil and destination or self.destination
	self.run			= fun ~= nil and fun or self.run
	self.shouldRepeat	= shouldRepeat ~= nil and shouldRepeat or self.shouldRepeat
	self.repeatMax		= repeatMax ~= nil and repeatMax or self.repeatMax
	self.repeatInterval	= repeatInterval ~= nil and repeatInterval or self.repeatInterval
end

--- Check if the event is ready to fire.
-- @param timestamp	This is the current timestamp to compare to our destination timestamp.
-- @return true if the event is ready to fire.<br/>false otherwise.
function Event:isReady(timestamp)
	-- is this event "done"?
	if self:isDone() then
		return false
	end

	-- have we reached our destination?
	if timestamp >= self.destination then
		return true
	end

	return false
end

--- Check if this event will fire anymore.
-- @return true if the event will still fire.<br/>false otherwise.
function Event:isDone()
	if self:hasRun() and not self:willRepeat() then
		return true
	end

	return false
end

--- Check if this event has had its first firing.
-- @return true if it has fired.<br/>false otherwise.
function Event:hasRun()
	return self.didRun
end

--- Will this event repeat (anymore)? Takes into consideration whether or not we
-- have reached our repeat maximum, so it will return false if we have reached it.
-- @return true if it will repeat.<br/>false otherwise.
function Event:willRepeat()
	return self.shouldRepeat == true and (self.currentRepeat < self.repeatMax or self.repeatMax == nil or self.repeatMax == 0)
end

--- The intended access point for running the event.
-- @param timestamp Timestamp to be treated as the firing-off point.
function Event:execute(timestamp)
	-- if it has not run yet, indicate it has
	if not self:hasRun() then
		self.didRun			= true

	-- if it has run, indicate this is a repeat
	else
		self.currentRepeat	= self.currentRepeat + 1
	end

	-- actual event processing
	self:run()

	-- prepare for the next repeation, if necessary
	if self:willRepeat() then
		self.destination = self.destination + self.repeatInterval
	end
end

return Event
