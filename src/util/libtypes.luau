-- types:

export type Buffer = {
	cursor: number,
	references: { unknown },
	inner: buffer,
}

export type Channel = Buffer & {
	send: (buffer, { unknown }?) -> (),
	limit: number,
	-- an unreliable channel drops a message over limit instead of sending it
	reliable: boolean,
	-- messages in the batch
	count: number,
}

export type function GetSchema(t: type, schemaindex: string)
	return t:readproperty(types.singleton(schemaindex))
end

-- a field's type is its schema's __T as is: nested structs already resolved theirs
export type function GetNestedSchema(t: type)
	local nt = types.newtable()
	for i, v in t:properties() do
		nt:setproperty(types.singleton(i:value()), GetSchema(v.read or types.never, "__T"))
	end
	return nt
end

export type Middleware = (id: number, plr: Player) -> boolean
export type Connection = (...any) -> ()
export type Callback = (...any) -> (boolean, ...any)
export type Cleanup = () -> ()

export type Schema<T = nil> = {
	read read: (buf: buffer, offset: number) -> (T, number),
	read write: (input: T) -> (),
	read __T: T,
}

export type Intermediate<T = nil, O = nil, K = never> = {
	read schema: Schema<T>,
	-- functions only
	read schema_output: Schema<O>?,
	read __schema_output: O,
	read __schema: T,
	read __kind: K,
	read id: number,
	-- events only
	read reliable: boolean?,
}

export type ClientRemote<T = nil> = {
	read connect: (self: any, callback: (T) -> ()) -> Cleanup,
	read fire: (any, T) -> (),
	read __T: T,
	read __kind: "event",
}
export type ClientFunction<T = nil, O = nil> = {
	read invoke: (any, T) -> (boolean, O?),
	read __T: T,
	read __O: O,
	read __kind: "function",
}
export type ServerRemote<T = nil> = {
	read connect: (self: any, callback: (Player, T) -> ()) -> Cleanup,
	read fire: (any, Player, T) -> (),
	read fire_all: (any, T) -> (),
	read __T: T,
	read __kind: "event",
}
export type ServerFunction<T = nil, O = nil> = {
	-- O? so a refusal can return false, nil as well as false
	read set_callback: (any, (Player, T) -> (boolean, ...O?)) -> (),
	read __T: T,
	read __O: O,
	read __kind: "function",
}

type function SearchAndReplace(input: type, relative_write_to: type, server: boolean): ()
	assert(input:is("table"), "NOT A TABLE")

	for i, v in input:properties() do
		local t = assert(v.read)

		local schema = GetSchema(t, "__schema")
		local schema_output = GetSchema(t, "__schema_output")
		if schema then -- is Intermediate
			local substituted: type
			do
				local remote_kind = t:readproperty(types.singleton("__kind"))
				assert(remote_kind, "FAILED TO GET KIND")
				remote_kind = remote_kind:value()
				if remote_kind == "function" then
					local output = schema_output or types.singleton(nil)
					substituted = if server then ServerFunction(schema, output) else ClientFunction(schema, output)
				elseif remote_kind == "event" then
					substituted = if server then ServerRemote(schema) else ClientRemote(schema)
				end
			end
			assert(substituted, "NO SUBSTITUTE")
			relative_write_to:setreadproperty(i, substituted)
		else
			local tempnt = types.newtable()
			relative_write_to:setreadproperty(i, tempnt)
			SearchAndReplace(t, tempnt, server)
		end
	end
end

export type function ReplicateClient(original: type)
	local ot = types.newtable()
	SearchAndReplace(original, ot, false)
	return ot
end

export type function ReplicateServer(original: type)
	local ot = types.newtable()
	SearchAndReplace(original, ot, true)
	return ot
end

return nil
