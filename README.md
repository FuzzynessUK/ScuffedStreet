# Scuffed Street

An original property-trading board game for 2–4 players, made in Godot 4.7.
Buy lots, renovate them, trade block bonds and race to a net-worth goal.
Rules: [docs/DESIGN.md](docs/DESIGN.md). Board format: [boards/README.md](boards/README.md).

Placeholder graphics only for now.

## Run

Open the folder in Godot 4.7 and press F5, or:

    Godot_v4.7.2-stable_win64.exe --path .

Dev switches (after `--`): `--watch` starts an all-CPU game, `--shot=<file.png>`
saves a screenshot after 8 seconds and quits.

## Tests

    Godot_v4.7.2-stable_win64_console.exe --headless --path . --import
    Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_core.gd
    Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/sim_cpu.gd

`test_core.gd` checks the rules; `sim_cpu.gd` plays 200 all-CPU games and
reports how they end (useful for balancing).

## Layout

- `scripts/core/` — rules engine with no UI (`GameState`, `Board`, `PlayerState`, `Cpu`)
- `scripts/ui/` — the hot-seat screen and the basic 3D board (placeholder meshes)
- `boards/` — board JSON files
- `tests/` — headless tests and the CPU simulation
