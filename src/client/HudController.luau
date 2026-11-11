--!strict
-- Day 1 HUD: checkpoint progress, a "waiting for your partner" note, and a controls hint.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local HudController = {}

local function makeLabel(parent: Instance, name: string, textSize: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundColor3 = Color3.fromRGB(30, 24, 18)
	label.BackgroundTransparency = 0.3
	label.TextColor3 = Color3.fromRGB(255, 244, 220)
	label.Font = Enum.Font.GothamBold
	label.TextSize = textSize
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Parent = parent

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 14)
	padding.PaddingRight = UDim.new(0, 14)
	padding.Parent = label

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label
	return label
end

local function numberAttribute(instance: Instance, name: string): number
	local value = instance:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

function HudController.init()
	local player = Players.LocalPlayer

	local gui = Instance.new("ScreenGui")
	gui.Name = "MonkeyHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false

	local progress = makeLabel(gui, "Progress", 20)
	progress.AnchorPoint = Vector2.new(0.5, 0)
	progress.Position = UDim2.new(0.5, 0, 0, 8)
	progress.Size = UDim2.fromOffset(0, 36)

	local waiting = makeLabel(gui, "Waiting", 15)
	waiting.AnchorPoint = Vector2.new(0.5, 0)
	waiting.Position = UDim2.new(0.5, 0, 0, 50)
	waiting.Size = UDim2.fromOffset(0, 28)
	waiting.Text = "Waiting for your partner to catch up"
	waiting.Visible = false

	if Config.Debug.ShowControlsHint and not UserInputService.TouchEnabled then
		local hint = makeLabel(gui, "ControlsHint", 14)
		hint.AnchorPoint = Vector2.new(0, 1)
		hint.Position = UDim2.new(0, 12, 1, -12)
		hint.Size = UDim2.fromOffset(0, 28)
		hint.Text = "E grab  ·  Space let go  ·  Q dash  ·  R flop"
	end

	local function refresh()
		local reached = numberAttribute(player, "ReachedStage")
		local shared = numberAttribute(Workspace, "SharedStage")
		local final = numberAttribute(Workspace, "FinalStage")
		if Workspace:GetAttribute("RunComplete") == true then
			progress.Text = "You both made it home!"
			waiting.Visible = false
			return
		end
		progress.Text = `Checkpoint {reached} / {final}`
		waiting.Visible = reached > shared
	end

	player:GetAttributeChangedSignal("ReachedStage"):Connect(refresh)
	Workspace:GetAttributeChangedSignal("SharedStage"):Connect(refresh)
	Workspace:GetAttributeChangedSignal("FinalStage"):Connect(refresh)
	Workspace:GetAttributeChangedSignal("RunComplete"):Connect(refresh)
	refresh()

	gui.Parent = player:WaitForChild("PlayerGui")
end

return HudController
