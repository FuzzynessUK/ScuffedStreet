# Scuffed Street — design

A property-trading board game for 2–4 players (humans or computer). Players
travel a looping board, buy lots in junkyard-town blocks, invest in them,
trade in block bonds, and race to a target net worth.

All rules, numbers, space types and events here are our own. Shared genre
ideas (buy property, collect rent, bonus for owning a set, a market, a lap
salary) are used freely; specific mechanics are not copied from any game.

## Win condition

- The **Goal** (net worth) is picked on the home menu: 8,000, 10,000, 15,000
  (the default), 20,000 or 30,000 G. (Boards carry a goal of their own for the
  sim; the home menu's choice replaces it.)
- A player whose net worth is at or above the Goal at the **start of their
  turn** wins if they then reach the **Depot** during that turn (pass or land).
- While a player is in reach of the win (net worth at the Goal, or at it when
  their current turn began) their net worth on the stats glows and cycles
  through the rainbow, and the music switches to the intense loop until
  nobody is.
- If any player goes **broke** (see Bankruptcy) the game ends at once and the
  richest remaining player wins.
- Optional turn limit: richest player wins when it runs out.

**Net worth** = cash + sum of lot values + bonds × current bond price.

## Money

- Currency: shown as `G`.
- Starting cash is set per board (default 1,500).

## Movement

- Between turns the camera shows the whole board for 1.4 seconds, then
  "X's turn!" pops up in the middle in their colour while the camera moves
  in on them; they play 1.4 seconds later.
- Roll **2d4** (2–8), so movement is more predictable than one big die. The
  roll is a numbered dice block spinning over the player's head (its numbers
  flicking) through the turn menu; Roll makes them jump and punch it with one
  fist, and it flies at the screen, bounces round the bottom of it as if
  just in front of the camera, and settles face on showing the roll. A Dice
  space puts a fresh block over their head for the second roll. Landing on
  the Star sends a smiling star rising out of the player, growing slowly
  and twinkling, with a sparkle sound.
- Move exactly that many spaces, one step at a time. At a junction the player
  picks a branch. You may never step back onto the space you just came from,
  but while planning you can press **Back** to undo steps. After the last
  step the game asks **"Go here?"**; only a confirmed route counts. Suits and
  a PAYDAY still show as you go: stepping past the Depot with every suit
  plays the PAYDAY there and then (the cash on the stats shows it, in gold
  until confirmed), and backing up behind the Depot takes it back again.
- Suits are collected live while planning (pip and popup); stepping back off
  a suit collected on this route takes it away again. Suits held before the
  move are kept.
- Keyboard: the arrow keys (or d-pad) step in that direction on screen; the
  arrow back the way you came, Backspace (or the pad's B) undo a step;
  Enter or Space confirms "Go here?" (or takes the only way forward).
- **Escape** at any time brings up the pause box: Keep playing, Main Menu
  (during a game; back to the home screen, keeping the board and goal picked)
  and Quit (closes the game), and the **sound options**: Music and Sound
  effects, each switched on or off with a volume slider (0–100%), and the
  **camera option** Always zoomed out (the whole board all the time instead
  of following the player; short shows like the whole-block close-up still
  play). They take effect at once and are saved in `user://settings.cfg`
  (`scripts/ui/settings.gd`; music plays on a "Music" audio bus, effects on
  "SFX"). While the box is up everything stands still, CPU turns included;
  Escape again closes it.
- Standing on or passing over a lot shows its details: owner and building,
  lot value, rent, max capital (capital it can still take before it is a full
  Megamart) and how much of the block the owner holds.
- Spaces passed through can trigger "pass" effects (Depot, Relays); only the
  final space triggers its "land" effect.

## Laps: Relays and salary

- Each board has **4 Relay** spaces, one per card suit: Spade, Heart, Diamond
  and Club, each with its own colour, shown as a suit beacon on the space and
  as suit pips on the player panel. (There are no promotion levels; a
  PAYDAY always pays by the formula below.) Passing or landing on a Relay you have not
  visited this lap gives you its **punch** (each Relay counts once per lap).
  **Landing** on a suit also opens the Scrap Heap: pick a Wildcard.
- Passing or landing on the **Depot** with **all four suits** is a **PAYDAY**:
  fireworks, and your salary, and your suits reset:

  `salary = base_salary + 4 × relay_bonus + 5% of your total lot value`

  Defaults: base 200, relay bonus 120. Collect the suits in any order.
- Reaching the Depot without every suit pays nothing; you keep the suits you
  have. Landing on the Depot always opens the Bond Market.
- **Any Suit** cards (from the Scrap Heap, Scrap Slots, Pick a Card or the
  Chance Wheel) are kept, **two at most**: winning one while holding two
  gives nothing. They show as gold stars by the suit pips. At the Depot each one stands in for a
  missing suit. The bank takes only the cards that filled a gap: with all four
  real suits it takes none and you keep them for a later lap.

## Lots and blocks

- Each lot belongs to a **Block** (3–5 lots, shown by colour).
- Landing on an **unowned** lot: you may buy it at its list price.
- Landing on **someone else's** lot: pay rent.
- Landing on **your own** lot: you may invest in **one** of your lots (see
  below).

### Investing

You put G (capital) into a lot, and every G invested adds a G to its value.
How much a lot can take depends on your **share of its block**: in all, at
most **3.2 × its base price × your share** (its max capital), and in any one
turn at most **1 × its base price × your share** (twice that with the whole
block). So in a block of three, one lot can grow to a Shop, two lots to a
Store, and only the whole block reaches a Megamart:

| Lots owned (of 3) | In all (× base) | Per turn (× base) | Can reach |
|-------------------|-----------------|-------------------|-----------|
| 1                 | 1.07            | 0.33              | Shop      |
| 2                 | 2.13            | 0.67              | Store     |
| 3 (whole block)   | 3.2             | 2.0               | Megamart  |

Capital already put in stays if you later own less of the block; it just
takes no more. On the invest screen you pick **one** lot (yours are lit up),
then an amount: a quarter, half, three quarters or all of what it can take
this turn (or as much as cash plus bonds cover), and that is it until the
next chance. CPUs likewise invest in one lot at a time.

The building's name follows its capital, as a share of the base price, and
the rent rate rises evenly with capital from 10% of value (none) to 24%
(full). Investing raises the block's value, so its bond price rises too.

| Building | Capital (× base) | Rent at that point |
|----------|------------------|--------------------|
| Shack    | 0 to 0.6         | 10% of value       |
| Shop     | from 0.6         | about 13%          |
| Store    | from 1.6         | 17%                |
| Megamart | 3.2 (full)       | 24%                |

The Workshop and your Repair Shop let you invest the same way at 80% / 50%
of the price. The Free Renovation card puts its base price in for free.

### Block bonus

Rent is multiplied by how much of the block the owner holds:

| Share of block owned | Rent multiplier |
|----------------------|-----------------|
| 1 lot                | ×1.0            |
| at least half        | ×1.5            |
| all but one          | ×2.0            |
| the whole block      | ×3.0, values ×1.25, twice the investment per turn |

(If "at least half" and "all but one" are the same count, the higher applies.)

**Whole block.** Owning every lot in a block raises each lot's value by 25%
(so its bond price jumps) and doubles how much each lot takes per turn. The
moment a block comes into one player's hands (a purchase, buyout, auction,
trade or card) the camera moves in on it and its buildings change one by
one: each spins round and its roof pops back on in gold with a burst of sparks, under
a WHOLE BLOCK! banner, to a rising fanfare (one note per building, then a
held chord; the music dips under it). The gold roofs stay while the block is
whole.

**Corner map.** All through a game a small, slightly see-through map of the board sits in
the bottom-left corner of the board view (`scripts/ui/minimap.gd`, as an overlay): every
space as a square at its place, bought lots filled in their owner's colour
(lots for sale in their block's colour, dimmed), letters on the special
spaces (B the Bank, ? a Wildcard, M a minigame, a star, a moon, V a vacant
plot, a built plot's initial, D Dice, $ the Market), the suits on
the Relays, and a dot for each player (following a route as it is planned).
It hides while View Map is open.

**On the board.** A lot's tile is a border in its block's colour round a
panel: cream while for sale, the owner's colour once bought. On it stands a
house (walls with a door and a row of windows per floor, a gabled roof and a
chimney) that grows with the lot's value, all grey while for sale, in the
owner's colours once bought. A wooden sign
in front shows the price while it is for sale and the rent once owned (in
the owner's colour; CLOSED while they are on the Moon). Relays are a
cream-white border round squares of the suit's colour that grow lighter
towards the middle, with a big glowing suit on them under the floating one.
The Dice space is a flat white die (five pips) on glowing green, the same
lighter-to-the-middle squares. An empty Plot is bare earth with tufts of
grass round it and a cartoon red SALE sign (no price sign: the cost is on
the menu when you land). Once built, a plot shows a model of its building
with the owner's colour in it: a wooden Toll Bridge on stone piers with a
booth and barrier, an Airport (an airliner on the runway, the terminal and control tower in
front), a
columned Tax Office with a % on its pediment, a Repair Shop garage with a
spanner on the roof and tyres, and a Shopping Centre as a giant mall (a tall white-clad block with
louvres and a red MALL sign, a curved glass entrance under a canopy, a long
glass wing with a SHOPS sign and a terrace, a lamp post with banners in the
owner's colour) that grows taller each time it is expanded. The Depot is
drawn as the BANK: a grand columned bank with a dome and a gold money bag on
top, a red carpet to its door and BANK lettered on the tile. The Wildcard
space is a green ? on purple. The Star space is a flat smiling star on squares of blue and green.
The Arcade is an upright arcade cabinet (lit marquee, a glowing maze-and-dots
screen, joystick and buttons, coin door), nearly square on, on a dark grey
arcade-room floor inside a white border.
Dev switch `--look=<space type>[@distance]` holds the camera on the first
space of that type, for checking tile art.

**Light.** A warm afternoon sun with soft shadows and a cool, sky-tinted fill,
slightly darkened with a little extra contrast so the board isn't glaring.
Figures take 0.24 s a space (0.26 s between a CPU's steps). The dice block
and dice are outlined along every edge with a faint (90% see-through) line in the
numbers' blue, so each side stands out.

### Buyouts

Landing on a rival's lot, after paying rent you may **buy it out** for
**2× its value**. The owner must accept. Not allowed on Megamarts.

## Block bonds

- Each block issues **bonds**. Bond price = `round(block total value / 40)`,
  minimum 5, recalculated whenever a lot's value changes.
- You buy and sell bonds in the Bond Market, which opens when you land on the
  Depot and after every PAYDAY; you can also sell from the turn menu, or
  just look (View bonds).
- **PAYDAY market:** passing the Depot with every suit opens the Bond Market
  there and then, with the salary in hand, once the PAYDAY show (banner,
  fireworks, trumpets) has finished. While a human is still planning
  the route this is provisional: backing up behind the Depot undoes every
  trade made there (cash, bonds and price pressure go back), and stepping
  past it again reopens it. A route that ends on the Depot just opens the
  market on landing. CPUs (and warps through the Depot) trade on landing. (No board has a separate Market
  space any more.) Up to 20 bonds per action.
- The **Bond Market** screen lists every block with its bond price, the change
  since the round began, the block's total value, each player's holdings and
  what yours are worth; pick a block and an amount (1-20) to buy or sell.
- Whenever any bond price moves, the **Bond Ticker** appears over the board:
  moved prices spin like a slot-machine reel, then settle with the rise or fall.
- **Dividends:** when rent is paid on any lot in a block, each bondholder of
  that block receives `rent × 1%` per bond held, paid by the bank.
- **Pressure:** a single purchase of 10+ bonds raises that block's bond price
  10% until the next change in its value; a sale of 10+ lowers it 10%.

## Space types

| Space    | Effect |
|----------|--------|
| Depot    | Start. PAYDAY when passed/landed holding all four suits. Bond Market when you land here (not when a turn starts here). |
| Relay    | Suit for this lap (see above). Landing also opens the Scrap Heap. |
| Lot      | Buy / pay rent / invest in any of your lots. |
| Market   | Trade bonds. (Not on any board now: bonds are traded at the Depot.) |
| Wildcard | Draw a Wildcard (see deck). |
| Dice     | Roll again and keep moving (2 per board). |
| Arcade   | Play a minigame (see Minigames). |
| Star     | Interest (one per board, ★): until your next turn you get a **20% commission**, paid by the bank, on every profit the other players make: rent they collect, PAYDAY salaries, bond dividends, Scrap Heap combo bonuses, card gains and minigame prizes (not sales or trades). They keep all of theirs. Shows as "Star 20%" on the stats. |
| Moon     | Take a break (one per board, ☾): all your lots are **closed** until your next turn, so they charge no rent. A brief sunset sweeps over the board (orange, then dusky purple, then back), and each of your lots shows a red "✕ CLOSED" sign until it reopens. Shows as "☾ closed" on the stats. |
| Plot     | A building plot (three per board): build on it, then rivals pay and you get a perk (see Building plots). |
| Workshop | Invest in any of your lots at 80% of the price. (Not on Scrapyard Loop now: its Workshop became a plot.) |
| Toll     | Pay 8% of your cash to the bank. (Not on Scrapyard Loop now: its Toll became a plot.) |
| Detour   | Warp to the paired Detour space; your move ends there. |
| Junction | No effect; a branch point (any space may branch, this one is just empty). |

## Wildcards and the Scrap Heap

Landing on a Wildcard space opens the **Scrap Heap**: an 8×8 grid of face-down
cards drawn from a pool of **135 Wildcards**: the three Any Suit cards (21,
22 and 23) and three Arcade Tickets in every table, the other 58 slots all
different cards, so every new table
brings a fresh mix. The player picks a card, it turns over and takes effect,
and the slot stays face up in that player's colour.  The tile lands showing the card's unique
number (1–128), and keeps it. The card itself then pops up big, shaped like a
playing card on a bright background for its kind (orange gains, grey costs,
blue moves, teal bonds, purple lots, night blue for a black-out): across the
top only its number and sign in big chunky letters ("+60G", "-10%", "x2",
"FREE"), and in the middle, in a white-framed square, a picture of what it
does (`scripts/ui/card_art.gd`): a little 3D diorama on a patch of grass
(`scripts/ui/card_scene.gd`, built from the board's own models: houses,
the Bank, figures, plus coins, cars, dice...), its subject in the middle and
turning gently; Bond Bump and Bond Slump are a whiteboard on an easel with
the chart climbing or diving. Under the card a text box gives its number,
name, what it does and the combo money. When every slot has been
taken a new table is drawn from the pool and the colours clear. Each card is
data in `scripts/core/wildcards.gd`: its name and text, what it asks you to
pick, and an effect with its amounts. The 22 cards below have their own
pictures; the newer ones share a picture with a card of the same meaning or
use a template for their effect (a coin pile sized to the amount, coins
flying into the Bank, a house with an arrow up or down, a car
riding ahead, a whiteboard with their own percentage...), captioned with
their own numbers.

**Patches:** your taken cards in an unbroken straight line (across or down)
through the card you take form a patch; if both directions have one, the
longer counts. An L shape is not a patch: only its longest straight arm
counts. Taking a card pays `40 × (patch size − 1)` from the bank, so joining
one of your cards pays 40, a line of 3 pays 80, a line of 5 pays 160. Rivals'
cards don't count and break the line. Free slots
show what they would pay you.

Cards that need a choice (a lot, a block, a swap) do nothing if there is no
valid choice. Only Swap Meet may be declined.

**Bond Bump / Bond Slump reel:** the block letters spin on a reel and the
player presses Stop. Stop is not a skill test: the block is drawn at random at
that moment and the reel then slows down onto it, whatever it was showing.
CPUs get the same random draw.

1. **Scrap Drive** — every other player pays you 40.
2. **Parking Ticket** — pay a 100 G fine to the bank.
3. **Rush Hour** — roll again and move.
4. **Inspection** — pay 25 to the bank for every building tier you own (Shop 1, Store 2, Megamart 3).
5. **Grand Opening** — one of your lots gains +20% value for good.
6. **Power Cut** — a rival's lot charges no rent until its owner's next turn.
7. **Lucky Find** — gain 150.
8. **Bond Bump** — a block's bond price rises 15% until its value changes. The
   block comes from a slot-machine reel (see above).
9. **Bond Slump** — the same, falling 15%.
10. **Shortcut** — jump to the nearest Relay you haven't punched (punch it, land there; no salary for skipping past the Depot).
11. **Tax Refund** — gain 5% of your lot value.
12. **Swap Meet** — swap one of your Shacks for a rival's Shack, paying them the difference if theirs is worth more.
13. **Charity** — the richest player gives 100 to the poorest.
14. **Back to Base** — go straight to the Depot (PAYDAY with every suit; wins if at goal).
15. **Free Renovation** — invest capital worth its base price in one of your lots, free (not counted against the turn's limit).
16. **Lucky Dip** — win a random 50–250 G (in tens).
17. **Heavy Traffic** — you don't move on your next turn.
18. **Double Rent** — the next rent you collect is doubled.
19. **Market Tip** — buy up to 10 bonds in a block at 10% off.
20. **Scrap Tax** — pay 10% of your cash to the bank.
21–23. **Any Suit** (three of them) — keep this card; it stands in for a
    missing suit at PAYDAY (see Laps).
24. **Arcade Ticket** — play a minigame now.

The other 111 cards are our own variations on these and a few new effects:
money from or to the bank (20–400 G), mystery prizes of a random amount
(one of them can also lose you 100 G), from or to every other
player, for everyone at once, shares of your cash, net worth or lot value,
per lot or per building tier you own; lot value up (one lot or a whole block
of yours) or a rival's down (never below half); a rival's block shut for a
round; bond prices up or down 8–25%, free bonds, discounted bonds, a
dividend per bond held; free capital or a discounted round of investing;
riding 1–6 spaces
ahead, a bus to a random space; a rival stuck in traffic; a suit punched
for you or one lost; the Star's commission; tickets for a particular
minigame; and cards that move players about the board:

- **Warp Gate** — warp to any space you choose (click it on the board, which
  pulls back to show it all, or press The Bank) and land there.
- **Bank Shuttle** — go to the Bank (PAYDAY if you hold every suit) and land
  there, or stay where you are.
- **Suit Hopper** — jump to a suit space of your choice and punch its suit;
  you don't land there, so no Scrap Heap card.
- **Reverse Gear** — on your next turn you walk backwards. **U-Turn** — a
  rival you pick does. Walking backwards, the first step turns round (any
  way but the way on) and the rest keep going back the way they came,
  whether the board's links run one way or both; it lasts that one turn.
- **Fire Sale** — sell one of your lots to the bank for **twice its value**;
  it then goes to auction like any lot sold to the bank.

Card numbers are their place in the pool, so adding the two extra Any Suit
cards moved every card after them on by two.
## Minigames

Started by landing on an **Arcade** space or drawing an **Arcade Ticket**.
Each one picks a minigame at random. Prizes are fixed amounts of G (no
scaling). Everything random is drawn by the game (`scripts/core/minigames.gd`);
the screen only shows it, so CPUs play by the same odds.

**Scrap Slots** — a 3×3 grid. All three rows spin; each press of Stop (or
Enter) stops the next row, top to bottom, three presses in all. Like the Bond
reel, Stop is not a timing test: a row's three symbols are drawn when Stop is
pressed and the row slows onto them. Every cell is drawn by weight (Gold 1,
Bolt 3, Warp 2, Bond 2, Card 2).

Only **three in a line** pays: any of the 3 rows, 3 columns or 2 diagonals,
drawn across the grid when they win. Every winning line pays (several Warp
lines still make one Warp; the free bonds from every Bond line go in one
random block, picked on the Bond reel). A paying line comes up roughly one spin in three.

| Line of      | Prize |
|--------------|-------|
| Gold         | 400 G |
| Bolt         | 120 G |
| Warp         | Warp to the Depot or a suit (entering it counts: suit, PAYDAY), then land there |
| Bond         | 10 free bonds in a random block (the Bond reel picks it) |
| Card (★)     | An Any Suit card |

**Pick a Card** — four cards are shown face up, each only its prize: a
picture and a caption (coin piles for 300 G and 100 G, the four suits round
a rainbow for an Any Suit card, a puff of smoke for nothing). After two
seconds they turn face down, slide together into one stack, are shuffled
(cards pulled out and put back on top) and dealt back to the table. The
player clicks a card and wins its prize. It is pure luck: where each prize
ends up is a fresh random draw, and the card pictures carry no prize until one
is turned over, so watching the shuffle tells you nothing. CPUs guess too.

**Chance Wheel** — two wheels seen face on, as if standing in front of them:
WHO? (every player still in, the thrower too) and WHAT? (good and bad); a
bond action brings out a third, WHERE? (blocks), thrown at the same way. All
spin very fast (WHO? 7 turns a second, WHAT? 5). The player presses Throw (or Enter)
to throw a dart at each; it flies in from in front of them, hits the mark at
12 o'clock and rides round as the wheel slows. The segment it sticks in
is the result, and it happens to that player:

| WHAT?       | Effect |
|-------------|--------|
| +300 G      | Gets 300 G |
| −200 G      | Pays 200 G to the bank (may force a bond sale) |
| Any Suit    | Gets an Any Suit card |
| −5 bonds    | Loses 5 bonds (all of them if fewer) in a block picked by the WHERE? wheel, which only shows blocks they hold; none held: nothing happens |
| +100 G      | Gets 100 G |
| Skip move   | Skips their next move |
| +5 bonds    | Gets 5 bonds in a block picked by the WHERE? wheel (any block) |

There is nothing to react to: each result is drawn when the dart is thrown,
and the wheel's turn during the dart's flight is nudged (unseeable at that
speed) so the dart lands in that segment. CPUs throw by themselves.

**Critter Race** — a bright 3D meadow race (deliberately not scrapyard
themed). Every player still in backs one of four animals, whoever is losing
first: lowest net worth picks first, the leader last, ties in seat order (two
may back the same one; the tags show who backed what), then they watch them race down a
four-lane track to a chequered finish under a bunting arch:

| Racer  | Style |
|--------|-------|
| Bunny  | Hops in bursts |
| Turtle | Slow and steady |
| Fox    | Sprints, then puffs |
| Duck   | Waddles, then flaps |

Every race is planned fresh: each animal gets a finishing time (8–11 s, all
drawn the same way, so every animal is equally likely to win) and a pace for
each of 8 stretches in its own style, so the lead changes and no two races
look alike. The styles are only for show. Prizes by where your animal
finishes: 1st **100 G × your level** (200 G at level 1), 2nd 120 G, 3rd 40 G,
4th nothing. CPUs pick at random. After the race the camera cuts to a podium
past the finish: the winner jumps and spins on the gold step, 2nd and 3rd hop
on silver and bronze, 4th droops on the grass, and confetti falls. Meanwhile
each player's winnings are shown one at a time, 3 seconds each, in the same
order they picked, and paid as they are shown, so the stats update player by
player. The animals are placeholders built from simple shapes, to be swapped
for models later.

**Level:** every player starts at level 1 and goes up one level at each
PAYDAY. It shows as "Lv" on the player stats and scales the Critter Race
winner's prize.

## Boards

The home menu has **Choose a board**: every board in `boards/` with its
size; hovering a choice shows that board behind the menu, and picking it
makes it the board for new games (and the Test Lab). Besides Scrapyard Loop
there are Figure Eight, Three Islands, Spiral Market, Crossroads and Long
Street, drawn as text maps (`boards/maps/`, see `boards/README.md`) so more
levels are quick to add. Those boards are two-way: you choose a direction
and turn round at dead ends. Boards are JSON files (format in
`boards/README.md`), so new boards need no code. All boards and art are
original.

Every board sits on a very basic 3D golf course for now (filler scenery):
rough and mown grass, fairways to flagged greens, bunkers, a pond and trees,
under a blue sky.

## Test Lab

The home menu's **Test Lab** starts a throwaway game (you and three CPUs) with
a menu to try any feature on demand, in groups (Minigames, CPU minigames,
Spaces and moving, Bonds and money, Auctions and Wildcards) so each menu fits: every minigame (or a random one, as an
Arcade would pick), a CPU playing any minigame, the Bond Bump / Slump reel,
a Wildcard draw, the Bond Market, a 300 G debt to sell bonds for, an auction
where you sell (the CPUs bid), one where CPU 2 sells and you bid against
CPU 3 and CPU 4 ("Bid at an auction"), buying the last lot of a block (the
whole-block show), investing, a PAYDAY on the way (every suit, three steps
short of the Depot, walk 4: try backing up), reaching the goal (the glow and
the intense music), +1000 G, rolling the dice block, and landing on a Dice
space, the Star or the Moon.
Nothing there carries over; going bankrupt or winning just starts it afresh.

## Bankruptcy

- A payment (rent, a toll, a card) may push cash below 0, and a lot may be
  bought, bought out or invested in with too little cash as long as cash plus
  the value of your bonds covers it. Either way the player must then clear
  the negative balance:
  1. the Bond Market opens and they choose which bonds to sell at the
     current price (CPUs sell in order); they can't leave while still
     negative and holding bonds, then
  2. any remaining debt sells lots back to the bank at **70% of value**,
     cheapest first.
  Lots sold to the bank become unowned at tier 0 and go to **auction**.
- If everything is sold and cash is still negative, the player is **broke**
  and the game ends (see Win condition).

## Building plots

Three empty plots per board (on Scrapyard Loop: the old Toll, the old
Workshop, and Winch Tower's spot in Block F). Land on an empty one and you
**must** build one of these for **200 G** (with cash, or bonds to cover it as
for a lot; only if even that can't pay does it stay empty). The building is
yours; it counts in your net worth at what you spent on it. Rivals pay you
when they land (a Toll Bridge also when they pass), which counts as profit for
a Star commission; you get its perk when you land.

Shopping Centres are expanded only when you land on one of your own built
plots, but then you may expand **any** of your Shopping Centres on the board
(the one in question lights up as you're asked).

| Building | Rivals | Owner who lands |
|---|---|---|
| ⇆ Toll Bridge | Pay the toll when they pass or land: 20 G, rising 10 G every time it is paid. Tolls go into the bridge's jar. | Empties the jar into their cash |
| ✈ Airport | Pay 50 G | Flies free to any space (not lots or plots) and lands there |
| % Tax Office | Pay 10% of their net worth to the owner | Gets a 5% net-worth bonus from the bank |
| ⚒ Repair Shop | Pay 50 G | Renovates any of their lots at half price |
| ⌂ Shopping Centre | Pay its fee: 100 G, then 500, 1000, 2000 G as it grows | (see above) Expanding costs 300 / 500 / 1000 G, 3 times at most |

Two more buildings are to come (`scripts/core/plots.gd`: an entry in KINDS
and ORDER, its charge in rival_charge and its perk in on_land). Plots can't
yet be sold, traded or rebuilt. CPUs build at random whenever they can pay,
expand when they can keep their reserve, and fly as they would warp.

## Auctions

Every lot sold back to the bank (from the turn menu, or to pay off a debt)
is auctioned at once to everyone else; the seller can't bid.

- The auction screen shows the lot on a minimap (ringed in pink) with its
  block, lot value, rent and max capital, then all four players: a 3D figure
  of each on a little stage, and under each their **Stocks** (bonds at
  today's prices), **Ready Cash** and **Total**.
- Bidding opens at the lot's value (no building) and each bid adds **10 G**;
  nobody can bid past their Total. Each human bidder has a Bid button; CPUs
  bid by themselves, up to a private limit around the lot's value (higher for
  a block they are building, never below half their cash reserve).
- Every bid restarts a **5 second** clock. The bidder's figure throws a hand
  up and their bid pops up above their head (outbid amounts turn grey). When
  the clock runs out the highest bidder wins and celebrates; with no bids the
  lot stays on sale.
- The winner pays from Ready Cash; if that is short, the Bond Market opens
  to sell bonds for the rest, as for any debt.

## Turn order

1. Start of turn: check the Goal. (Standing on the Depot does not open the
   Bond Market; only landing there does.)
2. Turn menu, before rolling (humans; as often as they like, then **Roll**):
   - **View bonds** — the Bond Market to look at only.
   - **Sell bonds** — the Bond Market opens for selling only (buying still
     happens when you land on the Depot).
   - **Sell a lot to the bank** — at 70% of its value; it goes back on sale
     with no building, and straight to auction (see Auctions).
   - **Trade with a player** — pick a player, tick any of your lots and set G
     to give, tick any of theirs and set G to ask for, then Propose. Each side
     can offer G up to their cash plus bonds (as at an auction); whoever is
     left owing sells bonds. Lots keep their buildings. A human answers Accept / Decline on the same screen; a
     CPU accepts only if it comes out at least 15% ahead on lot value plus G,
     counting a lot in a block it is building at 1.5× (to keep or to win), and
     never if the trade leaves it below half its cash reserve.
3. Roll and move (choose branches).
4. Resolve the landing space.
5. End of turn.

## Computer players (phase 1)

Simple, rule-driven:

- Buy a lot if cash after buying stays above a safety reserve (300 G + 10%
  of the most expensive rent on the board).
- Invest when they may: as much as each lot takes, best block share first,
  keeping 1.5× the reserve.
- Prefer branches leading towards unpunched Relays, or the Depot when at Goal.
- Buy bonds in blocks where they own most lots; sell when cash is short.

Difficulty levels later tune the reserve and how far ahead they look.

## Roadmap

1. **Core** — rules engine (pure logic, no UI) with headless tests; one board.
2. **Playable hot-seat** — board drawn in 2D, dice, menus for every decision.
3. **Computer players.**
4. **Online** — host-authoritative over Epic Online Services (lobbies + P2P
   relay) via the godot-epic-online-services plugin.
5. **Polish** — more boards, art, sound, settings.

## Music and sound

All original, synthesised in code on acoustic-style instruments
(`scripts/ui/music.gd`): plucked harp, bass and pizzicato (Karplus-Strong),
bowed strings, flute, clarinet, marimba, glockenspiel and bells, brass, and
timpani, kick, snare, clap, shaker, woodblock and cymbal, through a small
reverb. Everything is rendered once on worker threads and cached in
`user://music_cache` (bump `SOUND_VERSION` after changing a sound).

| Loop | When | Sound |
|------|------|-------|
| Journey | normally | 80 bpm, D major: flute over harp, strings and plucked bass |
| Final stretch | anyone in reach of the win | 126 bpm, A minor: brass, driving strings, cellos, timpani |
| Casino | Scrap Slots, Pick a Card, Chance Wheel | 112 bpm swing, F: vibraphone, jazz piano chords, walking bass, brushes and ride |
| Race | Critter Race | 152 bpm, D major gallop: brass and flute, racing strings, oom-pah pizzicato, snare |
| Bonus | picking from the Scrap Heap | 138 bpm, G major: marimba, glockenspiel, pizzicato, claps |

Stingers (the music dips under them): **PAYDAY** trumpets (three pickup
notes, a run up and a held chord with strings, timpani and cymbal) and the
**whole-block** fanfare (a snare roll, a rising brass note per roof, a held
chord). Effects (`scripts/ui/sfx.gd`): a soft, low note per space moved,
alternating between two notes like footsteps (`STEP_STYLE`: marimba, pluck,
tap or bass; a lower note stepping back); glockenspiel
runs up / down for buying / selling bonds; a cash register's cha-ching
(lever clack, bell, coins) for buying a lot or an auction win; an epic
orchestral TAKEOVER (a drum roll swelling into two brass stabs and a big
held chord with a cymbal crash) for buying out a rival's lot;
woodblock knocks and a bell chord for investing and building.
