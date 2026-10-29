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


func bonds_in(block: String) -> int:
	return bonds.get(block, 0)
