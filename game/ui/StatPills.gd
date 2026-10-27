class_name StatPills
## A difficulty's short stats as pills (owner, 2026-10-27: the long details under a difficulty compressed into pills,
## with icons where they fit): each an icon and a value on a dark surface, for a RichTextLabel. The song menu's
## stats line and the Download page's details both use them, so a stat looks the same on both.
## - time to get ready for each note (seconds a note is in view before it arrives),
## - notes to hit per second,
## - how twisty its swings are (Constants.FLOW_LEVELS),
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

## The three pills of a difficulty: get ready, notes per second (left out when unknown), swing flow.
static func difficulty(ready_seconds: float, notes_per_second: float, flow: int, size: int) -> String:
	var pills := PackedStringArray([pill(READY_ICON, "%.2f s" % ready_seconds, size)])
	if notes_per_second > 0.0:
		pills.append(pill(NPS_ICON, "%.1f/s" % notes_per_second, size))
	pills.append(pill(FLOW_ICON, Constants.FLOW_LEVELS[clampi(flow, 0, Constants.FLOW_LEVELS.size() - 1)][0], size))
	return GAP.join(pills)

## A length in minutes and seconds, as a pill.
static func length(seconds: float, size: int) -> String:
	return pill(LENGTH_ICON, "%d:%02d" % [int(seconds) / 60, int(seconds) % 60], size)

## A workout's sets ("3 sets"), as a pill.
static func workout(sets: int, size: int) -> String:
	return pill(WORKOUT_ICON, "%d %s" % [sets, "set" if sets == 1 else "sets"], size)
