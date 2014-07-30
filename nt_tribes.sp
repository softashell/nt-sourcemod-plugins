#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

new Handle:hEnabled, Handle:hFriction, Handle:hAirAccelerate, Handle:hAccelerate;

new gOffsetMyWeapons, gOffsetAmmo;

new bool:bFreezeTime, bDuel;

new Float:gTopSpeed[MAXPLAYERS+1], Float:gCurrentSpeed[MAXPLAYERS+1], gFastest, Float:gFastestSpeed;

new Float:flLastCheck, Float:flRoundStartTime;

new lastplayer_jinrai, lastplayer_nsf;

public Plugin:myinfo =
{
    name = "TRIBESTOKYO°",
    author = "soft as HELL",
    description = "fun allowed",
    version = "1.0",
    url = ""
};

public OnPluginStart()
{
	// Get cvar handles
	hEnabled = CreateConVar("sm_nt_tribes", "0", "Enable shitty game mode");
	hFriction = FindConVar("sv_friction");
	hAirAccelerate = FindConVar("sv_airaccelerate");
	hAccelerate = FindConVar("sv_accelerate");

	// Hook sm_nt_tribes value change
	HookConVarChange(hEnabled, toggle_plugin);

	// Hook player commands
	AddCommandListener(cmd_handler, "setclass");
	AddCommandListener(cmd_handler, "loadout");
	AddCommandListener(cmd_handler, "loadoutmenu");

	HookEvent("player_spawn", event_PlayerSpawn);
	HookEvent("game_round_start", event_RoundStart);

	// Get offsets
	gOffsetMyWeapons = FindSendPropInfo("CBasePlayer", "m_hMyWeapons");
	gOffsetAmmo = FindSendPropInfo("CBasePlayer", "m_iAmmo");
}

public OnClientPutInServer(client)
{
	gTopSpeed[client] = 0.0;
	gCurrentSpeed[client] = 0.0;
}

public OnAutoConfigsBuffered() {
	decl String:currentMap[64];
	GetCurrentMap(currentMap, 64);

	// if current map is vtol automatically enable plugin
	if(StrEqual(currentMap, "nt_vtol_ctg"))
		SetConVarInt(hEnabled, 1);
	else
		SetConVarInt(hEnabled, 0);

	bFreezeTime = true;
	bDuel = false;

	gFastest = 0;
	gFastestSpeed = 0.0;

	lastplayer_jinrai = 0;
	lastplayer_nsf = 0;

	flLastCheck = GetGameTime();
	flRoundStartTime = GetGameTime();
}

public toggle_plugin(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	// Set server cvars when sm_nt_tribes is changed
	if (StringToInt(newVal) >= 1)
	{
		SetConVarFloat(hFriction, 0.0);
		SetConVarInt(hAirAccelerate, 1000);
		SetConVarInt(hAccelerate, 1000);
	}
	else
	{
		SetConVarInt(hFriction, 4);
		SetConVarInt(hAirAccelerate, 10);
		SetConVarInt(hAccelerate, 10);
	}

}

public Action:cmd_handler(client, const String:command[], args)
{
	if(GetConVarInt(hEnabled) < 1)
		return Plugin_Continue;

	decl String:cmd[3];
	GetCmdArgString(cmd, sizeof(cmd));

	new arg = StringToInt(cmd);

	if(StrEqual(command, "setclass"))
	{
		// Allow only REKIN
		if (arg != 1)
		{
			// Force recon
			SetPlayerClass(client, 1);

			PrintToChat(client, "You're only allowed to play RECON on this map!");

			// Show class menu again
			ClientCommand(client, "classmenu");

			return Plugin_Handled;
		}
	}
	else if(StrEqual(command, "loadout"))
	{
		/* If plugin in enabled mid map players only see loadout menu when spawning
			so we have to force recon here again if players isn't one already */
		if(GetPlayerClass(client) != 1)
		{
			SetPlayerClass(client, 1);
			ClientCommand(client, "setclass 1");
		}

		// Not really needed but it just forces everyone to spawn with mpn
		if( arg != 0 )
		{
			ClientCommand(client, "loadout 0");
			return Plugin_Handled;
		}
	}
	else if(StrEqual(command, "loadoutmenu"))
	{
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(GetConVarInt(hEnabled) < 1)
		return;

	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (!IsClientInGame(client))
		return;

	// Delay stripping of weapons because this is called before players get weapons
	CreateTimer(0.4, timer_GiveWeapons, client);
}

public Action:event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	bDuel = false;
	bFreezeTime = true;

	flRoundStartTime = GetGameTime();
}

public Action:timer_GiveWeapons(Handle:timer, any:client)
{
	if(GetConVarInt(hEnabled) < 1)
		return;

	if(!IsClientInGame(client))
		return;

	if(!IsPlayerAlive(client))
		return;

	new String:classname[13];

	// NT has only five weapon slots, loop trough them and remove all valid weapons
	for(new weapon = 0; weapon <= 5; weapon++)
	{
		// Get entity id from offset
		new wpn = GetEntDataEnt2(client, gOffsetMyWeapons + (weapon * 4));

		if(!IsValidEntity(wpn))
			continue;

		if(!GetEdictClassname(wpn, classname, 13))
			continue; // Skip if we for some reason can't get classname

		if(StrEqual(classname, "weapon_knife"))
			continue; // Skip if it's knife

		RemovePlayerItem(client, wpn);
		RemoveEdict(wpn);
	}

	SetWeaponAmmo(client, 11, 92); // shotgun ammo + 7 shells in magazine
	SetWeaponAmmo(client, 5, 54);  // secondary ammo + 6 shells in magazine

	GivePlayerItem(client, "weapon_remotedet");
	GivePlayerItem(client, "weapon_kyla");

	new iWeapon = GivePlayerItem(client, "weapon_supa7");

	if( iWeapon != -1)
		AcceptEntityInput(iWeapon, "use", client, client);

	// Print the disclaimer but doesn't seem any of the noobs even care what's going on
	PrintToChat(client, "You're now playing TRIBESTOKYO° don't take this too seriously and have fun");

	if(gFastest != 0)
	{
		if(IsClientInGame(gFastest))
		{
			// If fastest player is set from last round display it
			// 1 unit = 0.01905 meters
			PrintToChat(client, "Top speed: %.1f m/s by %N (Your top speed last round: %.1f m/s)", gFastestSpeed*0.01905, gFastest, gTopSpeed[client]*0.01905);
		}
	}

	gTopSpeed[client] = 0.0;
}

public OnGameFrame()
{
	if(GetConVarInt(hEnabled) < 1)
		return;

	new Float:gametime = GetGameTime();

	// Freezetime is still active
	if(bFreezeTime)
	{
		if((gametime - flRoundStartTime) >= 15.0)
			bFreezeTime = false; // if 15 seconds have passed disable it
		else
			return; // skip this frame
	}

	new jinrai, nsf;

	for(new i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;

		if(GetClientTeam(i) <= 1) // Spectator or no team assigned
			continue;

		if (!IsPlayerAlive(i))
			continue;

		// Update Player Speed every frame
		UpdateCurrentSpeed(i);

		// Skip past this point if one second hasn't passed since last check
		if((gametime - flLastCheck) < 1.0)
			continue;

		if(GetClientTeam(i) == 2) // Jinrai
		{
			jinrai++;
			lastplayer_jinrai = i;
		}
		else // NSF
		{
			nsf++;
			lastplayer_nsf = i;
		}

		// Give weapons ammo and refill AUX
		SetPlayerData(i);

		// Compare players speed against other players if needed
		CheckPlayerSpeed(i);
	}

	if((gametime - flLastCheck) >= 1.0)
	{
		// Enable suddn death if only 1 player on each team
		if(jinrai == 1 && nsf == 1)
			bDuel = true;
		else
			bDuel = false;

		flLastCheck = gametime;
	}
}

UpdateCurrentSpeed(client)
{
	// Get velocity vector
	decl Float:velocity[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", velocity);
	/* Seems to spam warnings because player is going too fast
	DataTable warning: (class player): Out-of-range value (-2079.884033) in SendProp Float 'm_vecVelocity[0]', clamping. */

	new Float:speed = GetVectorLength(velocity);

	gCurrentSpeed[client] = speed;

	// Show speed in center
	PrintCenterText(client, "%.1f", speed * 0.01905);

	// Going faster than previous top speed
	if(speed > gTopSpeed[client])
		gTopSpeed[client] = speed;

	// Going faster than current record
	if(speed > gFastestSpeed || gFastest == 0)
	{
		gFastest = client;
		gFastestSpeed = speed;
	}

}

SetPlayerData(client)
{
	decl String:classname[64];

	// Set AUX to 100 for unlimited super jump
	SetEntPropFloat(client, Prop_Send, "m_fSprintNRG", 100.0);

	// Keep thermoptic camo at 0 charge because can't see shit as it is on vtol already
	SetEntPropFloat(client, Prop_Send, "m_fThermopticNRG", 0.0);

	new weapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
	if(weapon == -1)
		return; // No weapon equipped

	GetEdictClassname(weapon, classname, 64);

	// Set back to max ammo in magazine
	if(StrEqual(classname, "weapon_supa7"))
		SetEntProp(weapon, Prop_Send, "m_iClip1", 7);
	else if(StrEqual(classname, "weapon_kyla"))
		SetEntProp(weapon, Prop_Send, "m_iClip1", 6);

}

CheckPlayerSpeed(client)
{
	// Player is moving too slow
	if(gCurrentSpeed[client] <= 200)
	{
		// 15 second freezetime + 2 seconds to give player a chance to move
		if((GetGameTime() >= flRoundStartTime+17.0)) 
			ReduceHealth(client, 5);
	}
	else if(bDuel) // Only 2 players alive
	{
		// if client is in jinrai set enemy to last nsf player or vice versa
		new enemy = GetClientTeam(client) == 2 ? lastplayer_nsf : lastplayer_jinrai;

		if(enemy == 0)
			return;

		if(!IsClientInGame(enemy))
			return;

		if(!IsPlayerAlive(enemy))
			return;

		// Player is slower than enemy
		if(gCurrentSpeed[client] < gCurrentSpeed[enemy])
			ReduceHealth(client, 2); // Reduce health by 2
	}

}

ReduceHealth(client, damage)
{
 	new health = GetClientHealth(client) - damage;

	if (health < 0)
		health = 0;

	SetEntProp(client, Prop_Send, "m_iHealth", health, 1);
	SetEntProp(client, Prop_Data, "m_iHealth", health, 1);

	if (health <= 0)
		ForcePlayerSuicide(client);
}

stock SetPlayerClass(client, class)
{
	return SetEntProp(client, Prop_Send, "m_iClassType", class);
}

stock GetPlayerClass(client)
{
	return GetEntProp(client, Prop_Send, "m_iClassType");
}

stock SetWeaponAmmo(client, type, ammo)
{
    return SetEntData(client, gOffsetAmmo + (type * 4), ammo);
}