class_name SongSearch
extends RefCounted
## The song menu's search match (owner, 2026-10-30: better results for Japanese songs): the typed text and a song's
## name, artist, mapper and BeatSaver tags are compared as loose keys, so case, spaces, punctuation and long vowels
## don't matter and kana in a title matches its romaji ("usseewa", "Ussewa" and "うっせぇわ" are one key). Kanji
## can't be read without a dictionary and stay as they are.

## Hiragana to Hepburn romaji; katakana is read as hiragana (KATAKANA_OFFSET below it).
const KANA := {
	"あ": "a", "い": "i", "う": "u", "え": "e", "お": "o",
	"か": "ka", "き": "ki", "く": "ku", "け": "ke", "こ": "ko",
	"が": "ga", "ぎ": "gi", "ぐ": "gu", "げ": "ge", "ご": "go",
	"さ": "sa", "し": "shi", "す": "su", "せ": "se", "そ": "so",
	"ざ": "za", "じ": "ji", "ず": "zu", "ぜ": "ze", "ぞ": "zo",
	"た": "ta", "ち": "chi", "つ": "tsu", "て": "te", "と": "to",
	"だ": "da", "ぢ": "ji", "づ": "zu", "で": "de", "ど": "do",
	"な": "na", "に": "ni", "ぬ": "nu", "ね": "ne", "の": "no",
	"は": "ha", "ひ": "hi", "ふ": "fu", "へ": "he", "ほ": "ho",
	"ば": "ba", "び": "bi", "ぶ": "bu", "べ": "be", "ぼ": "bo",
	"ぱ": "pa", "ぴ": "pi", "ぷ": "pu", "ぺ": "pe", "ぽ": "po",
	"ま": "ma", "み": "mi", "む": "mu", "め": "me", "も": "mo",
	"や": "ya", "ゆ": "yu", "よ": "yo",
	"ら": "ra", "り": "ri", "る": "ru", "れ": "re", "ろ": "ro",
	"わ": "wa", "ゐ": "i", "ゑ": "e", "を": "o", "ん": "n", "ゔ": "vu",
	"ぁ": "a", "ぃ": "i", "ぅ": "u", "ぇ": "e", "ぉ": "o", "ゎ": "wa",
}
## Small ya, yu, yo after an i-row kana: きゃ is "kya", しゃ "sha" (the i is dropped, and a y after sh, ch or j too).
const SMALL_Y := {"ゃ": "a", "ゅ": "u", "ょ": "o"}
## The small tsu doubles the next consonant; the long-vowel mark repeats the vowel (dropped by the long-vowel rule).
const SMALL_TSU := "っ"
const LONG_MARK := "ー"
## Code point distance from a katakana to its hiragana.
const KATAKANA_OFFSET := 0x60
const KATAKANA_FIRST := 0x30A1
const KATAKANA_LAST := 0x30F4
## Long vowels and doubled letters written either way in romaji ("ou"/"oo"/"o", "ss"/"s") read as one.
const LONG_VOWELS := ["ou", "oo", "uu", "aa", "ii", "ee", "ei"]

## Each song's loose key by its folder, with the tags it was made with (tags arrive later for older songs), so a
## search key press doesn't read every title again.
static var _keys := {}

## True if every word of the typed text is in the song's name, artist, mapper or tags (as loose keys).
static func matches(text: String, map: MapInfo, tags: PackedStringArray) -> bool:
	var joined := " ".join(tags)
	var cached: Array = _keys.get(map.filepath, [])
	if cached.is_empty() or cached[0] != joined:
		cached = [joined, key("%s %s %s %s" % [map.song_name, map.song_author_name, map.level_author_name, joined])]
		_keys[map.filepath] = cached
	var haystack: String = cached[1]
	for word in text.split(" ", false):
		if not haystack.contains(key(word)):
			return false
	return true

## The loose form of text: kana read as romaji, lower case, only letters, digits and other scripts' characters,
## long vowels and doubled letters as one.
static func key(text: String) -> String:
	var romaji := ""
	var double_next := false
	for i in text.length():
		var c := text[i]
		var code := c.unicode_at(0)
		if code >= KATAKANA_FIRST and code <= KATAKANA_LAST:
			c = String.chr(code - KATAKANA_OFFSET)
		if c == SMALL_TSU:
			double_next = true
			continue
		if SMALL_Y.has(c) and romaji.ends_with("i"):
			romaji = romaji.left(-1)
			if not (romaji.ends_with("sh") or romaji.ends_with("ch") or romaji.ends_with("j")):
				romaji += "y"
			romaji += SMALL_Y[c]
			continue
		var read: String = KANA.get(c, c.to_lower())
		if double_next and KANA.has(c):
			read = read[0] + read
		double_next = false
		if c == LONG_MARK:
			read = romaji.right(1)
		romaji += read
	var loose := ""
	for i in romaji.length():
		var c := romaji[i]
		# spaces and punctuation drop out; letters, digits and other scripts (kanji, hangul) stay
		if c.unicode_at(0) < 0x80 and not (c.is_valid_int() or (c >= "a" and c <= "z")):
			continue
		if not loose.is_empty() and loose.right(1) == c and c >= "a" and c <= "z":
			continue
		loose += c
	for pair: String in LONG_VOWELS:
		loose = loose.replace(pair, pair[0])
	return loose
