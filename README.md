Plugins may use [**sourcemod-nt-include**](https://github.com/softashell/sourcemod-nt-include/), download **.inc** file and place it in your compiler include directory.

nt_damage
====================
Shows detailed damage dealt/received in console on death/round end.

Also adds optional assist awards since it keeps track of damage anyway
- **sm_ntdamage_assists** 0 - Enable/Disable rewarding of assists
- **sm_ntdamage_damage** 45 - Damage required to trigger assist
- **sm_ntdamage_points** 1 - Points given for each assist
- **sm_ntdamage_assistmode** - Switches assist mode, default is 0
	- 0 - Gives out points only when player did enough damage to dead player
	- 1 - Sums all assisted damage and gives out points when enough damage has been assisted in total (**sm_ntdamage_damage** should be set above 100)

nt_ghostcap
====================
Logs ghost capture event so you can award players in HLSTATSX:CE, also creates OnGhostCapture(client) forward other plugins can use (example in nt_ghostcap_test.sp)

nt_doublecap
====================
Removes ghost when round has ended to prevent double capping
* **Requires nt_ghostcap to work**
* **Requires ["NEOTOKYO OnRoundConcluded Event"](https://github.com/Rainyan/sourcemod-nt-onroundconcluded-event) to work**

nt_drop
====================
- Keeps weapons on ground all round.
	- Can be toggled with cvar: **sm_ntdrop_nodespawn** - Whether weapons' spawnflags are adjusted to prevent the weapon from disappearing from the world after 30 seconds
- Drops weapons with all spare ammo.
- Disables ammo pick up from dropped weapons.
- Optionally enables weapon pick up and switch with +use (compile with `ENABLE_USE` preprocessor flag set as true)
- Works out of the box for SourceMod version 1.11 or newer
	- **SourceMod 1.10 or older**: You need the correct version of [the DHooks extension](https://forums.alliedmods.net/showpost.php?p=2588686) for your SM version!

nt_autojump
====================
Enables quake like bunnyhopping

nt_noobname
====================
Changes the name of any **NeotokyoNoob** connecting to random podbot name

nt_mirrordamage
====================
For first 7 seconds of a round or before first enemy takes damage by default team attackers will take double damage they inflicted and victim will not lose any health

nt_radio
====================
Adds **!radio** command so players can listen to included soundtrack

nt_unlimitedsquads
====================
Automatically assigns players to ALPHA or any other squad and allows unlimited squad size plus squad locking with cvars

- **sm_nt_squadautojoin** 1-5 - changes the default squad players will join
- **sm_nt_squadlock** 0 - blocks squad changing, disabled by default
