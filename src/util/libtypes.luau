-- types:

export type Buffer = {
	cursor: number,
	size: number,
	references: { unknown },
	inner: buffer,
}

export type function GetSchema(t: type, schemaindex: string)
	return t:readproperty(types.singleton(schemaindex))
end

export type function GetNestedSchema(t: type)
	local nt = types.newtable()
	local function traverse(t: type, n: type)
		for i, v in t:properties() do
			local tx = GetSchema(v.read or types.never, "__T")
			if tx:is("table") then
				local ntx = types.newtable()
				n:setproperty(types.singleton(i:value()), ntx)
				traverse(tx, ntx)
			else
				n:setproperty(types.singleton(i:value()), tx)
			end
		end
	end
	traverse(t, nt)

	return nt
end

export type Middleware = (id: number, plr: Player) -> boolean
export type Connection = (...any) -> ()
export type Callback = (...any) -> (boolean, any)
export type Cleanup = () -> ()

export type Schema<T = nil> = {
	read read: (buf: buffer, offset: number) -> (T, number),
	read write: (input: T) -> (),
	read __T: T,
}

export type Intermediate<T = nil, O = nil, K = never> = {
	read schema: Schema<T>,
	read schema_output: Schema<O>,
	read __schema_output: O,
	read __schema: T,
	read __kind: K,
	read id: number,
	read reliable: boolean,
}

export type ClientRemote<T = nil> = {
	read connect: (self: any, callback: (T) -> ()) -> Cleanup,
	read fire: (any, T) -> (),
	read __T: T,
	read __kind: "event",
}
export type ClientFunction<T = nil, O = nil> = {
	read invoke: (any, T) -> (boolean, O),
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
	read set_callback: (any, (Player, T) -> (boolean, O)) -> (),
	read __T: T,
	read __O: O,
	read __kind: "function",
}

type function ClientSearchAndReplace(input: type, relative_write_to: type): ()
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
					substituted = ClientFunction(schema, schema_output or types.singleton(nil))
				elseif remote_kind == "event" then
					substituted = ClientRemote(schema)
				end
			end
			assert(substituted, "NO SUBSTITUTE")
			relative_write_to:setreadproperty(i, substituted)
		else
			local tempnt = types.newtable()
			relative_write_to:setreadproperty(i, tempnt)
			ClientSearchAndReplace(t, tempnt)
		end
	end
end

type function ServerSearchAndReplace(input: type, relative_write_to: type): ()
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
					substituted = ServerFunction(schema, schema_output or types.singleton(nil))
				elseif remote_kind == "event" then
					substituted = ServerRemote(schema)
				end
			end
			assert(substituted, "NO SUBSTITUTE")
			relative_write_to:setreadproperty(i, substituted)
		else
			local tempnt = types.newtable()
			relative_write_to:setreadproperty(i, tempnt)
			ServerSearchAndReplace(t, tempnt)
		end
	end
end

export type function ReplicateClient(original: type)
	local ot = types.newtable()
	ClientSearchAndReplace(original, ot)
	return ot
end

export type function ReplicateServer(original: type)
	local ot = types.newtable()
	ServerSearchAndReplace(original, ot)
	return ot
end

return nil
