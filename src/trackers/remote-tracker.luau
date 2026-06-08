local remotes = {}

function map(key: string, remote: any) end

function get()
	return remotes
end

return {
	map = map,
	get = get,
}
