# STEAL A BRAINROT — Italian Brainrot Tycoon

A 3D Roblox tycoon in the genre Steal a Brainrot began. Fifteen absurd Italian
brainrot legends ride a conveyor belt through the middle of the map. Buy them
off the belt, stand them on your base, and watch the cash tick in every second
— then sneak onto a rival's base, rip their best brainrot off its stand, and
dash home with it on your head before they catch you.

## How to play

- **Buy.** Brainrots roll down the central conveyor, from a $50 Tralalero
  Tralala up to the $7,500,000 Dragon Cannelloni. Rarer ones roll less often:
  Common 46%, Rare 28%, Epic 16%, Legendary 7%, Mythic 3%. Walk up to one and
  hold its **Buy** prompt. It takes a free stand on your base (six per base)
  and starts earning its rate every second.
- **Earn.** You start with $100. Every brainrot on your base pays its
  IncomePerSecond into your Cash once a second; the HUD shows your cash and
  your current +$/s.
- **Steal.** Any brainrot on a rival's base can be grabbed with its **Steal**
  prompt. It rides on your head and slows you down — by 5% for a Common, up
  to 50% for the Dragon Cannelloni. Touch the glowing green pad on your own
  base to bank it: it takes a free stand of yours, or sells for its full
  price if your base is full. Die on the way home and the brainrot goes back
  to its owner.
- **Defend.** The **LOCK BASE** button raises a shield wall across your base
  for 30 seconds; nothing can be stolen from a locked base. The lock then
  recharges for 30 more seconds.

Eight bases ring the belt, four north and four south. Joining assigns you a
free one and sends you to it; leaving frees it for the next player.

## The cast

Fifteen brainrots in five rarities, each with its own price, income rate,
carry slowdown and colour: Tralalero Tralala, Tung Tung Tung Sahur, Brr Brr
Patapim (Common); Chimpanzini Bananini, Cappuccino Assassino, Frigo Camelo
(Rare); Bombardiro Crocodilo, Bombombini Gusini, La Vaca Saturno Saturnita
(Epic); Giraffa Celeste, Matteo, La Grande Combinazione (Legendary); Los
Tralaleritos, Graipuss Medussi and Dragon Cannelloni (Mythic).

## How it is built

A Rojo 7 project. Every script of the place is a `.luau` file under `src/`:

- `src/ReplicatedStorage/Shared/BrainrotData.luau` — a ModuleScript holding
  the whole cast (price, income, slowdown, colour, rarity weights) and the
  one `BuildModel` function that builds each blocky 3D character with its
  floating name label.
- `src/ServerScriptService/GameManager.server.luau` — builds the world at
  runtime (lawn, conveyor, eight bases with stands, owner signs, delivery
  pads and lock walls), creates the shared RemoteEvents, and assigns and
  frees bases as players join and leave.
- `src/ServerScriptService/Conveyor.server.luau` — rolls weighted-random
  brainrots onto the belt, slides them along, and hands buy prompts to the
  economy.
- `src/ServerScriptService/Economy.server.luau` — leaderstats Cash and
  Income, the per-second income tick, and placing bought or delivered
  brainrots on stands.
- `src/ServerScriptService/Steal.server.luau` — steal prompts, carrying on
  the head with the tier slowdown, delivery at your own pad, returning a haul
  when its thief dies, and the base lock (30s shield, 60s cooldown).
- `src/StarterPlayerScripts/HUD.client.luau` — the ScreenGui: title, cash and
  income readouts, the LOCK BASE button and event toasts.

Client and server talk through two RemoteEvents in `ReplicatedStorage.Remotes`
(`Notify` server-to-client, `LockBase` client-to-server); server scripts talk
through two BindableEvents in ServerStorage (`BuyRequest`, `PlaceRequest`).

## Run it

Build the place from source and hand it in locally:

    ~/workspace/tools/rojo/rojo build default.project.json --output game.rbxl
    mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts

`main.ts` copies `game.rbxl`, `src/`, `screenshots/` and `PLAY.json` to the
output directory and writes `dossier.json` with the vendored
`vendor/makefun-roblox.ts`. The published game is at the link in `PLAY.json`;
`screenshots/1-thumbnail.png` is also the experience's first thumbnail on
Roblox, and `TOUR.json` shows reviewers how to reach each screenshot's scene.
