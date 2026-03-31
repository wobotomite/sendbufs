local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local remotes = require("./remotes")
local read_iter = require("./read-iter")
local read = require("./read")
local buffer_writer = require("./buffer-writer")

local alloc = buffer_writer.alloc
local u8 = buffer_writer.u8

local dump = require("./dump")

@native
function create_super(): buffer_writer.buffer_writer
	return {
		size = 256,
		cursor = 0,
		buff = buffer.create(256),
		references = {},
	}
end

local players_reliable: { [Player]: buffer_writer.buffer_writer? } = {}
local players_unreliable: { [Player]: buffer_writer.buffer_writer? } = {}

@native
function send_reliable_packet(
	to: Player,
	id: number,
	writer: (buf: buffer_writer.buffer_writer, data: any) -> (),
	data: any
)
	local buf = players_reliable[to] or create_super()
	alloc(buf, 2)
	u8(buf, id)
	writer(buf, data)
	players_reliable[to] = buf
end
@native
function send_unreliable_packet(
	to: Player,
	id: number,
	writer: (buf: buffer_writer.buffer_writer, data: any) -> (),
	data: any
)
	local buf = players_unreliable[to] or create_super()
	alloc(buf, 2)
	u8(buf, id)
	writer(buf, data)
	players_unreliable[to] = buf
end



@native
function start()
	local reliable = Instance.new("RemoteEvent")
	reliable.Name = ".reliable"
	local unreliable = Instance.new("UnreliableRemoteEvent")
	unreliable.Name = ".unreliable"
	local remote_fn = Instance.new("RemoteFunction")
	remote_fn.Name = ".remote_fn"

	remote_fn.OnServerInvoke = function(plr,b,ref)
		for nid,val in read_iter("schema", b) do
			if (remotes[nid]==nil or remotes[nid].kind~="function") then
				return false,0;
			end
			local success,res = pcall(remotes[nid].callback,val,plr);
			if (not success) then 
				warn(res)
				return false,1 
			end;
			local buf = create_super();
			remotes[nid].schema_out.write(buf,res);
			local r,refs = dump(buf)
			return true,r,refs;

		end
		return false,2;
	end

	reliable.OnServerEvent:Connect(function(plr: Player, b, r)
		read(b, r, plr)
	end)
	unreliable.OnServerEvent:Connect(function(plr: Player, b, r)
		read(b, r, plr)
	end)

	reliable.Parent = ReplicatedStorage
	unreliable.Parent = ReplicatedStorage
	remote_fn.Parent = ReplicatedStorage

	RunService.Heartbeat:Connect(function()
		for _, plr in Players:GetPlayers() do
			do
				local buf = players_reliable[plr]
				if buf ~= nil and buf.cursor > 0 then
					local dumpBuffer, references = dump(buf)
					reliable:FireClient(plr, dumpBuffer, references)
					buf.cursor = 0
					table.clear(buf.references)
				end
			end
			do
				local buf = players_unreliable[plr]
				if buf ~= nil and buf.cursor > 0 then
					local dumpBuffer, references = dump(buf)
					unreliable:FireClient(plr, dumpBuffer, references)
					buf.cursor = 0
					table.clear(buf.references)
				end
			end
		end
	end)
end

return {
	start = start,
	send_reliable_packet = send_reliable_packet,
	send_unreliable_packet = send_unreliable_packet,
}
