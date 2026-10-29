# Board format

One JSON file per board. Top-level fields:

| Field         | Type   | Meaning |
|---------------|--------|---------|
| `name`        | string | Shown in menus. |
| `goal`        | int    | Net worth needed to win. |
| `start_cash`  | int    | Each player's starting Scrap. |
| `base_salary` | int    | Salary for passing the Depot. |
| `relay_bonus` | int    | Extra salary per Relay punched this lap. |
| `blocks`      | object | Block id -> `{ "name", "color" }` (colour as `#rrggbb`). |
| `spaces`      | array  | The spaces, see below. |

Each space:

| Field   | Required for | Meaning |
|---------|--------------|---------|
| `id`    | all          | Must equal its index in the array. |
| `type`  | all          | `depot`, `relay`, `lot`, `market`, `wildcard`, `workshop`, `toll`, `jackpot`, `detour`, `junction`. |
| `x`,`y` | all          | Grid position used for drawing (1 unit = one space). |
| `next`  | all          | Ids you can move to from here; more than one = a branch. |
| `block` | `lot`        | Block id. |
| `price` | `lot`        | Base price. |
| `pair`  | `detour`     | Id of the Detour space this one warps to. |
| `mark`  | `relay`      | Short symbol name shown on the space and the player panel (e.g. `Gear`). |
| `color` | `relay`      | The relay's colour, `#rrggbb`. Each relay should have a distinct one. |
| `name`  | optional     | Display name. |

Movement follows `next` only, so the board is directed. Exactly one `depot`
is required. The loader checks all of this and reports the first problem.
