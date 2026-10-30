class_name Board
extends RefCounted
## A board loaded from JSON (format: boards/README.md). Read-only after loading.

const TYPES := ["depot", "relay", "lot", "market", "wildcard", "workshop",
		"toll", "detour", "junction", "dice", "arcade",
		"interest", "break", "plot"]

var name := ""
var goal := 10000
var start_cash := 1500
var base_salary := 200
var relay_bonus := 150
var blocks := {}  # block id -> {name: String, color: Color}
var spaces: Array[Dictionary] = []
var depot := -1


static func load_file(path: String) -> Board:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("Board: cannot read %s" % path)
		return null
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Board: %s is not a JSON object" % path)
		return null
	var b := Board.new()
	var err := b.load_data(data)
	if err != "":
		push_error("Board %s: %s" % [path, err])
		return null
	return b


## Fills the board from parsed JSON. Returns "" or the first problem found.
func load_data(data: Dictionary) -> String:
	name = str(data.get("name", "Untitled"))
	goal = int(data.get("goal", goal))
	start_cash = int(data.get("start_cash", start_cash))
	base_salary = int(data.get("base_salary", base_salary))
	relay_bonus = int(data.get("relay_bonus", relay_bonus))

	var raw_blocks: Dictionary = data.get("blocks", {})
	for id in raw_blocks:
		var blk: Dictionary = raw_blocks[id]
		blocks[str(id)] = {
			"name": str(blk.get("name", id)),
			"color": Color.html(str(blk.get("color", "#888888"))),
		}

	var raw_spaces: Array = data.get("spaces", [])
	if raw_spaces.is_empty():
		return "no spaces"
	for i in raw_spaces.size():
		var s: Dictionary = raw_spaces[i]
		if int(s.get("id", -1)) != i:
			return "space %d has id %s (must equal its index)" % [i, s.get("id")]
		var type := str(s.get("type", ""))
		if type not in TYPES:
			return "space %d has unknown type '%s'" % [i, type]
		var next: Array[int] = []
		for n in s.get("next", []):
			next.append(int(n))
		var space := {
			"id": i,
			"type": type,
			"x": float(s.get("x", 0)),
			"y": float(s.get("y", 0)),
			"next": next,
			"name": str(s.get("name", "")),
			"block": str(s.get("block", "")),
			"price": int(s.get("price", 0)),
			"pair": int(s.get("pair", -1)),
			"mark": str(s.get("mark", "")),
			"color": Color.html(str(s.get("color", "#888888"))),
		}
		if type == "lot":
			if not blocks.has(space.block):
				return "lot %d has unknown block '%s'" % [i, space.block]
			if space.price <= 0:
				return "lot %d has no price" % i
		if type == "depot":
			if depot != -1:
				return "more than one depot (%d and %d)" % [depot, i]
			depot = i
		spaces.append(space)

	if depot == -1:
		return "no depot"
	for s in spaces:
		if s.next.is_empty():
			return "space %d has no next space" % s.id
		for n in s.next:
			if n < 0 or n >= spaces.size():
				return "space %d points to missing space %d" % [s.id, n]
		if s.type == "detour":
			if s.pair < 0 or s.pair >= spaces.size() or spaces[s.pair].type != "detour":
				return "detour %d has no valid pair" % s.id
	return ""


func lot_ids() -> Array[int]:
	var out: Array[int] = []
	for s in spaces:
		if s.type == "lot":
			out.append(s.id)
	return out


func lots_in_block(block: String) -> Array[int]:
	var out: Array[int] = []
	for s in spaces:
		if s.type == "lot" and s.block == block:
			out.append(s.id)
	return out


func relay_ids() -> Array[int]:
	var out: Array[int] = []
	for s in spaces:
		if s.type == "relay":
			out.append(s.id)
	return out
