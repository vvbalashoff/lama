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

--- Cloneable that manages user I/O.
-- @author milkmanjack
module("obj.Client", package.seeall)

local Cloneable						= require("obj.Cloneable")

--- Cloneable that manages user I/O.
-- @class table
-- @name Client
-- @field socket The socket associated with this Client.
local Client						= Cloneable.clone()

-- runtime data
Client.socket						= nil
Client.backlogInput					= nil -- backlog that adds support for pure telnet

--- Contains all telnet protocol options on the client.
-- @class table
-- @name Client.options
Client.options						= nil

--- Contains currently flagged protocols that the Client wants to negotiate.
-- @class table
-- @name Client.options.WILL
--Client.options.WILL				= nil

--- Contains currently flagged protocols that the Client doesn't want to negotiate.
-- @class table
-- @name Client.options.WONT
--Client.options.WONT				= nil

--- Contains currently flagged options that the Client wants the Server to negotiate.
-- @class table
-- @name Client.options.DO
--Client.options.DO					= nil

--- Contains currently flagged options that the Client doesn't want the Server to negotiate.
-- @class table
-- @name Client.options.DONT
--Client.options.DONT				= nil

--- Contains terminal type information.
-- @class table
-- @name Client.options.TTYPE
-- @field type The type of terminal the client is using.
--Client.options.TTYPE				= nil

--- Contains MCCP2 zlib streams.
-- @class table
-- @name Client.options.MCCP2
-- @field inflater The zlib inflate input stream.
-- @field deflater The zlib deflate output stream.
-- @field deflateBuffer The buffer deflated output is stored in before being sent.

--- Associates a socket with the Client.
-- @param socket The socket to be associated.
-- @param updateOptions Tell the client which options we support.
function Client:initialize(socket, updateOptions)
	updateOptions = (updateOptions == nil and true) or updateOptions -- default to true
	self:setSocket(socket)

	-- initialize options
	self.options						= {}
	self.options.WILL					= {}
	self.options.WONT					= {}
	self.options.DO						= {}
	self.options.DONT					= {}
	self.options.TTYPE					= {}
	self.options.TTYPE.type				= nil
	self.options.MCCP2					= {}
	self.options.MCCP2.inflater			= nil
	self.options.MCCP2.deflater			= nil
	self.options.MCCP2.deflateBuffer	= nil

	if updateOptions then
		self:sendSupportedOptions()
	end
end

--- Returns the string-value of the Client.
-- @return A string in the format of <tt>"[client@&lt;client remote address&gt;]"</tt>.
function Client:toString()
	if not self.socket then
		return "[client@nil]"
	end

	local addr, port = self:getAddress()
	return string.format("[client@%s]", addr)
end

--- Pipe to socket's receive() function.
-- Telnet protocol processing is handled before values are returned.
-- @return If successful, returns the received pattern.<br/>In case of error, the method returns nil followed by an error message.
function Client:receive(pattern, prefix)
	local _, err, input = self.socket:receive(pattern, prefix)

	if input == nil then
		return nil, err
	end

	-- remove carriage returns
	input = string.gsub(input, "\r", "")

	if string.len(input) < 1 then
		return nil, err
	end

	-- parse IAC messages at the client level before passing off to whoever wants to know
	local found = string.find(input, string.char(Telnet.command.IAC))
	while found ~= nil do
		local command = string.byte(input, found+1)
		local option = string.byte(input, found+2)
		local current = found+2
		if command == Telnet.command.WILL then
			self:onWill(option)

		elseif command == Telnet.command.WONT then
			self:onWont(option)

		elseif command == Telnet.command.DO then
			self:onDo(option)

		elseif command == Telnet.command.DONT then
			self:onDont(option)

		elseif command == Telnet.command.SB then
			-- check for subnegotiations that start with IAC SB and end with IAC SE
			local nextIACSE = string.find(input, string.char(Telnet.command.IAC, Telnet.command.SE), current)
			if nextIACSE then
				self:onSubnegotiation(string.sub(input, current, nextIACSE-1))
				current = nextIACSE+1
			end
		end

		-- string.format terminates on null char when displaying, which happens to be used in
		-- TTYPE negotiation (Telnet.command.IS == 0 == null terminator).
		-- as such, use pure concatenation.
		input = string.sub(input, 1, found-1) .. string.sub(input, current+1) -- strip IAC message from input
		found = string.find(input, string.char(Telnet.command.IAC))
	end

	-- backlog input missing a linebreak
	-- this will add support for ANSI clients
	local lastLinebreak = string.find(input, "\n")
	local nextLinebreak = string.find(input, "\n", lastLinebreak)
	while nextLinebreak do
		lastLinebreak = nextLinebreak
		nextLinebreak = string.find(input, "\n", nextLinebreak+1)
	end

	-- no linebreak sent? just throw it in the backlog.
	if not lastLinebreak then
		self.backlogInput = string.format("%s%s", self.backlogInput or "", input)
		return nil, err
	end

	-- copy valid input (input ending with a linebreak)
	-- move rest into backlog
	local validInput = string.format("%s%s", self.backlogInput or "", string.sub(input, 1, lastLinebreak))
	if string.len(validInput) > 0 then
		self.backlogInput = nil
	end

	local remainingInput = string.sub(input, lastLinebreak and lastLinebreak+1 or 1)
	if string.len(remainingInput) > 0 then
		self.backlogInput = remainingInput
	end

	return validInput, err
end

--- Inform the Client of which options we support.
-- <b>Should be called only once per socket to avoid miscommunications.</b>
function Client:sendSupportedOptions()
	-- start MCCP2 negotiation
	if config.MCCP2IsEnabled() then
		self:sendWill(Telnet.protocol.MCCP2)
	end

	self:sendDo(Telnet.protocol.TTYPE) -- tell us your terminal type please.
	self:sendWill(Telnet.protocol.MSSP) -- this works, kinda.
end

--- Send an IAC WILL message with the given option.
-- @param op Option the Server supports and wants the Client to negotiate.
function Client:sendWill(op)
	self:send(string.char(Telnet.command.IAC, Telnet.command.WILL, op))
end

--- Send an IAC WONT message with the given option.
-- @param op Option the Server doesn't support and wants the Client not to negotiate.
function Client:sendWont(op)
	self:send(string.char(Telnet.command.IAC, Telnet.command.WONT, op))
end

--- Send an IAC DO message with the given option.
-- @param op Option the Server wants the Client to negotiate.
function Client:sendDo(op)
	self:send(string.char(Telnet.command.IAC, Telnet.command.DO, op))
end

--- Send an IAC DONT message with the given option.
-- @param op Option the Server doesn't wnat the Client to negotiate.
function Client:sendDont(op)
	self:send(string.char(Telnet.command.IAC, Telnet.command.DONT, op))
end

--- What to do when receiving an IAC WILL option.
-- @param op Option the Client wants to negotiate.
function Client:onWill(op)
	self.options.WILL[op] = true
	self.options.WONT[op] = false

	-- if they will negotiate terminal type, ask for it right away
	if op == Telnet.protocol.TTYPE then
		self.options.TTYPE.enabled = true
		self:send(string.char(Telnet.command.IAC, Telnet.command.SB, Telnet.protocol.TTYPE, Telnet.environment.SEND, Telnet.command.IAC, Telnet.command.SE))
	end
end

--- What to do when receiving an IAC WONT option.
-- @param op Option the Client doesn't want to negotiate.
function Client:onWont(op)
	self.options.WONT[op] = true
	self.options.WILL[op] = false
end

--- What to do when receiving an IAC DO option.
-- @param op Option the Client wants the Server to negotiate.
function Client:onDo(op)
	-- process before setting DO
	if op == Telnet.protocol.MCCP2 and config.MCCP2IsEnabled() then
		self:send(string.char(Telnet.command.IAC, Telnet.command.SB, Telnet.protocol.MCCP2, Telnet.command.IAC, Telnet.command.SE))

		-- all output from now on is deflated!
		self.options.MCCP2.deflateBuffer = {}
		self.options.MCCP2.deflater = zlib.deflate(function(data) table.insert(self.options.MCCP2.deflateBuffer, data) end)
	end

	self.options.DO[op] = true
	self.options.DONT[op] = false

	-- start doing MSSP negotiations
	if op == Telnet.protocol.MSSP then
		self:MSSP(Telnet.MSSP.VAR, "NAME", Telnet.MSSP.VAL, "lama", Telnet.MSSP.VAR, "UPTIME", Telnet.MSSP.VAL, os.time())
	end
end

--- What to do when receiving an IAC DONT option.
-- @param op Option the Client doesn't want the Server to negotiate.
function Client:onDont(op)
	self.options.DO[op] = false
	self.options.DONT[op] = true
end

--- What to do when receiving an IAC SE subnegotiation.
-- @param negotiation The entirety of the subnegotiation message.
function Client:onSubnegotiation(negotiation)
	-- TTYPE IS <type>
	if string.find(negotiation, string.char(Telnet.protocol.TTYPE, Telnet.environment.IS)) == 1 then
		local type = string.sub(negotiation, 3)
		self.options.TTYPE.type = type
	end
end

--- Check if we will negotiate the given option.
-- @return true if option is currently negotiated.<br/>false otherwise.
function Client:getWill(op)
	return self.options.WILL[op] == true
end

--- Check if we will not negotiate the given option.
-- @return true if option is currently not negotiated.<br/>false otherwise.
function Client:getWont(op)
	return self.options.WONT[op] == true
end

--- Check if the client expects us to negotiate this option.
-- @return true if option is currently negotiated.<br/>false otherwise.
function Client:getDo(op)
	return self.options.DO[op] == true
end

--- Check if the client expects us not to negotiate this option.
-- @return true if option is currently not negotiated.<br/>false otherwise.
function Client:getDont(op)
	return self.options.DONT[op] == true
end

-- send an MSSP negotiation.
function Client:MSSP(...)
	local packed = {...}
	local formatted = string.char(Telnet.command.IAC, Telnet.command.SB, Telnet.protocol.MSSP)
	for i=1, #packed, 2 do
		local op = packed[i]
		local val = packed[i+1]
		formatted = string.format("%s%s%s", formatted, string.char(op), val)
	end

	formatted = string.format("%s%s", formatted, string.char(Telnet.command.IAC, Telnet.command.SE))

	self:send(formatted)
end

--- Pipe to socket's send() function.
-- @return If successful, returns number of bytes written.<br/>In case of error, the method returns nil followed by an error message, followed by the number of bytes that were written before failure.
function Client:send(data, i, j)
	if self:getDo(Telnet.protocol.MCCP2) then
		-- write data to the deflate buffer
		self.options.MCCP2.deflater:write(data)
		self.options.MCCP2.deflater:flush()
		local compressed = table.concat(self.options.MCCP2.deflateBuffer) -- get the string
		Game.debug(string.format("MCCP2 compression savings: %d", string.len(data)-string.len(compressed)))
		self.options.MCCP2.deflateBuffer = {} -- prepare next buffer
		return self.socket:send(compressed,i,j)
	else
		return self.socket:send(data, i, j)
	end
end

--- Formats a string before sending it to the client.
-- @param str String to be sent.
-- @return result of self:send().
function Client:sendString(str)
	str = string.gsub(str or "", "\n", "\r\n") -- insert carriage returns for each linefeed
	return self:send(str)
end

--- Close the client's socket.
function Client:close()
	return self.socket:close()
end

--- Manually assign socket.
-- @param socket Socket to assign.
function Client:setSocket(socket)
	self.socket = socket
end

--- Retreive the client's socket.
-- @return The Client's socket.</br>nil if no socket is attached.
function Client:getSocket()
	return self.socket
end

--- Retreive the client's remote address.
-- @return The client's remote address.
function Client:getAddress()
	return self.socket:getpeername() or "nil" -- always return a string
end

--- Retreive the client's terminal type, if applicable.
-- @return A string representing the type of terminal.
function Client:getTerminalType()
	if not self:getWill(Telnet.protocol.TTYPE) then
		return "TTYPE not supported"
	end

	return self.options.TTYPE.type or "waiting..."
end

return Client
