# Board format

One JSON file per board. Top-level fields:

| Field         | Type   | Meaning |
|---------------|--------|---------|
| `name`        | string | Shown in menus. |
| `goal`        | int    | Net worth needed to win. |
| `start_cash`  | int    | Each player's starting Scrap. |
| `base_salary` | int    | Salary for passing the Depot. |
| `relay_bonus` | int    | Extra salary per Relay punched this lap. |
| `theme` | string | The backdrop round the board: `sea` (default), `space`, `volcano`, `castle`, `racing` or `storm`. |
| `props` | array | Optional, for 3D boards: things the board stands on, each `{kind: "island" or "tower", at: [x, y, z], size: [w, d] (island) or [w, h, d] (tower), depth}` in tiles. |
| `camera` | array | Optional: the direction the camera looks at the board from, `[x, y, z]` (default `[0, 0.85, 0.55]`). |
| `blocks`      | object | Block id -> `{ "name", "color" }` (colour as `#rrggbb`). |
| `spaces`      | array  | The spaces, see below. |

Each space:

| Field   | Required for | Meaning |
|---------|--------------|---------|
| `id`    | all          | Must equal its index in the array. |
| `type`  | all          | `depot`, `relay`, `lot`, `market`, `wildcard`, `workshop`, `toll`, `warp`, `detour`, `junction`, `dice`, `arcade`, `interest` (Star), `break` (Moon), `plot` (an empty building plot). |
| `x`,`y` | all          | Grid position used for drawing (1 unit = one space). |
| `next`  | all          | Ids you can move to from here; more than one = a branch. |
| `block` | `lot`        | Block id. |
| `price` | `lot`        | Base price. |
| `pair`  | `detour`, `warp` | Id of the Detour space this one warps to; for a warp pad, its partner (also in `next`). |
| `at`    | optional     | 3D boards: world position in tiles, `[across, up, towards the camera]` (else `x`, 0, `y`). |
| `face`  | optional     | 3D boards: `up` (default) or `front` (stood on a wall facing the camera)., or a direction `[x, y, z]` its top points (round a bottle). |
| `mark`  | `relay`      | The suit: `Spade`, `Heart`, `Diamond` or `Club`. |
| `color` | `relay`      | The relay's colour, `#rrggbb`. Each relay should have a distinct one. |
| `name`  | optional     | Display name. |

Movement follows `next` only, so the board is directed. Exactly one `depot`
is required. The loader checks all of this and reports the first problem.

## Making a board from a text map

The easy way to add a board: draw it in `boards/maps/<name>.txt` and run

    perl tools/make_boards.pl

which writes `boards/<name>.json` for every map (and checks each one). The
home menu's board picker lists every `.json` in this folder, so a new board
shows up there by itself.

A map file has `key: value` lines (`name`, `goal`, `start_cash`,
`base_salary`, `relay_bonus`, `theme` (the backdrop: sea, space, volcano,
castle, racing or storm), and optionally `names:` a comma-separated list
of lot names, or `name_offset:` to start further along the built-in list),
then `map:` and the board, one cell per space, cells separated by spaces.
Cells next to each other (left, right, up, down) are linked both ways: you
can walk either way, and turn round at a dead end.

| Cell | Space | Cell | Space |
|---|---|---|---|
| `D` | Depot | `a`–`h` | a lot in block A–H |
| `S` `H` `V` `C` | the suits: Spade, Heart, Diamond, Club | `*` | Star |
| `M` | Moon | `P` | building plot |
| `?` | Wildcard | `R` | Dice |
| `X` | Arcade | `K` | Market |
| `T` / `W` | Toll / Workshop | | |
| `+` | plain path | `.` | nothing |

Every board needs one Depot, the four suits, one Star, one Moon, three plots,
two Dice and one Arcade, every block at least two lots, and every space
reachable from the Depot; the script stops on the first problem. Lot prices
rise block by block (in order of first appearance) and within each block.
Sea Pirates is hand-written JSON (a one-way loop), not made from a map.
