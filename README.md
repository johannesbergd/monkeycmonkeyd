# Monkey See, Monkey Do: Day 1 (movement prototype)

Day 1 delivers the riskiest part of the game first: how the monkey moves.
Grab, hang, swing, let go, air-dash, flop (ragdoll), shared checkpoints, respawning, and the wobbly
"floppy" look. A greybox test course builds itself so you can test right away.

## Daily workflow

1. Double-click **`start-dev.bat`**. The first time, it installs the pinned Rojo version (7.7.0) with Rokit.
   Then, in Studio, click **Connect** in the Rojo plugin. Leave the window open while you work.
2. Edit code in `src/` with VS Code, not Studio's script editor (Rojo overwrites Studio-side edits).
   When Claude writes code, it lands in this folder and Rojo syncs it into Studio by itself.
3. Double-click **`save.bat`** to commit your changes (it asks for a short note) and push to GitHub.

**One-time setup on a new computer**

- Git for Windows: https://git-scm.com
- Rokit, in PowerShell:
  `Invoke-RestMethod https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.ps1 | Invoke-Expression`
- After the first `start-dev.bat`, run `rojo plugin install` in this folder so the Studio plugin matches.

## Open it

**Quickest:** open `ForestRun-Day1.rbxl` in Roblox Studio and press Play.

**With Rojo (recommended for the rest of the week):**

```
rojo serve default.project.json
```

Then connect from the Rojo plugin in Studio. The file layout:

| Folder | Becomes | Runs on |
| --- | --- | --- |
| `src/shared` | ReplicatedStorage.Shared | both |
| `src/server` | ServerScriptService.Server | server |
| `src/client` | StarterPlayer.StarterPlayerScripts.Client | each player |

**Without Rojo:** create those three folders in Studio and paste each file in.
`*.server.luau` is a Script, `*.client.luau` is a LocalScript, everything else is a ModuleScript
named after the file.

## Test it with two players and real lag

1. In Studio, open **Studio Settings > Network** (Alt+S / ⌥S) and set network simulation to a
   50 to 150 ms delay in both directions. Real players sit at 100 to 300 ms; testing without lag
   hides most co-op bugs.
2. **Test > Clients and Servers**: 2 players, then **Start**.
3. Go through the course in both windows:
   - Hop the three branches to checkpoint 1.
   - Swing: run off the edge, tap **E** near the vine, swing with WASD, press **Space** to let go with a boost.
   - Dash: jump, then **Q** in the air.
   - Monkey bars: hold **E** and press **Space** to fling from bar to bar.
   - Fall off anywhere: you land back on your checkpoint.
   - Press **R** to flop. Jump off something tall and land hard to flop by accident.
4. Watch the *other* window while one player moves. The wobble, arm flailing and ragdoll should all
   show up on the other client too.

If one player gets more than one checkpoint ahead, they see "Waiting for your partner" and the next
checkpoint won't count until the partner catches up.

## Controls

| Action | Keyboard | Gamepad | Mobile |
| --- | --- | --- | --- |
| Grab (tap; tap again to drop; hold to catch anything you pass) | E | R2 | Grab button |
| Let go with a boost | Space | A | Jump button |
| Air dash | Q | X | Dash button |
| Flop | R | B | Flop button |

Mobile buttons come from ContextActionService and use its default positions. Day 2 replaces them
with custom buttons.

## Tune the feel live

All numbers are in `src/shared/Config.luau`. While playing you can change them without restarting:

1. In the Explorer, select **ReplicatedStorage > Shared > Config**.
2. In Properties > Attributes you'll see every value, such as `Grab_SwingAccel` and `Wobble_SpringDamping`.
3. Edit a value **in the Server view** so it applies everywhere (Client view = that client only).
4. When it feels right, copy the number back into `Config.luau`. Attributes don't save.

Good first knobs:

- **Floppier:** lower `Wobble_SpringDamping` (0.3) or `Wobble_SpringSpeed` (10).
- **Easier swings:** raise `Grab_Radius` (4.5), `Grab_SwingAccel` (90) or `Grab_ReleaseJumpForward` (20).
- **Longer dash:** raise `Dash_Speed` or `Carry_AfterDash`.
- **Fewer accidental flops:** raise `Ragdoll_HardLandingSpeed`.
- **Shared respawns:** set `Checkpoints_RespawnAt` to `Shared` to send fallers back to the last checkpoint you *both* reached.

## How it works

The one rule: **each player's computer only moves its own monkey.**

- Grabbing creates a rope from your root part to the branch, plus a push force for swinging. All of it
  is created on your client, so it responds instantly at any ping; the result replicates as normal
  character movement.
- No physics constraint ever joins the two monkeys. Joined assemblies share one network owner, so the
  other player's controls would lag. Monkeys also don't collide with each other (collision group
  `Monkeys`), which stops players flinging each other.
- After a dash or a release, the Humanoid's air control is paused for a moment ("carry") so it doesn't
  cancel your momentum.
- Ragdoll: the server builds BallSocket joints next to every Motor6D at spawn. Your client swaps them
  instantly; the server swaps them too so others see it, and forces you up after `Ragdoll_MaxTime`.
- The wobble offsets Motor6D C0 values on top of the animations, computed on every client from each
  monkey's speed. Client-side C0 changes don't replicate, so it costs no network traffic.
- Checkpoints are server-side and must be touched in order.

## Building your own level

- Tag anything climbable `Grabbable` (Properties > Tags). Branches you can also stand on stay solid;
  hang-only vines and bars should have **CanCollide off**, or a jump lands the monkey on top of them
  instead of in its hands.
- Checkpoints: a part tagged `Checkpoint` with a number attribute `Stage` (0 = start). Non-collidable works best.
- The ground: tag it `ForestFloor`, or just keep it below `Checkpoints_KillY`.
- Put your level in a Workspace folder named `Course`. The greybox builder then skips itself; or set
  `Debug_BuildTestCourse` to false.
- Keep the avatar type R15 (Game Settings > Avatar). Build the monkey on an R15 rig so the ragdoll,
  wobble and the 18+ DevEx rate all keep working. Both R15 joint types work: classic `Motor6D` rigs and
  Roblox's upgraded `AnimationConstraint` rigs (what your avatar uses today).

## Known Day 1 limits

- Roblox's own ladder climbing is turned off for monkeys (it grabbed stacked branches by itself).

- Mobile buttons use default positions and labels.
- No co-op moves yet (boost, pull-up, ping wheel). Those are Day 2.
- Exploit checks are basic (rate limits, in-order checkpoints). Day 6 adds timing and distance checks.
