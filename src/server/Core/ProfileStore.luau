--[[
	Minimal, self-contained session-locked DataStore wrapper (no external
	dependencies). Not a full ProfileService/ProfileStore replacement, but
	covers: atomic session locking with stale-lock takeover, retry/backoff on
	DataStore calls, and safe save/release. DataService is the only module
	that should use this directly.
]]

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local ProfileStore = {}
ProfileStore.__index = ProfileStore

-- Studio has no stable game.JobId (a fresh random one is generated below on
-- every single Play session), so a session this same machine held can never
-- be recognized as "ours" and reclaimed early the way a live server restart
-- can be -- without a shorter timeout here, every Play session started within
-- SESSION_LOCK_STALE_SECONDS of the previous one's end would find the lock
-- still (spuriously) held and kick the tester. Production servers keep the
-- full timeout, which is load-bearing there: it's what stops two real
-- concurrent servers from corrupting the same profile.
local SESSION_LOCK_STALE_SECONDS = RunService:IsStudio() and 3 or 30
local SESSION_CLAIM_RETRY_COUNT = 5
local SESSION_CLAIM_RETRY_WAIT_SECONDS = 3

local JOB_ID = (game.JobId ~= "" and game.JobId) or ("STUDIO_" .. HttpService:GenerateGUID(false))

local function withRetry(fn, maxAttempts: number?)
	local attempts = maxAttempts or 5
	local lastError

	for attempt = 1, attempts do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end

		lastError = result
		if attempt < attempts then
			task.wait(math.min(2 ^ attempt * 0.5, 8))
		end
	end

	return false, lastError
end

function ProfileStore.new(dataStoreName: string, defaultProfileFn: () -> any, reconcileFn: ((any) -> any)?)
	local self = setmetatable({}, ProfileStore)
	self._store = DataStoreService:GetDataStore(dataStoreName)
	self._defaultProfileFn = defaultProfileFn
	self._reconcileFn = reconcileFn
	self._activeProfiles = {} :: { [string]: any }
	return self
end

-- Attempts to atomically claim (or take over a stale) session lock for `key`.
-- Returns the raw stored record { Data, ActiveSession } on success, or nil.
function ProfileStore:_claimSession(key: string)
	local claimedRecord = nil

	local ok = withRetry(function()
		local updated = self._store:UpdateAsync(key, function(raw)
			raw = raw or {}
			local session = raw.ActiveSession
			local now = os.time()

			if session and session.JobId ~= JOB_ID and (now - (session.Timestamp or 0)) < SESSION_LOCK_STALE_SECONDS then
				-- Another live server currently owns this profile.
				return nil
			end

			raw.ActiveSession = { JobId = JOB_ID, Timestamp = now }
			raw.Data = raw.Data or self._defaultProfileFn()
			return raw
		end)

		if updated == nil then
			error("SessionLocked")
		end

		claimedRecord = updated
	end, 2)

	if not ok then
		return nil
	end

	return claimedRecord
end

function ProfileStore:Load(key: string)
	if self._activeProfiles[key] then
		return self._activeProfiles[key]
	end

	local raw = nil
	for attempt = 1, SESSION_CLAIM_RETRY_COUNT do
		raw = self:_claimSession(key)
		if raw then
			break
		end
		if attempt < SESSION_CLAIM_RETRY_COUNT then
			task.wait(SESSION_CLAIM_RETRY_WAIT_SECONDS)
		end
	end

	if not raw then
		warn(("ProfileStore: could not claim session lock for %s"):format(key))
		return nil
	end

	local data = raw.Data or self._defaultProfileFn()
	if self._reconcileFn then
		data = self._reconcileFn(data)
	end

	local handle = {
		Key = key,
		Data = data,
		Active = true,
	}

	self._activeProfiles[key] = handle
	return handle
end

function ProfileStore:Save(handle): boolean
	if not handle.Active then
		return false
	end

	local ok = withRetry(function()
		self._store:UpdateAsync(handle.Key, function(raw)
			raw = raw or {}
			local session = raw.ActiveSession
			if session and session.JobId ~= JOB_ID then
				-- Lost the lock to another server; never overwrite their save.
				error("LostSessionLock")
			end
			raw.Data = handle.Data
			raw.ActiveSession = { JobId = JOB_ID, Timestamp = os.time() }
			return raw
		end)
	end)

	if not ok then
		warn(("ProfileStore: failed to save profile for %s"):format(handle.Key))
	end

	return ok
end

function ProfileStore:Release(handle)
	if not handle.Active then
		return
	end

	local ok = withRetry(function()
		self._store:UpdateAsync(handle.Key, function(raw)
			raw = raw or {}
			local session = raw.ActiveSession
			if session and session.JobId ~= JOB_ID then
				error("LostSessionLock")
			end
			raw.Data = handle.Data
			raw.ActiveSession = nil
			return raw
		end)
	end)

	if not ok then
		warn(("ProfileStore: failed to release profile for %s"):format(handle.Key))
	end

	handle.Active = false
	self._activeProfiles[handle.Key] = nil
end

function ProfileStore:ReleaseAllSync(timeBudgetSeconds: number)
	local start = os.clock()
	for _, handle in self._activeProfiles do
		if os.clock() - start > timeBudgetSeconds then
			break
		end
		self:Release(handle)
	end
end

return ProfileStore
