class_name Health
## The player's health rules, apart from the game scene so they can be tested (tests/test_health.gd): what a song
## starts with and what a change does in each fail mode. BeepSaber_Game keeps the value, the rails and the fail.

## Health a song starts with: half in the health bar mode (and the hidden bar of No Fail), full with lives or Instant.
static func start_value(health_mode: bool, fail_mode: int) -> float:
	if health_mode and fail_mode != Constants.FAIL_MODE_BAR:
		return Constants.HEALTH_MAX
	return Constants.HEALTH_START

## Health after a change of delta; mistake is a miss, bad cut, bomb or wall entry, which costs a life in 4 Lives mode
## and all of it in Instant. Damage in the bar mode is scaled by damage_scale; No Fail's hidden bar isn't. Never
## more than HEALTH_MAX.
static func next_value(value: float, delta: float, mistake: bool, health_mode: bool, fail_mode: int,
		damage_scale: float) -> float:
	if not health_mode:
		return minf(value + delta, Constants.HEALTH_MAX)
	match fail_mode:
		Constants.FAIL_MODE_LIVES:
			if mistake:
				value -= Constants.HEALTH_MAX / Constants.FAIL_LIVES
		Constants.FAIL_MODE_INSTANT:
			if mistake:
				value = 0.0
		_:
			value += delta * damage_scale if delta < 0.0 else delta
	return minf(value, Constants.HEALTH_MAX)
