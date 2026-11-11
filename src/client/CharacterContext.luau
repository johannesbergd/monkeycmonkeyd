--!strict
-- Keeps track of the local player's current monkey so other controllers don't each re-implement it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Signal)

export type Rig = {
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
}

local CharacterContext = {}

-- Fires with no arguments whenever the rig changes (spawn, respawn, removal). Call get() for the new one.
CharacterContext.Changed = Signal.new()

local player = Players.LocalPlayer
local current: Rig? = nil

function CharacterContext.get(): Rig?
	return current
end

local function bind(character: Model)
	current = nil
	CharacterContext.Changed:Fire()

	local humanoid = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not humanoid or not humanoid:IsA("Humanoid") or not root or not root:IsA("BasePart") then
		return
	end
	if player.Character ~= character then
		return
	end

	current = {
		character = character,
		humanoid = humanoid,
		root = root,
	}
	CharacterContext.Changed:Fire()
end

player.CharacterAdded:Connect(bind)
player.CharacterRemoving:Connect(function()
	current = nil
	CharacterContext.Changed:Fire()
end)
if player.Character then
	task.spawn(bind, player.Character)
end

return CharacterContext
