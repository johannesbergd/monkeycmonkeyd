--!strict
-- A damped spring for Vector3 values. Used by the wobble to make bodies lag, overshoot and settle.
-- speed: how fast it chases the target. damping: < 1 overshoots (floppy), 1 settles without overshoot.

export type Spring = {
	position: Vector3,
	velocity: Vector3,
	target: Vector3,
}

local Spring = {}

local MAX_STEP = 1 / 60

function Spring.new(initial: Vector3?): Spring
	local start = initial or Vector3.zero
	return {
		position = start,
		velocity = Vector3.zero,
		target = start,
	}
end

function Spring.step(spring: Spring, dt: number, speed: number, damping: number)
	-- Sub-step so a frame hitch can't make the spring explode.
	local remaining = math.min(dt, 0.25)
	while remaining > 0 do
		local h = math.min(remaining, MAX_STEP)
		local accel = (spring.target - spring.position) * (speed * speed) - spring.velocity * (2 * damping * speed)
		spring.velocity += accel * h
		spring.position += spring.velocity * h
		remaining -= h
	end
end

return Spring
