--!strict
-- Tiny per-player rate limiter for remote events.
-- RateLimiter.new(10, 2) allows up to 10 calls per player in any 2-second window.

local Players = game:GetService("Players")

export type RateLimiter = {
	allow: (self: RateLimiter, player: Player) -> boolean,
}

local RateLimiter = {}

function RateLimiter.new(maxCalls: number, windowSeconds: number): RateLimiter
	local history: { [Player]: { number } } = {}

	Players.PlayerRemoving:Connect(function(player)
		history[player] = nil
	end)

	local limiter = {}

	function limiter.allow(_self: RateLimiter, player: Player): boolean
		local now = os.clock()
		local calls = history[player]
		if not calls then
			calls = {}
			history[player] = calls
		end
		-- Drop calls that have left the window.
		local kept = {}
		for _, t in calls do
			if now - t < windowSeconds then
				table.insert(kept, t)
			end
		end
		if #kept >= maxCalls then
			history[player] = kept
			return false
		end
		table.insert(kept, now)
		history[player] = kept
		return true
	end

	return limiter :: any
end

return RateLimiter
