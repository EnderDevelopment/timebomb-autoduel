# Roblox Timebomb Duels

A two-player Roblox dueling game where opponents face off around a timed bomb. The game features an Auto-Play "Pro Bot" system that automatically takes over empty seats or can be enabled by players, providing professional-level gameplay with optimal positioning and blast prediction. Players must survive within the arena while avoiding the bomb's blast radius to score points and win the match.

## Install

1. Create a new Roblox place or open an existing one.
2. Build an arena with:
   - Two spawn pads named `Player1Pos` and `Player2Pos`
   - A `BombSpawn` part in the center of the arena
   - Place these parts inside a Model named `Arena` in Workspace
3. Insert the provided scripts:
   - Place `TimebombServer` script in `ServerScriptService`
   - Place `TimebombClient` LocalScript in `StarterPlayer > StarterPlayerScripts`
4. The server will automatically create the bomb at the BombSpawn location on game start.

## Use

1. Start the game – the server assigns players to seats automatically.
2. If only one player is present, the Auto-Play Pro Bot takes the empty seat.
3. Use the on-screen HUD to see fuse time, round timer, and scores.
4. Click the "Auto-Play" button to toggle the Pro Bot to control your character.
5. Survive rounds by staying in the arena and avoiding the bomb blast.
6. First player to score 3 points (default) wins the match.

---

More Roblox script projects by EnderDevelopment: https://github.com/EnderDevelopment

Project page: https://dash.enderdevelopment.com/community/243c177b-2621-4b11-9ba3-fcb0fc78120a?utm_source=github&utm_medium=readme&utm_campaign=auto_publish&utm_content=243c177b-2621-4b11-9ba3-fcb0fc78120a
