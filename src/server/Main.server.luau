--!strict
-- Server entry point for the Forest Run place.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local LiveTuning = require(ReplicatedStorage.Shared.LiveTuning)

local CharacterService = require(script.Parent.CharacterService)
local CharacterStateService = require(script.Parent.CharacterStateService)
local CheckpointService = require(script.Parent.CheckpointService)
local TestCourse = require(script.Parent.TestCourse)

LiveTuning.mirror(Config, ReplicatedStorage.Shared.Config)

if Config.Debug.BuildTestCourse then
	TestCourse.buildIfMissing()
end

CharacterService.start()
CharacterStateService.start()
CheckpointService.start()
