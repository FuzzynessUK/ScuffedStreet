# Scuffed Street — design

A property-trading board game for 2–4 players (humans or computer). Players
travel a looping board, buy lots in junkyard-town blocks, renovate them,
trade in block bonds, and race to a target net worth.

All rules, numbers, space types and events here are our own. Shared genre
ideas (buy property, collect rent, bonus for owning a set, a market, a lap
salary) are used freely; specific mechanics are not copied from any game.

## Win condition

- Each board sets a **Goal** (net worth, e.g. 10,000 Scrap).
- A player whose net worth is at or above the Goal at the **start of their
  turn** wins if they then reach the **Depot** during that turn (pass or land).
- If any player goes **broke** (see Bankruptcy) the game ends at once and the
  richest remaining player wins.
- Optional turn limit: richest player wins when it runs out.

**Net worth** = cash + sum of lot values + bonds × current bond price.

## Money

- Currency: **Scrap** (shown as `S`).
- Starting cash is set per board (default 1,500).

## Movement

- Roll **2d4** (2–8), so movement is more predictable than one big die.
- Move exactly that many spaces, one step at a time. At a junction the player
  picks a branch. You may never step back onto the space you just came from,
  but while planning you can press **Back** to undo steps. After the last
  step the game asks **"Go here?"**; only a confirmed route counts.
- Standing on or passing over a lot shows its details: owner and tier, lot
  value, rent, next renovation cost and how much of the block the owner holds.
- Spaces passed through can trigger "pass" effects (Depot, Relays); only the
  final space triggers its "land" effect.

## Laps: Relays and salary

- Each board has **4 Relay** spaces, one per card suit: Spade, Heart, Diamond
  and Club, each with its own colour, shown as a suit beacon on the space and
  as suit pips on the player panel. (There are no promotion levels; a
  PAYDAY always pays by the formula below.) Passing or landing on a Relay you have not
  visited this lap gives you its **punch** (each Relay counts once per lap).
- Passing or landing on the **Depot** with **all four suits** is a **PAYDAY**:
  fireworks, and your salary, and your suits reset:

  `salary = base_salary + 4 × relay_bonus + 5% of your total lot value`

  Defaults: base 200, relay bonus 120. Collect the suits in any order.
- Reaching the Depot without every suit pays nothing; you keep the suits you
  have. Landing on the Depot always opens the Bond Market.

## Lots and blocks

- Each lot belongs to a **Block** (3–5 lots, shown by colour).
- Landing on an **unowned** lot: you may buy it at its list price.
- Landing on **someone else's** lot: pay rent.
- Landing on **your own** lot: you may renovate it (see below).

### Renovation tiers

A lot has a tier from 0 to 3. Renovating costs a fixed fraction of the lot's
*base* price and raises both its value and its rent.

| Tier | Name     | Upgrade cost  | Value       | Base rent    |
|------|----------|---------------|-------------|--------------|
| 0    | Shack    | —             | 1.0 × base  | 0.10 × value |
| 1    | Shop     | 0.6 × base    | 1.6 × base  | 0.14 × value |
| 2    | Store    | 1.0 × base    | 2.6 × base  | 0.18 × value |
| 3    | Megamart | 1.6 × base    | 4.2 × base  | 0.24 × value |

You may renovate one tier per visit.

### Block bonus

Rent is multiplied by how much of the block the owner holds:

| Share of block owned | Rent multiplier |
|----------------------|-----------------|
| 1 lot                | ×1.0            |
| at least half        | ×1.5            |
| all but one          | ×2.0            |
| the whole block      | ×3.0 (and renovation costs −25%) |

(If "at least half" and "all but one" are the same count, the higher applies.)

### Buyouts

Landing on a rival's lot, after paying rent you may **buy it out** for
**2× its value**. The owner must accept. Not allowed on Megamarts.

## Block bonds

- Each block issues **bonds**. Bond price = `round(block total value / 40)`,
  minimum 5, recalculated whenever a lot's value changes.
- You may buy or sell bonds on a **Market** space (landing or passing), or at
  the start of your turn when standing on the Depot. Up to 20 bonds per action.
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
| Depot    | Start. PAYDAY when passed/landed holding all four suits. Bond Market when you land or start a turn here. |
| Relay    | Punch for this lap (see above). Landing also gives 50 S. |
| Lot      | Buy / pay rent / renovate. |
| Market   | Trade bonds. |
| Wildcard | Draw a Wildcard (see deck). |
| Workshop | Renovate any one of your lots by one tier at 80% cost. |
| Toll     | Pay 8% of your cash into the **Pot**. |
| Jackpot  | Collect the whole Pot. |
| Detour   | Warp to the paired Detour space; your move ends there. |
| Junction | No effect; a branch point (any space may branch, this one is just empty). |

## Wildcards and the Scrap Heap

Landing on a Wildcard space opens the **Scrap Heap**: an 8×8 grid of face-down
cards. Every one of the 20 Wildcards is in it at least once; the other slots
are random repeats. The player picks a card, it turns over and takes effect,
and the slot stays face up in that player's colour. When every slot has been
taken the heap is reshuffled and the colours clear. Cards are kept by id
(`scripts/core/wildcards.gd`) so a card can later launch a minigame.

**Patches:** your taken cards that touch up, down, left or right form a patch.
Taking a card pays `40 × (patch size − 1)` from the bank, so joining one of
your cards pays 40, a patch of 3 pays 80, a patch of 5 pays 160. Rivals'
cards don't count and block your patch from growing through them. Free slots
show what they would pay you.

Cards that need a choice (a lot, a block, a swap) do nothing if there is no
valid choice. Only Swap Meet may be declined.

1. **Scrap Drive** — every other player pays you 40.
2. **Parking Ticket** — pay 100 into the Pot.
3. **Rush Hour** — roll again and move.
4. **Inspection** — pay 25 to the bank for every renovation tier you own.
5. **Grand Opening** — one of your lots gains +20% value for good.
6. **Power Cut** — a rival's lot charges no rent until its owner's next turn.
7. **Lucky Find** — gain 150.
8. **Bond Bump** — a block's bond price rises 15% until its value changes.
9. **Bond Slump** — a block's bond price falls 15% until its value changes.
10. **Shortcut** — jump to the nearest Relay you haven't punched (punch it, land there; no salary for skipping past the Depot).
11. **Tax Refund** — gain 5% of your lot value.
12. **Swap Meet** — swap one of your Shacks for a rival's Shack, paying them the difference if theirs is worth more.
13. **Charity** — the richest player gives 100 to the poorest.
14. **Back to Base** — go straight to the Depot (PAYDAY with every suit; wins if at goal).
15. **Free Renovation** — renovate one of your lots by one tier for free.
16. **Pot Luck** — take half the Pot.
17. **Heavy Traffic** — you don't move on your next turn.
18. **Double Rent** — the next rent you collect is doubled.
19. **Market Tip** — buy up to 10 bonds in a block at 10% off.
20. **Scrap Tax** — pay 10% of your cash to the bank.

## Bankruptcy

- If a payment would push cash below 0, the player must raise money:
  1. sell bonds at the current price, then
  2. sell lots back to the bank at **70% of value** (player chooses which).
  Lots sold to the bank become unowned at tier 0.
- If everything is sold and cash is still negative, the player is **broke**
  and the game ends (see Win condition).

## Turn order

1. Start of turn: check the Goal; Depot bond trading if standing there.
2. Roll and move (choose branches).
3. Resolve the landing space.
4. Optional: none. (Keep turns snappy; trading happens only on spaces.)
5. End of turn.

## Computer players (phase 1)

Simple, rule-driven:

- Buy a lot if cash after buying stays above a safety reserve (300 S + 10%
  of the most expensive rent on the board).
- Renovate when it completes or strengthens a block, keeping the reserve.
- Prefer branches leading towards unpunched Relays, or the Depot when at Goal.
- Buy bonds in blocks where they own most lots; sell when cash is short.

Difficulty levels later tune the reserve and how far ahead they look.

## Boards

Boards are JSON files in `boards/` (format in `boards/README.md`), so new
boards need no code. All boards and art are original.

## Roadmap

1. **Core** — rules engine (pure logic, no UI) with headless tests; one board.
2. **Playable hot-seat** — board drawn in 2D, dice, menus for every decision.
3. **Computer players.**
4. **Online** — host-authoritative over Epic Online Services (lobbies + P2P
   relay) via the godot-epic-online-services plugin.
5. **Polish** — more boards, art, sound, settings.
