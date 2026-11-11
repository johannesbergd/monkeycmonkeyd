--!strict
-- Every tuning value for the monkeys lives here.
-- During a Play test you can change these live: see LiveTuning.luau and the README.

local Config = {
	Movement = {
		WalkSpeed = 18,
		JumpHeight = 8,
	},

	Grab = {
		-- Tap grab once: for this many seconds (or as long as it's held) the monkey grabs the first branch in reach.
		-- While hanging: Jump lets go with a boost, Grab again just drops.
		Buffer = 0.35,
		-- Ignore jump presses for this long after grabbing, so the jump that got you there doesn't let go.
		JumpReleaseDelay = 0.15,

		-- Where the "hands" look for something to grab, relative to the HumanoidRootPart.
		ReachUp = 2.5,
		ReachForward = 1.0,
		Radius = 3.5,

		-- Hanging: a rope from the top of the root part to the grip point.
		HangLength = 3.0,
		WinchSpeed = 30,
		WinchResponsiveness = 45,

		-- Swinging: extra acceleration (studs/s^2) toward the move direction while hanging.
		SwingAccel = 70,
		-- How quickly the monkey turns to face where it's swinging (AlignOrientation responsiveness).
		TurnResponsiveness = 18,

		-- Letting go.
		ReleaseBoost = 1.15, -- multiplies swing speed on release
		ReleaseJumpUp = 56, -- extra upward speed if you jump off (a normal jump is about 56)
		ReleaseJumpForward = 20, -- extra forward speed if you jump off
		SamePartCooldown = 0.35, -- seconds before you can re-grab the branch you just let go of
		BreakDistance = 14, -- auto-release if you somehow end up this far from the grip
	},

	Dash = {
		Speed = 46,
		Up = 12,
		PerAirtime = 1, -- dashes allowed before touching ground or grabbing
		Cooldown = 0.35,
	},

	-- After a dash or a release, the humanoid's own air control is paused for a moment so momentum carries.
	Carry = {
		AfterDash = 0.3,
		AfterRelease = 0.45,
		GroundCheckDistance = 3.6,
	},

	Ragdoll = {
		HardLandingSpeed = 75, -- falling faster than this (studs/s) ragdolls you on landing
		HardLandingTime = 1.4,
		FlopTime = 1.2,
		FlopCooldown = 2.0,
		MaxTime = 4.0, -- the server forces you back up after this
		SpinImpulse = 2.5,
	},

	Wobble = {
		Enabled = true,
		MaxDistance = 160, -- only wobble monkeys this close to the camera
		LeanPerSpeed = 0.022, -- radians of lean per stud/s
		MaxLean = 0.42,
		WaddleAmount = 0.16, -- side-to-side roll while walking
		WaddleStepsPerStud = 0.32,
		HeadLagPerAccel = 0.0035,
		MaxHeadLag = 0.5,
		ArmFlailAmount = 0.6,
		ArmFlailSpeed = 13,
		SpringSpeed = 14, -- higher = snappier, lower = floppier
		SpringDamping = 0.45, -- below 1 overshoots (wobbly), 1 = no overshoot
	},

	Checkpoints = {
		KillY = 20, -- fall below this height and you respawn
		RespawnAt = "Own", -- "Own" = your last checkpoint, "Shared" = the last one you BOTH reached
		MaxStagesAhead = 1, -- how many checkpoints you may get ahead of your partner
		RespawnHeight = 3.5,
	},

	Debug = {
		BuildTestCourse = true, -- builds a greybox course if Workspace has no "Course" folder
		ShowControlsHint = true,
	},
}

return Config
