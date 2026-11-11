--!strict
-- Builds a greybox course for tuning movement on Day 1. Skipped if Workspace already has a "Course" folder,
-- so once you build the real level, put it in a folder named "Course" (or turn off Debug.BuildTestCourse).
--
-- Layout, heading away from the spawn (toward -Z):
--   0 Start platform
--   Hop over three branches          -> 1
--   Swing from a vine across a gap   -> 2
--   Jump + air-dash across a gap      -> 3
--   Monkey bars (5 vines)             -> 4 Home

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Tags = require(ReplicatedStorage.Shared.Tags)

local TestCourse = {}

local BASE_Y = 80

local WOOD = Color3.fromRGB(122, 84, 52)
local BARK = Color3.fromRGB(86, 60, 40)
local VINE = Color3.fromRGB(96, 150, 64)
local GRASS = Color3.fromRGB(58, 92, 44)
local PAD = Color3.fromRGB(255, 205, 60)

local function newPart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function sign(parent: Instance, position: Vector3, text: string)
	local anchor = newPart(parent, "SignAnchor", Vector3.new(1, 1, 1), CFrame.new(position), WOOD, Enum.Material.Wood)
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(260, 60)
	billboard.StudsOffset = Vector3.new(0, 2, 0)
	billboard.MaxDistance = 120
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.3
	label.BackgroundColor3 = Color3.fromRGB(30, 24, 18)
	label.TextColor3 = Color3.fromRGB(255, 244, 220)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label
end

-- A thick platform with a decorative trunk underneath. Its edges are grabbable, so you can catch it if you fall short.
local function platform(parent: Instance, name: string, topCenter: Vector3, size: Vector3): Part
	local center = topCenter - Vector3.new(0, size.Y / 2, 0)
	local part = newPart(parent, name, size, CFrame.new(center), BARK, Enum.Material.Wood)
	CollectionService:AddTag(part, Tags.Grabbable)

	local trunkHeight = center.Y - size.Y / 2
	local trunk = newPart(
		parent,
		name .. "Trunk",
		Vector3.new(trunkHeight, 6, 6),
		CFrame.new(center.X, trunkHeight / 2, center.Z) * CFrame.Angles(0, 0, math.rad(90)),
		BARK,
		Enum.Material.Wood
	)
	trunk.Shape = Enum.PartType.Cylinder
	trunk.CanCollide = false
	trunk.CanQuery = false
	return part
end

-- A round branch lying across the path (along X). Solid branches can be stood on and hung from;
-- hang-only vines and bars aren't solid, so a jump carries you into them instead of onto them.
local function branch(parent: Instance, name: string, topCenter: Vector3, length: number, thickness: number, color: Color3, solid: boolean): Part
	local center = topCenter - Vector3.new(0, thickness / 2, 0)
	local part = newPart(parent, name, Vector3.new(length, thickness, thickness), CFrame.new(center), color, Enum.Material.Wood)
	part.Shape = Enum.PartType.Cylinder
	part.CanCollide = solid
	CollectionService:AddTag(part, Tags.Grabbable)
	return part
end

local function checkpoint(parent: Instance, stage: number, onPlatform: Part, label: string)
	local top = onPlatform.Position.Y + onPlatform.Size.Y / 2
	local pad = newPart(
		parent,
		`Checkpoint{stage}`,
		Vector3.new(6, 1, 6),
		CFrame.new(onPlatform.Position.X, top + 0.5, onPlatform.Position.Z),
		PAD,
		Enum.Material.Neon
	)
	pad.CanCollide = false
	pad.CanQuery = false
	pad.Transparency = 0.45
	pad:SetAttribute("Stage", stage)
	CollectionService:AddTag(pad, Tags.Checkpoint)
	sign(parent, Vector3.new(onPlatform.Position.X, top + 6, onPlatform.Position.Z), label)
end

function TestCourse.buildIfMissing()
	if Workspace:FindFirstChild("Course") then
		return
	end

	local course = Instance.new("Folder")
	course.Name = "Course"

	local floor = newPart(course, "ForestFloor", Vector3.new(1024, 2, 1024), CFrame.new(0, 0, -100), GRASS, Enum.Material.Grass)
	CollectionService:AddTag(floor, Tags.ForestFloor)

	-- 0: start
	local top = BASE_Y
	local start = platform(course, "Start", Vector3.new(0, top, 0), Vector3.new(16, 2, 16))
	checkpoint(course, 0, start, "Start")

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(0, top + 0.5, 5)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CanQuery = false
	spawn.Parent = course

	-- 1: hop across three branches, each a little higher
	branch(course, "Hop1", Vector3.new(0, top, -14), 12, 3, WOOD, true)
	branch(course, "Hop2", Vector3.new(0, top + 2, -24), 12, 3, WOOD, true)
	branch(course, "Hop3", Vector3.new(0, top + 4, -34), 12, 3, WOOD, true)
	top += 4
	local p1 = platform(course, "Platform1", Vector3.new(0, top, -46), Vector3.new(12, 2, 12))
	checkpoint(course, 1, p1, "1 · Next: swing (E to grab)")

	-- 2: swing from a vine across a 26-stud gap (the vine is in reach of a running jump off the edge)
	branch(course, "SwingVine", Vector3.new(0, top + 10, -60), 10, 1.6, VINE, false)
	local p2 = platform(course, "Platform2", Vector3.new(0, top, -84), Vector3.new(12, 2, 12))
	checkpoint(course, 2, p2, "2 · Next: jump, then Q to dash")

	-- 3: jump and air-dash across a 20-stud gap
	local p3 = platform(course, "Platform3", Vector3.new(0, top, -116), Vector3.new(12, 2, 12))
	checkpoint(course, 3, p3, "3 · Next: monkey bars")

	-- 4: monkey bars to home
	for i = 1, 5 do
		branch(course, `Bar{i}`, Vector3.new(0, top + 9, -122 - 8 * i), 10, 1.6, VINE, false)
	end
	local home = platform(course, "Home", Vector3.new(0, top, -182), Vector3.new(20, 2, 20))
	checkpoint(course, 4, home, "Home!")

	course.Parent = Workspace
end

return TestCourse
