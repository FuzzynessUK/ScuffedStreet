class_name Wildcards
extends RefCounted
## The Wildcard deck and its effects (docs/DESIGN.md, "Wildcards").
##
## Each card is data: its name and text, what the player must pick, and an
## effect (`fx`) with its amounts. Many cards share an effect with different
## amounts (Lucky Find and Spare Change are both "gain"). The Scrap Heap's
## table draws 64 of the cards each time it is laid (GameState._refill_heap).
##
## A card's `pick` says what the player must choose before it resolves:
##   none, own_lot, own_lot_upgradable, rival_lot, rival_player, block, swap,
##   slot (a block drawn at random, never chosen - the UI shows a reel),
##   space (any space but your own), relay (a suit space) or optional (go or
##   not: a null pick declines)
## choices() lists the valid picks (an empty list for a picking card means it
## fizzles); apply() resolves the card and returns follow-ups for the
## controller: {"move_again": true}, {"land_again": true},
## {"minigame": true, "game": "" (any) or a minigame}, or {"invest": rate}.
##
## Effects and their amounts:
##   gain amount, pay_bank amount                     G from / to the bank
##   gain_random min max                              a random amount (in tens) from the bank
##   collect_each amount, pay_each amount             G from / to every other player
##   all_gain amount, all_pay amount                  every player gets / pays the bank
##   gain_cash_pct pct, pay_cash_pct pct              a share of your cash
##   gain_net_pct pct, pay_net_pct pct                a share of your net worth
##   gain_lot_pct pct                                 a share of your lots' value
##   gain_per_lot amount, pay_per_lot amount          for each lot you own
##   pay_per_tier amount                              for each building tier you own
##   boost_lot mult, boost_block mult, devalue mult   a lot's (your block's) value, for good
##   blackout, blackout_block                         a rival lot (their block) earns no rent
##   bond_swing swing, free_bonds count               a block's bonds (drawn on the reel)
##   bond_discount count discount, bond_dividend amount (per bond held)
##   free_invest share, invest_rate rate              investment free / at a discount
##   move_again, move_ahead steps, to_random, to_relay, to_depot
##   skip, skip_rival                                 no move next turn (you / a rival)
##   double_rent, commission                          next rent doubled / the Star's commission
##   any_suit, free_suit, lose_suit                   Any Suit card, a suit punched / lost
##   minigame game                                    a minigame now ("" picks one)
##   charity amount, rich_pays_all amount, take_from_richest amount
##   swap                                             one of your Shacks for a rival's
##   warp_any, warp_bank, warp_relay                  warp to a space, the Bank, a suit
##                                                    (the suit is punched; no landing)
##   reverse, reverse_rival                           walk backwards next turn (you, a rival)
##   forced_sale                                      sell a lot to the bank at 2x, then auction

const CARDS := [
	# The first 20 keep their ids (the tests and the Test Lab use some).
	{"name": "Scrap Drive", "text": "Every other player pays you 40 G.", "pick": "none", "fx": "collect_each", "amount": 40},
	{"name": "Parking Ticket", "text": "Pay a 100 G parking fine to the bank.", "pick": "none", "fx": "pay_bank", "amount": 100},
	{"name": "Rush Hour", "text": "Roll again and move.", "pick": "none", "fx": "move_again"},
	{"name": "Inspection", "text": "Pay 25 G for every building tier you own (Shop 1, Store 2, Megamart 3).", "pick": "none", "fx": "pay_per_tier", "amount": 25},
	{"name": "Grand Opening", "text": "One of your lots gains +20% value for good.", "pick": "own_lot", "fx": "boost_lot", "mult": 1.2},
	{"name": "Power Cut", "text": "A rival's lot charges no rent until their next turn.", "pick": "rival_lot", "fx": "blackout"},
	{"name": "Lucky Find", "text": "Gain 150 G.", "pick": "none", "fx": "gain", "amount": 150},
	{"name": "Bond Bump", "text": "A block's bond price rises 15%.", "pick": "slot", "fx": "bond_swing", "swing": 0.15},
	{"name": "Bond Slump", "text": "A block's bond price falls 15%.", "pick": "slot", "fx": "bond_swing", "swing": -0.15},
	{"name": "Shortcut", "text": "Jump to the nearest Relay you haven't punched.", "pick": "none", "fx": "to_relay"},
	{"name": "Tax Refund", "text": "Gain 5% of your lot value.", "pick": "none", "fx": "gain_lot_pct", "pct": 0.05},
	{"name": "Swap Meet", "text": "Swap one of your Shacks for a rival's Shack, paying the difference if theirs is worth more.", "pick": "swap", "fx": "swap"},
	{"name": "Charity", "text": "The richest player gives 100 G to the poorest.", "pick": "none", "fx": "charity", "amount": 100},
	{"name": "Back to Base", "text": "Go straight to the Depot (PAYDAY if you hold every suit).", "pick": "none", "fx": "to_depot"},
	{"name": "Free Renovation", "text": "Invest in one of your lots for free: capital worth its base price.", "pick": "own_lot_upgradable", "fx": "free_invest", "share": 1.0},
	{"name": "Lucky Dip", "text": "Dip into the lucky tub: win 50 to 250 G.", "pick": "none", "fx": "gain_random", "min": 50, "max": 250},
	{"name": "Heavy Traffic", "text": "You don't move on your next turn.", "pick": "none", "fx": "skip"},
	{"name": "Double Rent", "text": "The next rent you collect is doubled.", "pick": "none", "fx": "double_rent"},
	{"name": "Market Tip", "text": "Buy up to 10 bonds in a block at 10% off.", "pick": "block", "fx": "bond_discount", "count": 10, "discount": 0.9},
	{"name": "Scrap Tax", "text": "Pay 10% of your cash to the bank.", "pick": "none", "fx": "pay_cash_pct", "pct": 0.1},
	{"name": "Any Suit", "text": "Keep this card: it stands in for a missing suit at PAYDAY. If you already have all four, the bank leaves it with you.", "pick": "none", "fx": "any_suit"},
	{"name": "Any Suit", "text": "Keep this card: it stands in for a missing suit at PAYDAY. If you already have all four, the bank leaves it with you.", "pick": "none", "fx": "any_suit"},
	{"name": "Any Suit", "text": "Keep this card: it stands in for a missing suit at PAYDAY. If you already have all four, the bank leaves it with you.", "pick": "none", "fx": "any_suit"},
	{"name": "Arcade Ticket", "text": "Play a minigame now.", "pick": "none", "fx": "minigame", "game": ""},
	# Money from the bank.
	{"name": "Spare Change", "text": "Gain 50 G.", "pick": "none", "fx": "gain", "amount": 50},
	{"name": "Tip Off", "text": "A good tip pays off: gain 60 G.", "pick": "none", "fx": "gain", "amount": 60},
	{"name": "Bottle Deposit", "text": "Return the empties: gain 80 G.", "pick": "none", "fx": "gain", "amount": 80},
	{"name": "Cashback", "text": "Gain 90 G cashback.", "pick": "none", "fx": "gain", "amount": 90},
	{"name": "Found Wallet", "text": "The owner's reward: gain 100 G.", "pick": "none", "fx": "gain", "amount": 100},
	{"name": "Garage Sale", "text": "Sell the clutter: gain 120 G.", "pick": "none", "fx": "gain", "amount": 120},
	{"name": "Prize Draw", "text": "Your ticket wins: gain 200 G.", "pick": "none", "fx": "gain", "amount": 200},
	{"name": "Scratch Card", "text": "Three in a row: gain 250 G.", "pick": "none", "fx": "gain", "amount": 250},
	{"name": "Golden Ticket", "text": "Gain 300 G.", "pick": "none", "fx": "gain", "amount": 300},
	{"name": "Inheritance", "text": "A distant aunt remembers you: gain 400 G.", "pick": "none", "fx": "gain", "amount": 400},
	# Money to the bank.
	{"name": "Library Fine", "text": "Pay 30 G to the bank.", "pick": "none", "fx": "pay_bank", "amount": 30},
	{"name": "Vet Bill", "text": "Pay 40 G to the bank.", "pick": "none", "fx": "pay_bank", "amount": 40},
	{"name": "Broken Window", "text": "Pay 60 G to the bank.", "pick": "none", "fx": "pay_bank", "amount": 60},
	{"name": "Speeding Fine", "text": "Pay 80 G to the bank.", "pick": "none", "fx": "pay_bank", "amount": 80},
	{"name": "Dentist", "text": "Pay 90 G to the bank.", "pick": "none", "fx": "pay_bank", "amount": 90},
	{"name": "Fridge Broke", "text": "Pay 110 G to the bank.", "pick": "none", "fx": "pay_bank", "amount": 110},
	{"name": "Roof Leak", "text": "Pay 120 G to the bank.", "pick": "none", "fx": "pay_bank", "amount": 120},
	{"name": "Burst Pipe", "text": "Pay 150 G to the bank.", "pick": "none", "fx": "pay_bank", "amount": 150},
	{"name": "Tow Truck", "text": "Pay 200 G to the bank.", "pick": "none", "fx": "pay_bank", "amount": 200},
	# Small bills.
	{"name": "Street Busker", "text": "Tip a busker 20 G (to the bank).", "pick": "none", "fx": "pay_bank", "amount": 20},
	{"name": "Charity Raffle", "text": "Buy 50 G of raffle tickets (to the bank).", "pick": "none", "fx": "pay_bank", "amount": 50},
	{"name": "Toll Booth", "text": "Pay an 80 G toll to the bank.", "pick": "none", "fx": "pay_bank", "amount": 80},
	{"name": "Clamped!", "text": "Pay 150 G to the bank to get your wheels back.", "pick": "none", "fx": "pay_bank", "amount": 150},
	# Money between players.
	{"name": "Birthday", "text": "Every other player gives you 20 G.", "pick": "none", "fx": "collect_each", "amount": 20},
	{"name": "Street Collection", "text": "Every other player pays you 30 G.", "pick": "none", "fx": "collect_each", "amount": 30},
	{"name": "Whip-Round", "text": "Every other player pays you 50 G.", "pick": "none", "fx": "collect_each", "amount": 50},
	{"name": "Block Party", "text": "Every other player pays you 60 G.", "pick": "none", "fx": "collect_each", "amount": 60},
	{"name": "Street Fair", "text": "Every other player pays you 80 G.", "pick": "none", "fx": "collect_each", "amount": 80},
	{"name": "Round of Drinks", "text": "Pay every other player 20 G.", "pick": "none", "fx": "pay_each", "amount": 20},
	{"name": "Gift Shopping", "text": "Pay every other player 30 G.", "pick": "none", "fx": "pay_each", "amount": 30},
	{"name": "Wedding Gifts", "text": "Pay every other player 40 G.", "pick": "none", "fx": "pay_each", "amount": 40},
	{"name": "Treat the Street", "text": "Pay every other player 50 G.", "pick": "none", "fx": "pay_each", "amount": 50},
	{"name": "Lost Bet", "text": "Pay every other player 80 G.", "pick": "none", "fx": "pay_each", "amount": 80},
	{"name": "Street Party", "text": "Everyone gains 50 G from the bank.", "pick": "none", "fx": "all_gain", "amount": 50},
	{"name": "Heat Wave", "text": "Everyone pays the bank 30 G for fans.", "pick": "none", "fx": "all_pay", "amount": 30},
	{"name": "Share the Wealth", "text": "The richest player pays every other player 30 G.", "pick": "none", "fx": "rich_pays_all", "amount": 30},
	{"name": "Helping Hand", "text": "The richest player gives 200 G to the poorest.", "pick": "none", "fx": "charity", "amount": 200},
	{"name": "Tip Jar", "text": "The richest rival pays you 60 G.", "pick": "none", "fx": "take_from_richest", "amount": 60},
	{"name": "Finder's Fee", "text": "The richest rival pays you 100 G.", "pick": "none", "fx": "take_from_richest", "amount": 100},
	# Shares of what you have.
	{"name": "Interest Payment", "text": "Gain 5% of your cash.", "pick": "none", "fx": "gain_cash_pct", "pct": 0.05},
	{"name": "Savings Bonus", "text": "Gain 10% of your cash.", "pick": "none", "fx": "gain_cash_pct", "pct": 0.1},
	{"name": "Service Charge", "text": "Pay 5% of your cash to the bank.", "pick": "none", "fx": "pay_cash_pct", "pct": 0.05},
	{"name": "Luxury Tax", "text": "Pay 15% of your cash to the bank.", "pick": "none", "fx": "pay_cash_pct", "pct": 0.15},
	{"name": "Wealth Award", "text": "Gain 2% of your net worth.", "pick": "none", "fx": "gain_net_pct", "pct": 0.02},
	{"name": "Means Test", "text": "Pay 2% of your net worth to the bank.", "pick": "none", "fx": "pay_net_pct", "pct": 0.02},
	{"name": "Rent Rebate", "text": "Gain 3% of your lot value.", "pick": "none", "fx": "gain_lot_pct", "pct": 0.03},
	{"name": "Property Award", "text": "Gain 8% of your lot value.", "pick": "none", "fx": "gain_lot_pct", "pct": 0.08},
	# By what you own.
	{"name": "Window Cleaning", "text": "Gain 10 G for every lot you own.", "pick": "none", "fx": "gain_per_lot", "amount": 10},
	{"name": "Rent Day", "text": "Gain 15 G for every lot you own.", "pick": "none", "fx": "gain_per_lot", "amount": 15},
	{"name": "Tenant Gifts", "text": "Gain 25 G for every lot you own.", "pick": "none", "fx": "gain_per_lot", "amount": 25},
	{"name": "Ground Rent", "text": "Pay 10 G for every lot you own.", "pick": "none", "fx": "pay_per_lot", "amount": 10},
	{"name": "Gardening Bill", "text": "Pay 20 G for every lot you own.", "pick": "none", "fx": "pay_per_lot", "amount": 20},
	{"name": "Safety Check", "text": "Pay 15 G for every building tier you own.", "pick": "none", "fx": "pay_per_tier", "amount": 15},
	{"name": "Rates Bill", "text": "Pay 40 G for every building tier you own.", "pick": "none", "fx": "pay_per_tier", "amount": 40},
	# Lot values.
	{"name": "Window Boxes", "text": "One of your lots gains +5% value for good.", "pick": "own_lot", "fx": "boost_lot", "mult": 1.05},
	{"name": "Fresh Paint", "text": "One of your lots gains +10% value for good.", "pick": "own_lot", "fx": "boost_lot", "mult": 1.1},
	{"name": "Big Sign", "text": "One of your lots gains +15% value for good.", "pick": "own_lot", "fx": "boost_lot", "mult": 1.15},
	{"name": "Five-Star Review", "text": "One of your lots gains +25% value for good.", "pick": "own_lot", "fx": "boost_lot", "mult": 1.25},
	{"name": "Celebrity Visit", "text": "One of your lots gains +30% value for good.", "pick": "own_lot", "fx": "boost_lot", "mult": 1.3},
	{"name": "Street Lights", "text": "Your lots in one block gain +10% value for good.", "pick": "own_lot", "fx": "boost_block", "mult": 1.1},
	{"name": "New Park", "text": "Your lots in one block gain +15% value for good.", "pick": "own_lot", "fx": "boost_block", "mult": 1.15},
	{"name": "Graffiti", "text": "A rival's lot loses 5% of its value.", "pick": "rival_lot", "fx": "devalue", "mult": 0.95},
	{"name": "Pothole", "text": "A rival's lot loses 8% of its value.", "pick": "rival_lot", "fx": "devalue", "mult": 0.92},
	{"name": "Bad Review", "text": "A rival's lot loses 10% of its value.", "pick": "rival_lot", "fx": "devalue", "mult": 0.9},
	{"name": "Water Cut", "text": "A rival's lot charges no rent until their next turn.", "pick": "rival_lot", "fx": "blackout"},
	{"name": "Road Works", "text": "A rival's lots in one block charge no rent until their next turn.", "pick": "rival_lot", "fx": "blackout_block"},
	{"name": "Strike", "text": "A rival's lots in one block charge no rent until their next turn.", "pick": "rival_lot", "fx": "blackout_block"},
	# Bonds.
	{"name": "Small Rally", "text": "A block's bond price rises 8%.", "pick": "slot", "fx": "bond_swing", "swing": 0.08},
	{"name": "Good Rumour", "text": "A block's bond price rises 10%.", "pick": "slot", "fx": "bond_swing", "swing": 0.1},
	{"name": "Bond Boom", "text": "A block's bond price rises 25%.", "pick": "slot", "fx": "bond_swing", "swing": 0.25},
	{"name": "Small Dip", "text": "A block's bond price falls 8%.", "pick": "slot", "fx": "bond_swing", "swing": -0.08},
	{"name": "Bad Rumour", "text": "A block's bond price falls 10%.", "pick": "slot", "fx": "bond_swing", "swing": -0.1},
	{"name": "Bond Crash", "text": "A block's bond price falls 25%.", "pick": "slot", "fx": "bond_swing", "swing": -0.25},
	{"name": "Bond Voucher", "text": "Get 2 bonds in a block for free.", "pick": "slot", "fx": "free_bonds", "count": 2},
	{"name": "Bond Gift", "text": "Get 3 bonds in a block for free.", "pick": "slot", "fx": "free_bonds", "count": 3},
	{"name": "Bond Hamper", "text": "Get 5 bonds in a block for free.", "pick": "slot", "fx": "free_bonds", "count": 5},
	{"name": "Bond Sale", "text": "Buy up to 5 bonds in a block at 20% off.", "pick": "block", "fx": "bond_discount", "count": 5, "discount": 0.8},
	{"name": "Insider Hint", "text": "Buy up to 15 bonds in a block at 5% off.", "pick": "block", "fx": "bond_discount", "count": 15, "discount": 0.95},
	{"name": "Dividend Day", "text": "Gain 2 G for every bond you hold.", "pick": "none", "fx": "bond_dividend", "amount": 2},
	{"name": "Bumper Dividend", "text": "Gain 4 G for every bond you hold.", "pick": "none", "fx": "bond_dividend", "amount": 4},
	# Investing.
	{"name": "Builder's Favour", "text": "Invest in one of your lots for free: capital worth a quarter of its base price.", "pick": "own_lot_upgradable", "fx": "free_invest", "share": 0.25},
	{"name": "Handyman Visit", "text": "Invest in one of your lots for free: capital worth half its base price.", "pick": "own_lot_upgradable", "fx": "free_invest", "share": 0.5},
	{"name": "Builders' Sale", "text": "Invest in your lots now at 70% of the price.", "pick": "none", "fx": "invest_rate", "rate": 0.7},
	{"name": "Trade Discount", "text": "Invest in your lots now at 85% of the price.", "pick": "none", "fx": "invest_rate", "rate": 0.85},
	# Mystery prizes.
	{"name": "Penny Jar", "text": "Shake out the penny jar: win 10 to 100 G.", "pick": "none", "fx": "gain_random", "min": 10, "max": 100},
	{"name": "Raffle Win", "text": "Your raffle ticket comes up: win 50 to 300 G.", "pick": "none", "fx": "gain_random", "min": 50, "max": 300},
	{"name": "Treasure Chest", "text": "Open the chest: win 100 to 500 G.", "pick": "none", "fx": "gain_random", "min": 100, "max": 500},
	{"name": "Wishing Well", "text": "Make a wish: win 20 to 150 G.", "pick": "none", "fx": "gain_random", "min": 20, "max": 150},
	{"name": "Mystery Box", "text": "Open the box: anything from losing 100 G to winning 200 G.", "pick": "none", "fx": "gain_random", "min": -100, "max": 200},
	# Getting about.
	{"name": "Scooter", "text": "Ride 1 space ahead and land there (nothing on the way counts).", "pick": "none", "fx": "move_ahead", "steps": 1},
	{"name": "Bike Ride", "text": "Ride 2 spaces ahead and land there (nothing on the way counts).", "pick": "none", "fx": "move_ahead", "steps": 2},
	{"name": "Taxi Ride", "text": "Ride 3 spaces ahead and land there (nothing on the way counts).", "pick": "none", "fx": "move_ahead", "steps": 3},
	{"name": "Express Bus", "text": "Ride 5 spaces ahead and land there (nothing on the way counts).", "pick": "none", "fx": "move_ahead", "steps": 5},
	{"name": "Train Trip", "text": "Ride 6 spaces ahead and land there (nothing on the way counts).", "pick": "none", "fx": "move_ahead", "steps": 6},
	{"name": "Wrong Bus", "text": "Off to a random space, and land there.", "pick": "none", "fx": "to_random"},
	{"name": "Flat Tyre", "text": "You don't move on your next turn.", "pick": "none", "fx": "skip"},
	{"name": "Gridlock", "text": "A rival doesn't move on their next turn.", "pick": "rival_player", "fx": "skip_rival"},
	# Suits and the Star.
	{"name": "Warp Gate", "text": "Warp to any space you choose, and land there.", "pick": "space", "fx": "warp_any"},
	{"name": "Suit Up", "text": "One suit you are missing is punched for you.", "pick": "none", "fx": "free_suit"},
	{"name": "Relay Pass", "text": "One suit you are missing is punched for you.", "pick": "none", "fx": "free_suit"},
	{"name": "Lost Stamp", "text": "You lose one of the suits you have punched this lap.", "pick": "none", "fx": "lose_suit"},
	{"name": "Talent Agent", "text": "Until your next turn you take the Star's commission on others' profits.", "pick": "none", "fx": "commission"},
	# Minigames.
	{"name": "Slot Token", "text": "Play Scrap Slots now.", "pick": "none", "fx": "minigame", "game": "slots"},
	{"name": "Card Shark", "text": "Play Pick a Card now.", "pick": "none", "fx": "minigame", "game": "pick_a_card"},
	{"name": "Wheel Spin", "text": "Play the Chance Wheel now.", "pick": "none", "fx": "minigame", "game": "wheel"},
	{"name": "Race Day", "text": "Everyone plays Critter Race now.", "pick": "none", "fx": "minigame", "game": "race"},
	# Getting about the board.
	{"name": "Bank Shuttle", "text": "Take the shuttle to the Bank if you like (PAYDAY if you hold every suit), or stay where you are.", "pick": "optional", "fx": "warp_bank"},
	{"name": "Suit Hopper", "text": "Jump to a suit space of your choice and punch its suit (no card from the Scrap Heap there).", "pick": "relay", "fx": "warp_relay"},
	{"name": "Reverse Gear", "text": "On your next turn you walk backwards.", "pick": "none", "fx": "reverse"},
	{"name": "U-Turn", "text": "Pick a rival: on their next turn they walk backwards.", "pick": "rival_player", "fx": "reverse_rival"},
	# Selling up.
	{"name": "Fire Sale", "text": "Sell one of your lots to the bank for twice its value. It then goes to auction.", "pick": "own_lot", "fx": "forced_sale"},
]
const ANY_SUIT := 20  # the first of the three Any Suit cards (numbers 21-23)
const ANY_SUITS := [20, 21, 22]
const ARCADE_TICKET := 23
## Cards in every Scrap Heap table, and how many times: card id -> copies.
const COPIES := {20: 1, 21: 1, 22: 1, ARCADE_TICKET: 3}
const BOND_SWING := 0.15  # Bond Bump / Slump
const FIRE_SALE_RATE := 2.0  # Fire Sale: the bank pays twice the value
const MIN_BOOST := 0.5  # devalue cards never take a lot below half its worth


static func card(id: int) -> Dictionary:
	return CARDS[id]


## The card called `name` ({} if there is none).
static func by_name(name: String) -> Dictionary:
	for c in CARDS:
		if c.name == name:
			return c
	return {}


## Valid picks for the card: lot ids, block ids, player indexes, or
## [mine, theirs] pairs for swap.
static func choices(g: GameState, p: PlayerState, id: int) -> Array:
	var out := []
	match CARDS[id].pick:
		"own_lot":
			for lot in g.lots:
				if g.lots[lot].owner == p.index:
					out.append(lot)
		"own_lot_upgradable":
			for lot in g.lots:
				if g.lots[lot].owner == p.index and g.max_capital(lot) > 0:
					out.append(lot)
		"rival_lot":
			for lot in g.lots:
				if g.lots[lot].owner >= 0 and g.lots[lot].owner != p.index:
					out.append(lot)
		"rival_player":
			for q in g.players:
				if q != p and not q.broke:
					out.append(q.index)
		"block", "slot":
			out.assign(g.board.blocks.keys())
		"space":
			for sp in g.board.spaces:
				if sp.id != p.position:
					out.append(sp.id)
		"relay":
			out.assign(g.board.relay_ids())
		"optional":
			out.append(true)
		"swap":
			for mine in g.lots:
				if g.lots[mine].owner != p.index or g.lots[mine].capital != 0:
					continue
				for theirs in g.lots:
					var o: int = g.lots[theirs].owner
					if o >= 0 and o != p.index and g.lots[theirs].capital == 0:
						out.append([mine, theirs])
	return out


static func apply(g: GameState, p: PlayerState, id: int, pick = null) -> Dictionary:
	var c: Dictionary = CARDS[id]
	g._note("%s draws %s: %s" % [p.name, c.name, c.text], "card", p.index, p.position)
	if c.pick == "optional" and pick == null:
		g._note("%s stays put." % p.name, "info", p.index)
		return {}
	if c.pick != "none" and pick == null:
		g._note("...but there is nothing to choose, so nothing happens.", "info", p.index)
		return {}
	var rivals := g.players.filter(func(q): return q != p and not q.broke)
	match c.fx:
		"gain":
			g.earn(p, c.amount)
		"pay_bank":
			g.charge(p, c.amount, -1)
		"gain_random":
			var won: int = g.rng.randi_range(c.min / 10, c.max / 10) * 10
			if won >= 0:
				g.earn(p, won)
			else:
				g.charge(p, -won, -1)
		"collect_each":
			for q in rivals:
				if not g.game_over:
					g.charge(q, c.amount, p.index)
		"pay_each":
			for q in rivals:
				if not g.game_over and not p.broke:
					g.charge(p, c.amount, q.index)
		"all_gain":
			for q in g.players:
				if not q.broke:
					g.earn(q, c.amount)
		"all_pay":
			for q in g.players:
				if not q.broke and not g.game_over:
					g.charge(q, c.amount, -1)
		"gain_cash_pct":
			g.earn(p, roundi(maxi(p.cash, 0) * c.pct))
		"pay_cash_pct":
			var tax := roundi(maxi(p.cash, 0) * c.pct)
			if tax > 0:
				g.charge(p, tax, -1)
		"gain_net_pct":
			g.earn(p, roundi(maxi(g.net_worth(p), 0) * c.pct))
		"pay_net_pct":
			var due := roundi(maxi(g.net_worth(p), 0) * c.pct)
			if due > 0:
				g.charge(p, due, -1)
		"gain_lot_pct":
			g.earn(p, roundi(g.lot_worth(p) * c.pct))
		"gain_per_lot", "pay_per_lot":
			var count := _owned(g, p).size()
			if count > 0:
				if c.fx == "gain_per_lot":
					g.earn(p, count * c.amount)
				else:
					g.charge(p, count * c.amount, -1)
		"pay_per_tier":
			var tiers := 0
			for lot in _owned(g, p):
				tiers += g.tier(lot)
			if tiers > 0:
				g.charge(p, tiers * c.amount, -1)
		"boost_lot":
			_boost(g, pick, c.mult, p)
		"boost_block":
			for lot in _owned(g, p):
				if g.space(lot).block == g.space(pick).block:
					_boost(g, lot, c.mult, p)
		"devalue":
			g.lots[pick].boost = maxf(MIN_BOOST, g.lots[pick].boost * c.mult)
			g._note("%s is worth %d G now" % [g._label(pick), g.lot_value(pick)], "loss",
					g.lots[pick].owner, pick)
		"blackout":
			g.lots[pick].blackout = true
			g._note("%s loses power" % g._label(pick), "loss", g.lots[pick].owner, pick)
		"blackout_block":
			var owner: int = g.lots[pick].owner
			for lot in g.lots:
				if g.lots[lot].owner == owner and g.space(lot).block == g.space(pick).block:
					g.lots[lot].blackout = true
					g._note("%s shuts" % g._label(lot), "loss", owner, lot)
		"bond_swing":
			g.bond_pressure[pick] = g.bond_pressure.get(pick, 1.0) * (1.0 + c.swing)
			g._note("Block %s bonds now %d G" % [g.board.blocks[pick].name, g.bond_price(pick)], "info", p.index)
		"free_bonds":
			p.bonds[pick] = p.bonds_in(pick) + c.count
			g._note("%s gets %d Block %s bonds" % [p.name, c.count, g.board.blocks[pick].name], "own", p.index)
		"bond_discount":
			var price := roundi(g.bond_price(pick) * c.discount)
			var count := mini(c.count, p.cash / maxi(price, 1))
			if count > 0:
				p.cash -= price * count
				p.bonds[pick] = p.bonds_in(pick) + count
				g._note("%s buys %d Block %s bonds at %d G" % [p.name, count, g.board.blocks[pick].name,
						price], "own", p.index)
		"bond_dividend":
			var held := 0
			for b in p.bonds:
				held += p.bonds[b]
			if held > 0:
				g.earn(p, held * c.amount)
		"free_invest":
			g.add_capital(pick, mini(roundi(g.space(pick).price * c.share), g.max_capital(pick)))
			g._note("%s is now a %s worth %d G" % [g._label(pick), GameState.TIER_NAMES[g.tier(pick)],
					g.lot_value(pick)], "own", p.index, pick)
			g._sound("build")
		"invest_rate":
			if g.can_invest(p):
				return {"invest": c.rate}
			g._note("%s has nowhere to invest." % p.name, "info", p.index)
		"move_again":
			return {"move_again": true}
		"move_ahead":
			var at := p.position
			var from := p.came_from
			for i in c.steps:
				var opts := g.options_from(at, from)
				from = at
				at = opts[0]
			_teleport(g, p, at, false)
			return {"land_again": true}
		"to_random":
			var spots: Array[int] = []
			for s in g.board.spaces:
				if s.id != p.position:
					spots.append(s.id)
			_teleport(g, p, spots[g.rng.randi_range(0, spots.size() - 1)], false)
			return {"land_again": true}
		"to_relay":
			var target := _nearest_unpunched_relay(g, p)
			if target < 0:
				g._note("Every Relay is already punched.", "info", p.index)
				return {}
			_teleport(g, p, target, false)
			return {"land_again": true}
		"to_depot":
			_teleport(g, p, g.board.depot, true)
			return {"land_again": true}
		"skip":
			p.skip_move = true
		"skip_rival":
			g.players[pick].skip_move = true
			g._note("%s is stuck in traffic" % g.players[pick].name, "loss", pick)
		"double_rent":
			p.double_rent = true
		"commission":
			p.commission = true
		"any_suit":
			g.give_any_suit(p, "keeps")
		"free_suit":
			var missing := g.board.relay_ids().filter(func(r): return r not in p.punches)
			if missing.is_empty():
				g._note("%s already has every suit." % p.name, "info", p.index)
			else:
				var r: int = missing[g.rng.randi_range(0, missing.size() - 1)]
				p.punches.append(r)
				g._note("%s gets the %s" % [p.name, g.space(r).mark], "gain", p.index, r)
		"lose_suit":
			if p.punches.is_empty():
				g._note("%s has no suits to lose." % p.name, "info", p.index)
			else:
				var r: int = p.punches[g.rng.randi_range(0, p.punches.size() - 1)]
				p.punches.erase(r)
				g._note("%s loses the %s" % [p.name, g.space(r).mark], "loss", p.index, r)
		"minigame":
			return {"minigame": true, "game": c.game}
		"charity":
			var rich := _richest(g, g.players)
			var poor := _poorest(g, g.players)
			if rich and rich != poor:
				g._note("%s gives %d to %s" % [rich.name, c.amount, poor.name], "info", rich.index)
				g.charge(rich, c.amount, poor.index)
		"rich_pays_all":
			var rich := _richest(g, g.players)
			if rich:
				for q in g.players:
					if q != rich and not q.broke and not g.game_over and not rich.broke:
						g.charge(rich, c.amount, q.index)
		"take_from_richest":
			var rich := _richest(g, rivals)
			if rich:
				g.charge(rich, c.amount, p.index)
		"warp_any":
			g.warp(p, pick)
			return {"land_again": true}
		"warp_bank":
			_teleport(g, p, g.board.depot, true)
			return {"land_again": true}
		"warp_relay":  # the suit is punched on arrival; no Scrap Heap draw
			g.warp(p, pick)
		"reverse":
			p.reverse_next = true
		"reverse_rival":
			g.players[pick].reverse_next = true
			g._note("%s will walk backwards next turn" % g.players[pick].name, "loss", pick)
		"forced_sale":
			g.sell_lot_to_bank(p, pick, FIRE_SALE_RATE)
		"swap":
			var mine: int = pick[0]
			var theirs: int = pick[1]
			var rival := g.players[g.lots[theirs].owner]
			var diff := g.lot_value(theirs) - g.lot_value(mine)
			if diff > 0:
				g.charge(p, diff, rival.index)
			if not p.broke:
				g.lots[mine].owner = rival.index
				g.lots[theirs].owner = p.index
				g._note("%s swaps %s for %s's %s" % [p.name, g._label(mine), rival.name,
						g._label(theirs)], "own", p.index, theirs)
	return {}


## Bond cards on the reel: a block drawn at random from the game's rng.
static func draw_block(g: GameState) -> String:
	var keys := g.board.blocks.keys()
	return keys[g.rng.randi_range(0, keys.size() - 1)]


## The CPU's pick for a card, or null to pass (only Swap Meet may be passed).
static func cpu_pick(g: GameState, p: PlayerState, id: int):
	var opts := choices(g, p, id)
	if opts.is_empty():
		return null
	match CARDS[id].fx:
		"boost_lot", "boost_block":  # the most valuable lot
			return _best(opts, func(lot): return g.lot_value(lot))
		"blackout", "blackout_block", "devalue":  # the rival lot with the highest rent
			return _best(opts, func(lot): return g.rent(lot))
		"bond_swing", "free_bonds":  # the reel decides, not the player
			return draw_block(g)
		"bond_discount":  # where it owns most lots
			return _best(opts, func(b): return g.owned_in_block(p.index, b) * 10 + p.bonds_in(b))
		"skip_rival":  # the leader
			return _best(opts, func(i): return g.net_worth(g.players[i]))
		"swap":  # only if it strengthens a block it is building
			var best = null
			var gain := 0
			for pair in opts:
				var get_block: String = g.space(pair[1]).block
				var give_block: String = g.space(pair[0]).block
				var delta := g.owned_in_block(p.index, get_block) - g.owned_in_block(p.index, give_block) + 1
				if get_block != give_block and delta > gain:
					gain = delta
					best = pair
			return best
		"warp_any":  # the Bank at goal, else the dearest lot it can buy, else the Star
			if p.at_goal:
				return g.board.depot
			var buy := opts.filter(func(id): return (g.space(id).type == "lot" and g.lots[id].owner < 0
					and g.lot_value(id) <= p.cash - Cpu.reserve(g, p)))
			if not buy.is_empty():
				return _best(buy, func(id): return g.lot_value(id))
			var star := opts.filter(func(id): return g.space(id).type == "interest")
			return star[0] if not star.is_empty() else opts[0]
		"warp_bank":  # only when it pays: at goal or with every suit
			return true if p.at_goal or g.has_all_suits(p) else null
		"warp_relay":
			var r := _nearest_unpunched_relay(g, p)
			return r if r >= 0 else opts[0]
		"reverse_rival":  # the leader
			return _best(opts, func(i): return g.net_worth(g.players[i]))
		"forced_sale":  # a lot from its weakest block, the dearest of those
			return _best(opts, func(id): return -g.owned_in_block(p.index, g.space(id).block) * 100000 + g.lot_value(id))
		"free_invest":  # the dearest base price
			return _best(opts, func(lot): return g.space(lot).price)
	return opts[0]


static func _best(opts: Array, score: Callable):
	var best = opts[0]
	for o in opts:
		if score.call(o) > score.call(best):
			best = o
	return best


static func _owned(g: GameState, p: PlayerState) -> Array:
	return g.lots.keys().filter(func(lot): return g.lots[lot].owner == p.index)


static func _boost(g: GameState, lot: int, mult: float, p: PlayerState) -> void:
	g.lots[lot].boost *= mult
	g.bond_pressure.erase(g.space(lot).block)
	g._note("%s is worth %d G now" % [g._label(lot), g.lot_value(lot)], "own", p.index, lot)


static func _richest(g: GameState, among: Array) -> PlayerState:
	var best: PlayerState = null
	for q in among:
		if not q.broke and (best == null or g.net_worth(q) > g.net_worth(best)):
			best = q
	return best


static func _poorest(g: GameState, among: Array) -> PlayerState:
	var best: PlayerState = null
	for q in among:
		if not q.broke and (best == null or g.net_worth(q) < g.net_worth(best)):
			best = q
	return best


static func _nearest_unpunched_relay(g: GameState, p: PlayerState) -> int:
	var targets: Array[int] = []
	for r in g.board.relay_ids():
		if r not in p.punches:
			targets.append(r)
	if targets.is_empty():
		return -1
	# Walk forward from the current space and take the first one reached.
	var seen := {p.position: true}
	var queue: Array[int] = [p.position]
	while not queue.is_empty():
		var id: int = queue.pop_front()
		for n in g.space(id).next:
			if n in targets:
				return n
			if not seen.has(n):
				seen[n] = true
				queue.append(n)
	return targets[0]


## Moves straight to `to`; entering it applies its pass effect (relay punch, or
## Depot salary when `salary`), but nothing on the way.
static func _teleport(g: GameState, p: PlayerState, to: int, salary: bool) -> void:
	p.came_from = -1
	p.position = to
	g._note("%s jumps to %s" % [p.name, g._label(to)], "info", p.index, to)
	if g.space(to).type != "depot" or salary:
		g._pass(p, to)
