--!strict
-- Binds keyboard, gamepad and touch. ContextActionService makes the mobile buttons for us.
--   Grab   E / R2 / touch "Grab"    tap to grab; while hanging, tap again to drop
--   Jump   Space / A / jump button  while hanging: let go with a boost
--   Dash   Q / X / touch "Dash"     in the air (or out of a hang)
--   Flop   R / B / touch "Flop"     ragdoll on purpose

local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

local MovementController = require(script.Parent.MovementController)
local RagdollController = require(script.Parent.RagdollController)

local InputController = {}

local function onGrab(_action: string, state: Enum.UserInputState, _input: InputObject): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		MovementController.grabPressed()
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		MovementController.grabReleased()
	end
	return Enum.ContextActionResult.Sink
end

local function onDash(_action: string, state: Enum.UserInputState, _input: InputObject): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		MovementController.dash()
	end
	return Enum.ContextActionResult.Sink
end

local function onFlop(_action: string, state: Enum.UserInputState, _input: InputObject): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		RagdollController.flop()
	end
	return Enum.ContextActionResult.Sink
end

function InputController.init()
	ContextActionService:BindAction("MonkeyGrab", onGrab, true, Enum.KeyCode.E, Enum.KeyCode.ButtonR2)
	ContextActionService:SetTitle("MonkeyGrab", "Grab")

	ContextActionService:BindAction("MonkeyDash", onDash, true, Enum.KeyCode.Q, Enum.KeyCode.ButtonX)
	ContextActionService:SetTitle("MonkeyDash", "Dash")

	ContextActionService:BindAction("MonkeyFlop", onFlop, true, Enum.KeyCode.R, Enum.KeyCode.ButtonB)
	ContextActionService:SetTitle("MonkeyFlop", "Flop")

	-- JumpRequest covers Space, the gamepad A button and the mobile jump button.
	UserInputService.JumpRequest:Connect(MovementController.jumpPressed)
end

return InputController
