--!strict
-- Renders one "STAT NAME: current value -> next value ($cost) [BUY]" row
-- shared by the Upgrade Book pages and the Bag upgrade panel. Purely
-- presentational: the Buy button only fires the request, it never
-- mutates the displayed level itself -- callers re-render on the next
-- profile/run update.

local Theme = require(script.Parent.Parent.Theme)
local Format = require(script.Parent.Parent.Parent.Util.Format)

local UpgradeRow = {}

export type LevelEntry = { Level: number, Value: number, Cost: number }

export type RowConfig = {
	Parent: Instance,
	StatName: string,
	Description: string?,
	Base: number,
	Levels: { LevelEntry },
	CurrentLevel: number,
	MaxLevel: number?,
	Affordable: boolean,
	ValueFormatter: ((number) -> string)?,
	LayoutOrder: number?,
	OnBuy: (nextLevel: number, cost: number) -> (),
}

function UpgradeRow.build(config: RowConfig): Frame
	local maxLevel = config.MaxLevel or #config.Levels
	local formatValue = config.ValueFormatter or function(v: number)
		return tostring(v)
	end

	local row = Theme.newPanel(config.StatName, config.Parent)
	row.Size = UDim2.new(1, 0, 0, 72)
	row.LayoutOrder = config.LayoutOrder or 0

	Theme.newLabel({
		Text = config.StatName,
		Size = UDim2.new(0.4, 0, 0, 26),
		Position = UDim2.new(0, 10, 0, 4),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})

	local currentValue = config.CurrentLevel <= 0 and config.Base
		or (config.Levels[config.CurrentLevel] and config.Levels[config.CurrentLevel].Value or config.Base)

	if config.Description then
		Theme.newLabel({
			Text = config.Description,
			Size = UDim2.new(0.4, 0, 0, 22),
			Position = UDim2.new(0, 10, 0, 30),
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Theme.FontBody,
			TextColor = Theme.Colors.TextDark,
			Parent = row,
		})
	end

	if config.CurrentLevel >= maxLevel then
		Theme.newLabel({
			Text = ("MAX (%s)"):format(formatValue(currentValue)),
			Size = UDim2.new(0.55, -10, 1, -8),
			Position = UDim2.new(1, -10, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			TextColor = Theme.Colors.ButtonSecondary,
			Parent = row,
		})
		return row
	end

	local nextLevel = config.CurrentLevel + 1
	local nextEntry = config.Levels[nextLevel]
	if not nextEntry then
		return row
	end

	Theme.newLabel({
		Text = ("%s -> %s"):format(formatValue(currentValue), formatValue(nextEntry.Value)),
		Size = UDim2.new(0.3, 0, 1, -8),
		Position = UDim2.new(0.42, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})

	local buyButton = Theme.newButton({
		Text = Format.cash(nextEntry.Cost),
		Size = UDim2.new(0, 110, 0, 44),
		Position = UDim2.new(1, -10, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Color = config.Affordable and Theme.Colors.ButtonPrimary or Theme.Colors.ButtonDisabled,
		Parent = row,
	})
	Theme.setButtonEnabled(buyButton, config.Affordable)
	buyButton.Activated:Connect(function()
		config.OnBuy(nextLevel, nextEntry.Cost)
	end)

	return row
end

return UpgradeRow
