class_name StatPills
## A difficulty's short stats as pills (owner, 2026-10-27: the long details under a difficulty compressed into pills,
## with icons where they fit): each an icon and a value on a dark surface, for a RichTextLabel. The song menu's
## stats line and the Download page's details both use them, so a stat looks the same on both.
## - time to get ready for each note: seconds a note is in view before it arrives ("1.00 s"),
## - notes to hit per second ("4.6 notes/s"),
## - how twisty its swings are: the percent of swings that break the flow and its band ("6% Twisty",
##   Constants.FLOW_LEVELS); every value carries its unit (owner, 2026-10-27),
## and on the song menu its length and a workout's sets.

const READY_ICON := "res://game/ui/icons/timer.svg"
const NPS_ICON := "res://game/ui/icons/zap.svg"
const FLOW_ICON := "res://game/ui/icons/shuffle.svg"
const LENGTH_ICON := "res://game/ui/icons/clock.svg"
const WORKOUT_ICON := "res://game/ui/icons/dumbbell.svg"
## between pills: no-break spaces, so a line wraps between pills, never inside one
const GAP := "  "

## One pill: icon (size px, in UI_TEXT) and text on UI_SURFACE.
static func pill(icon: String, text: String, size: int) -> String:
	return "[bgcolor=#%s] [img width=%d height=%d color=#%s]%s[/img] %s [/bgcolor]" % [
		Constants.UI_SURFACE.to_html(false), size, size, Constants.UI_TEXT.to_html(false), icon, text.replace(" ", " ")]

## The three pills of a difficulty: get ready, notes per second (left out when unknown), swing flow from the
## percent of swings that break it.
static func difficulty(ready_seconds: float, notes_per_second: float, flow_percent: float, size: int) -> String:
	var pills := PackedStringArray([pill(READY_ICON, "%.2f s" % ready_seconds, size)])
	if notes_per_second > 0.0:
		pills.append(pill(NPS_ICON, "%.1f notes/s" % notes_per_second, size))
	pills.append(pill(FLOW_ICON, "%d%% %s" % [roundi(flow_percent), Constants.FLOW_LEVELS[MapStats.flow_level(flow_percent)][0]], size))
	return GAP.join(pills)

## A length in minutes and seconds, as a pill.
static func length(seconds: float, size: int) -> String:
	return pill(LENGTH_ICON, "%d:%02d" % [int(seconds) / 60, int(seconds) % 60], size)

## A workout's sets ("3 sets"), as a pill.
static func workout(sets: int, size: int) -> String:
	return pill(WORKOUT_ICON, "%d %s" % [sets, "set" if sets == 1 else "sets"], size)
