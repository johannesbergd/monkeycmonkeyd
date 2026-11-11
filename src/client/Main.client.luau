--!strict
-- Client entry point for the Forest Run place.

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local LiveTuning = require(ReplicatedStorage.Shared.LiveTuning)

local HudController = require(script.Parent.HudController)
local InputController = require(script.Parent.InputController)
local MovementController = require(script.Parent.MovementController)
local RagdollController = require(script.Parent.RagdollController)
local RespawnController = require(script.Parent.RespawnController)
local WobbleController = require(script.Parent.WobbleController)

LiveTuning.mirror(Config, ReplicatedStorage.Shared.Config)

RagdollController.init()
MovementController.init()
RespawnController.init()
InputController.init()
WobbleController.init()
HudController.init()
