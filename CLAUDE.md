# ldjam59 — Ludum Dare 59 ("Signal")

Godot 4.6 game jam project. Theme exploration is in `README.md` — current direction is undecided; multiple concepts (signal-on-wire rhythm, spectrogram puzzle, echolocation, circuit-completion vs hostile wires) are still on the table.

## Engine config (`project.godot`)

- Godot **4.6**, features `["4.6", "Mobile"]`
- Renderer: **Mobile** rendering method, **Direct3D 12** driver on Windows
- 3D physics: **Jolt Physics** (4.6 default)
- Stretch: `canvas_items` / `expand`
- Main scene: `uid://uh5m17lb4xqr` → `level.tscn`

## Project layout

| Path | Role |
|------|------|
| `level.tscn` | **Main scene.** Camera3D, ground plane, `DirectionalLight3D`, `DynamicChain` instance, `Path3D` + `PathFollow3D` carrying a sphere-on-StaticBody3D animated on a loop (`AnimationPlayer` autoplay). |
| `dynamic_chain.gd` + `.tscn` | `@tool` `class_name DynamicChain extends Node3D`. Procedurally builds a chain of `RigidBody3D` links connected by `Generic6DOFJoint3D` (linear locked, angular limited). Editor-side regeneration on `link_count` setter; runtime build in `_ready` (skipped in editor). Requires `anchor: StaticBody3D` + `link_container: Node3D` to be assigned in inspector. |
| `scene.tscn` + `player.gd` + `img/` | **Leftover 2D template.** TileMapLayer + animated `CharacterBody2D` with `ui_*` input. Not referenced by the main scene; safe to delete or repurpose. |
| `.godot/` | Engine cache, do not edit |
| `*.gd.uid` / `*.tscn` UIDs | 4.x stable resource IDs — preserve them |

## Conventions

- **Static typing required.** All new GDScript uses typed vars/params/returns (`var x: int`, `-> void`).
- **Annotations not legacy keywords**: `@export`, `@onready`, `@tool`, `@rpc`.
- **Signals up, method calls down.** Don't have children reach into parents.
- **`%UniqueName`** for cross-tree refs over `$Path/To/Node`.
- Scene unique_ids in `.tscn` files are 4.6's stable node IDs — leave them alone when editing manually.
- Indentation in `.gd` files is 4-space (per `.editorconfig` ... actually empty; match existing files = **4-space**).

## Gotchas specific to this project

- `DynamicChain._generate_chain()` `await get_tree().process_frame` before creating joints — links must be in the tree first. Joint `node_a`/`node_b` are also reassigned in a `ready.connect` lambda because `NodePath`s only resolve once joints are parented.
- `_clear_chain()` queue_frees both tracked arrays *and* every child of `link_container` — re-running mid-frame can leak orphans if you skip either pass.
- The chain instance in `level.tscn` sits at `y ≈ 9.1` with `link_count = 8`; gravity will swing it immediately on play.
- `Path3D` curve is `closed = true`; `PathFollow3D` loops via `AnimationPlayer` ratio 0→1.
- Mobile renderer + D3D12: some desktop-renderer-only effects (e.g. SDFGI, volumetric fog) won't work. SSAO and tonemap (filmic) are enabled in the level's `Environment`.
- Jolt is non-deterministic vs Godot Physics 3D — don't expect identical stacking/restitution behavior if you reference older Godot tutorials.

## Reference

- Godot 4.6 docs via Context7: `/websites/godotengine_en_4_6` (use for any API lookup).
- Skill router for Godot work: see `~/.claude/skills/godot/SKILL.md`.
