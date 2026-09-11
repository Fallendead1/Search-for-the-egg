-- Canonical persistent profile schema + reconciliation. DataService is the
-- only module that should read/write raw profile tables directly; everyone
-- else goes through the Core service APIs.

local DataSchema = {}

DataSchema.SchemaVersion = 1

function DataSchema.GetDefaultProfile()
	return {
		SchemaVersion = DataSchema.SchemaVersion,

		Currencies = {
			Gems = 0,
			AlienTokens = 0,
		},

		Stats = {
			Wins = 0,
			BestTime = nil,
			TotalPlaytime = 0,
			TotalFeathersCollected = 0,
		},

		PermanentPerks = {
			BagSize = 0,
			HandGrabAmount = 0,
			GemValue = 0,
			FeatherValue = 0,
		},

		Classes = {
			-- Starter is owned by default so it can be validly equipped in Slot1.
			Owned = { Starter = true },
			Equipped = {
				Slot1 = "Starter",
				Slot2 = nil,
			},
			Slot2Unlocked = false,
		},

		Inventory = {
			OwnedSkins = {
				Pitchfork = { Default = true },
				Dynamite = { Default = true },
				Vacuum = { Default = true },
				Drone = { Default = true },
			},

			SelectedSkins = {
				Pitchfork = "Default",
				Dynamite = "Default",
				Vacuum = "Default",
				Drone = "Default",
			},
		},

		CodesRedeemed = {},

		Entitlements = {},

		-- See ProfileTypes.Receipts: tracks processed Robux PurchaseIds for
		-- MonetizationService idempotency. Not in the original GDD schema.
		Receipts = {
			Processed = {},
		},
	}
end

-- Recursively fills in any key missing from `target` using `defaults`,
-- without ever removing or overwriting a key that already exists. Used to
-- migrate older saved profiles forward when the schema grows.
local function reconcileInto(target, defaults)
	for key, defaultValue in defaults do
		if target[key] == nil then
			if type(defaultValue) == "table" then
				local fresh = {}
				target[key] = fresh
				reconcileInto(fresh, defaultValue)
			else
				target[key] = defaultValue
			end
		elseif type(defaultValue) == "table" and type(target[key]) == "table" then
			reconcileInto(target[key], defaultValue)
		end
	end
end

function DataSchema.Reconcile(profile)
	reconcileInto(profile, DataSchema.GetDefaultProfile())
	profile.SchemaVersion = DataSchema.SchemaVersion
	return profile
end

return table.freeze(DataSchema)
