--!strict
-- CollectionService tags used by the level. Tag parts in Studio with the Tag Editor
-- (Properties > Tags) or let the test-course builder do it.

return {
	Grabbable = "Grabbable", -- anything a monkey can hang from (branches, vines, ledges)
	Checkpoint = "Checkpoint", -- needs a number attribute "Stage" (0 = start)
	ForestFloor = "ForestFloor", -- touching it respawns you
}
