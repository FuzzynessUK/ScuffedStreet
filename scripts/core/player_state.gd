class_name PlayerState
extends RefCounted
## One player's position, money and holdings.

var index := 0
var name := ""
var is_cpu := false
var cash := 0
var position := 0
var came_from := -1          # space stepped from last; can't step straight back
var punches: Array[int] = [] # Relay ids punched this lap
var bonds := {}              # block id -> count
var at_goal := false         # net worth >= goal at the start of this turn
var broke := false
var skip_move := false    # Heavy Traffic: no roll next turn
var double_rent := false  # Double Rent: next rent collected is doubled
var any_suits := 0       # Any Suit cards held: each stands in for one missing suit
var level := 1           # 1 at the start, +1 at every PAYDAY (scales some prizes)
var commission := false  # Star space: 20% of others' profits until your next turn
var on_break := false    # Moon space: your lots are closed until your next turn
var creditor := -1       # who the last debt was owed to (player, or -1 the bank)
var reverse_next := false  # Reverse Gear / U-Turn: walk backwards next turn...
var reverse_move := false  # ...walking backwards this turn
var reverse_first := false  # the next step turns them round (first of the turn)


func bonds_in(block: String) -> int:
	return bonds.get(block, 0)
