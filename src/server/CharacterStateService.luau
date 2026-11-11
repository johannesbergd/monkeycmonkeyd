--!strict
-- Mirrors each monkey's ragdoll and hang state so every other player sees it.
-- The owning client starts and stops these itself (instant feel); the server applies the same change
-- for everyone else and keeps a failsafe so nobody stays ragdolled forever.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RagdollRig = require(ReplicatedStorage.Shared.RagdollRig)
local RateLimiter = require(ReplicatedStorage.Shared.RateLimiter)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local CharacterStateService = {}

-- Bumped every time a character's ragdoll state changes, so stale failsafe timers do nothing.
local ragdollTokens: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

local function setRagdoll(character: Model, on: boolean)
	RagdollRig.setRagdolled(character, on)
	character:SetAttribute("Ragdolled", on)
	ragdollTokens[character] = (ragdollTokens[character] or 0) + 1
end

local function aliveCharacter(player: Player): Model?
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character
end

-- For hazards and animals (Day 2): knock a player's monkey over from the server.
function CharacterStateService.ragdoll(player: Player, duration: number)
	Remotes.ForceRagdoll:FireClient(player, duration)
end

function CharacterStateService.start()
	local ragdollLimiter = RateLimiter.new(6, 2)
	local hangLimiter = RateLimiter.new(20, 2)

	Remotes.RagdollRequest.OnServerEvent:Connect(function(player: Player, on: unknown)
		if typeof(on) ~= "boolean" then
			return
		end
		local character = aliveCharacter(player)
		if not character then
			return
		end

		if not on then
			-- Getting up is never rate limited, so the server can't get stuck thinking you're down.
			setRagdoll(character, false)
			return
		end

		if not ragdollLimiter:allow(player) then
			return
		end
		setRagdoll(character, true)

		local token = ragdollTokens[character]
		task.delay(Config.Ragdoll.MaxTime + 1, function()
			if ragdollTokens[character] == token and character.Parent and character:GetAttribute("Ragdolled") then
				setRagdoll(character, false)
				Remotes.ForceRagdoll:FireClient(player, 0)
			end
		end)
	end)

	Remotes.HangState.OnServerEvent:Connect(function(player: Player, hanging: unknown)
		if typeof(hanging) ~= "boolean" then
			return
		end
		if not hangLimiter:allow(player) and hanging then
			return
		end
		local character = player.Character
		if character then
			character:SetAttribute("Hanging", hanging)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local character = player.Character
		if character then
			ragdollTokens[character] = nil
		end
	end)
end

return CharacterStateService
