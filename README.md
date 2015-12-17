Plugins may use [**sourcemod-nt-include**](https://github.com/softashell/sourcemod-nt-include/), download **.inc** file and place it in your compiler include directory.

nt_damage
====================
Shows detailed damage dealt/received in console on death/round end.

Also adds optional assist awards since it keeps track of damage anyway
- **sm_ntdamage_assists** 0 - Enable/Disable rewarding of assists
- **sm_ntdamage_damage** 100 - Total damage required to trigger assist
- **sm_ntdamage_points** 2 - Points given for each assist

nt_ghostcap
====================
Logs ghost capture event so you can award players in HLSTATSX:CE, also creates OnGhostCapture(client) forward other plugins can use (example in nt_ghostcap_test.sp)
- **sm_ntghostcap_doublecap** 0 - Enable/Disable experimental double capture prevention, in rare cases it can disable ghost capturing completely for the map so it's disabled by default

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
