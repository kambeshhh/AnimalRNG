# Animal RNG ("Hayvan Olarak Koş")

Roll for animals across a 28-tier rarity ladder and 8 mutations, then run around the hub as the creature you rolled.

- Place: `89511558428310` · Universe: `10777840386`
- Code layout: Rojo-compatible (`default.project.json`)

## Layout

| Repo path | Studio location | What |
|---|---|---|
| `src/server/ServerInit.server.luau` | `ServerScriptService.ServerInit` | Boots services (Init → Start), Action router, Studio-only `DevTestHook` + `/tier N` |
| `src/server/Services/*` | `ServerScriptService.Services` | Data, Roll, Morph, Admin, Monetization, Leaderboard, Weather, Forge, Altar, Totem, … |
| `src/shared/Modules/*` | `ReplicatedStorage.Modules` | `AnimalData` (registry, tiers, mutations, odds, Roll), `Config`, `Net`, `NumberFormat`, `UITheme` |
| `src/client/**` | `StarterPlayer.StarterPlayerScripts` | `Controllers/` (UI, Roll, Cutscene, Animation, Ability) + `ClientInit` |
| `assets/manifest.json` | `ReplicatedStorage.Animals` | Creature templates: group, weight, mesh/texture asset IDs |
| `tools/blender/` | — | Headless Blender pipeline (decimate, bake, outline, auto-rig, FBX export) |
| `tools/export/` | — | Assembles scripts exported from Studio into `src/` |

**Not in git:** the map, the UI (`StarterGui.RNGHud`), the creature templates and the props. These are instances inside the place. Rojo is set to `$ignoreUnknownInstances`, so syncing code never deletes them. For a full binary snapshot, use File → Save to File as `place/AnimalRNG.rbxl`.

## Core rules

- **Odds:** odds = creatureOdds × `Tiers[T].Min` × mutation multiplier.
  - Full comma-separated numbers on cutscenes, announcements and inspection.
  - Compact form (`K…Sx`) on cards and boards.
- **Groups** (from model attributes): Starter 65% · Apex 22% · Mythical 11% · Cosmic 2%.
- **Ouroboros:** the only tier-28 (Unattainable) creature. It never drops at tiers 1–27.
- **Mutations:**

  | Mutation | Multiplier |
  |---|---|
  | Normal | ×1 |
  | Gilded | ×5 |
  | Prismatic | ×25 |
  | Abyssal | ×150 |
  | Astral | ×1,000 |
  | Chrono-Shifted | ×10,000 |
  | Sovereign | ×100,000 |
  | Singularity | ×1,000,000 |

- **Luck:** additive free bonuses × paid multiplier (capped at ×4) × server event × bonus roll.
- **Server authority:** every remote is validated on the server. Admin actions go through `RS.Remotes.Admin`:
  - Dev actions require `Config.Admin.DevUserIds`, the place owner or `DevGroup`.
  - VIP actions require the `VIPAdmin` pass.

## Workflow

```sh
rokit add rojo-rbx/rojo   # or: aftman / cargo install rojo
rojo serve                # then connect the Rojo plugin in Studio
```

Studio test hook (Studio only, in `ServerStorage.DevTestHook`): `Invoke(action, playerName, ...)`.

- `Sandbox, name, true`: the session stops saving and stays off the global leaderboards. Use it before any test grants.
- `Give, name, animal, {Tier, Mutation}` · `Purge, name, {ids}, {DropIndex}` · `PreviewTier, name, n, announce` · `Data, name`

## Before going live

- Create the passes and products on the Creator Hub (currently Id 0, which means Studio test grants only):
  - Set `Config.Monetization.Passes.*.Id`, including `VIPAdmin`.
- Set `Config.Admin.DevUserIds` / `DevGroup`.
- Consider setting `Config.Admin.AllowStudioTesters = false`.
