--!strict
-- Roblox-compliant filtering for player-written text (spell names, tags,
-- collection names) before it is shown to anyone other than its author.
-- Authors may see their own unfiltered text. Any failure returns nil:
-- callers must hide the text (or show a placeholder), never fall back to raw text.
local TextService = game:GetService("TextService")

local TextFilter = {}
TextFilter.Placeholder = "Unnamed spell"
TextFilter.CacheSeconds = 300
TextFilter.MaxLength = 200

type Entry = { Result: string?, At: number }
local cache: { [string]: Entry } = {}
local cacheSize = 0
local MAX_CACHE = 2000

local function remember(key: string, result: string)
	if cacheSize >= MAX_CACHE then
		table.clear(cache) -- simple bound; entries are cheap to recompute
		cacheSize = 0
	end
	if not cache[key] then
		cacheSize += 1
	end
	cache[key] = { Result = result, At = os.clock() }
end

local function cacheKey(kind: string, text: string, fromUserId: number, toUserId: number?): string
	return kind .. "\0" .. tostring(fromUserId) .. "\0" .. tostring(toUserId or 0) .. "\0" .. text
end

local function cached(key: string): (boolean, string?)
	local entry = cache[key]
	if entry and os.clock() - entry.At < TextFilter.CacheSeconds then
		return true, entry.Result
	end
	return false, nil
end

local function filterObject(text: string, fromUserId: number): TextFilterResult?
	if type(text) ~= "string" or text == "" or #text > TextFilter.MaxLength or utf8.len(text) == nil then
		return nil
	end
	local ok, result = pcall(function()
		return TextService:FilterStringAsync(text, fromUserId, Enum.TextFilterContext.PublicChat)
	end)
	return if ok then result else nil
end

-- For text everyone in the server may see (killfeed, nameplates, shared spells).
-- Yields. Returns nil when filtering fails.
function TextFilter.forBroadcast(text: string, fromUserId: number): string?
	local key = cacheKey("b", text, fromUserId, nil)
	local hit, value = cached(key)
	if hit then
		return value
	end
	local result: string? = nil
	local object = filterObject(text, fromUserId)
	if object then
		local ok, filtered = pcall(function()
			return object:GetNonChatStringForBroadcastAsync()
		end)
		result = if ok then filtered else nil
	end
	if result then
		remember(key, result) -- never cache failures; a retry may succeed
	end
	return result
end

-- For text shown to one specific viewer (e.g. browsing another player's shared spell).
-- Yields. Returns nil when filtering fails.
function TextFilter.forUser(text: string, fromUserId: number, toUserId: number): string?
	if fromUserId == toUserId then
		return text
	end
	local key = cacheKey("u", text, fromUserId, toUserId)
	local hit, value = cached(key)
	if hit then
		return value
	end
	local result: string? = nil
	local object = filterObject(text, fromUserId)
	if object then
		local ok, filtered = pcall(function()
			return object:GetNonChatStringForUserAsync(toUserId)
		end)
		result = if ok then filtered else nil
	end
	if result then
		remember(key, result) -- never cache failures; a retry may succeed
	end
	return result
end

-- Convenience for spell names: always returns something safe to display.
function TextFilter.spellNameForBroadcast(name: string, fromUserId: number): string
	return TextFilter.forBroadcast(name, fromUserId) or TextFilter.Placeholder
end

return TextFilter
