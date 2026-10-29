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
- Move exactly that many spaces. At a junction the player picks a branch.
  You may never step back onto the space you just came from.
- Spaces passed through can trigger "pass" effects (Depot, Relays); only the
  final space triggers its "land" effect.

## Laps: Relays and salary

- Each board has **3 Relay** spaces. Passing or landing on a Relay you have not
  visited this lap gives you its **punch** (each Relay counts once per lap).
- Passing or landing on the **Depot** pays salary and resets your punches:

  `salary = base_salary + punches × relay_bonus + 5% of your total lot value`

  Defaults: base 200, relay bonus 150. A lap with no punches still pays base.
- So there is no required order or "full set": every Relay you hit adds money,
  and big landlords earn more from laps.

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
- **Dividends:** when rent is paid on any lot in a block, each bondholder of
  that block receives `rent × 1%` per bond held, paid by the bank.
- **Pressure:** a single purchase of 10+ bonds raises that block's bond price
  10% until the next change in its value; a sale of 10+ lowers it 10%.

## Space types

| Space    | Effect |
|----------|--------|
| Depot    | Start. Salary when passed/landed. Bond trading when you start a turn here. |
| Relay    | Punch for this lap (see above). Landing also gives 50 S. |
| Lot      | Buy / pay rent / renovate. |
| Market   | Trade bonds. |
| Wildcard | Draw a Wildcard (see deck). |
| Workshop | Renovate any one of your lots by one tier at 80% cost. |
| Toll     | Pay 8% of your cash into the **Pot**. |
| Jackpot  | Collect the whole Pot. |
| Detour   | Warp to the paired Detour space; your move ends there. |
| Junction | No effect; a branch point (any space may branch, this one is just empty). |

## Wildcard deck (first draft)

Shuffled 20-card deck; discards reshuffle when it runs out.

1. **Scrap drive** — every player pays you 40 S.
2. **Parking ticket** — pay 100 S to the Pot.
3. **Rush hour** — roll again now and move.
4. **Inspection** — pay 25 S per renovation tier you own.
5. **Grand opening** — choose one of your lots: +20% value (permanent).
6. **Power cut** — choose a rival's lot: it charges no rent until their next turn.
7. **Lucky find** — gain 150 S.
8. **Bond bump** — choose a block: its bond price +15% until its value changes.
9. **Bond slump** — choose a block: its bond price −15% until its value changes.
10. **Shortcut** — move to the nearest Relay you have not punched (no salary for passing Depot).
11. **Tax refund** — gain 5% of your lot value.
12. **Swap meet** — swap one of your Shacks with a rival's Shack of lower or equal value (their consent not needed).
13. **Charity** — the richest player gives 100 S to the poorest.
14. **Back to base** — go to the Depot (collect salary).
15. **Free renovation** — renovate one lot by one tier for free.
16. **Pot luck** — take half the Pot.
17. **Heavy traffic** — skip your next roll; you still get your turn's actions.
18. **Double rent** — the next rent you collect is doubled.
19. **Market tip** — buy up to 10 bonds anywhere now at −10%.
20. **Scrap tax** — pay 10% of your cash to the bank.

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
