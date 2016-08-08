#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <neotokyo>

public Plugin:myinfo =
{
    name = "NEOTOKYO° Damage counter",
    author = "soft as HELL",
    description = "Shows detailed damage list on death/round end",
    version = "0.7.0",
    url = ""
};

new Handle:g_hRewardAssists, Handle:g_hAssistDamage, Handle:g_hAssistPoints, Handle:g_hAssistMode;

new bool:g_SeenReport[MAXPLAYERS+1];
new g_Class[MAXPLAYERS+1];

new g_PlayerHealth[MAXPLAYERS+1];
new g_PlayerAssist[MAXPLAYERS+1];

new g_DamageDealt[MAXPLAYERS+1][MAXPLAYERS+1];
new g_HitsMade[MAXPLAYERS+1][MAXPLAYERS+1];

new g_DamageTaken[MAXPLAYERS+1][MAXPLAYERS+1];
new g_HitsTaken[MAXPLAYERS+1][MAXPLAYERS+1];

char class_names[][] = {
	"Unassigned",
	"Recon",
	"Assault",
	"Support"
};

public OnPluginStart()
{
	g_hRewardAssists = CreateConVar("sm_ntdamage_assists", "0", "Enable/Disable rewarding of assists");
	g_hAssistMode 	= CreateConVar("sm_ntdamage_assistmode", "0", "Switches assist mode");
	g_hAssistDamage = CreateConVar("sm_ntdamage_damage", "45", "Damage required to trigger assist");
	g_hAssistPoints = CreateConVar("sm_ntdamage_points", "1", "Points given for each assist");

	HookEvent("game_round_start", Event_RoundStart, EventHookMode_Post);
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Post);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
}

public OnClientPutInServer(client)
{
	g_SeenReport[client] = false;
	g_PlayerAssist[client] = 0;
}

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client;
	
	for(client = 1; client <= MaxClients; client++)
	{
		// Shows damage report now if player didn't die
		if(IsValidClient(client) && GetClientTeam(client) > 1)
		{
			if(!g_SeenReport[client])
				DamageReport(client);
		}

		// Resets everything
		g_SeenReport[client] = false;
		g_PlayerHealth[client] = 100;
		g_Class[client] = CLASS_NONE;

		for(new victim = 1; victim <= MaxClients; victim++)
		{
			g_DamageDealt[client][victim] = 0;
			g_HitsMade[client][victim] = 0;

			g_DamageTaken[client][victim] = 0;
			g_HitsTaken[client][victim] = 0;
		}
	}	
}

public Action:Event_PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));

	new health = GetEventInt(event, "health"); // Only reports new health
	
	// Calculate damage
	new damage = g_PlayerHealth[victim] - health;
	
	// Update current health
	g_PlayerHealth[victim] = health;

	if(!IsValidClient(attacker) || (victim == attacker))
		return;

	if(g_Class[victim] == CLASS_NONE)
		g_Class[victim] = GetPlayerClass(victim);
	
	g_DamageDealt[attacker][victim] += damage;
	g_HitsMade[attacker][victim] += 1;

	g_DamageTaken[victim][attacker] += damage;
	g_HitsTaken[victim][attacker] += 1;
}

public Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));

	if(!IsValidClient(victim))
		return;

	DamageReport(victim);

	if(GetConVarInt(g_hRewardAssists) > 0)
		RewardAssists(victim, attacker, GetConVarInt(g_hAssistMode));
}

DamageReport(client)
{
	new totalDamageDealt, totalDamageTaken, totalHitsDealt, totalHitsTaken, victim, attacker;

	PrintToConsole(client, "------------------------------------------------");
	for(victim = 1; victim <= MaxClients; victim++)
	{
		if((g_DamageDealt[client][victim] > 0) && (g_HitsMade[client][victim] > 0))
		{
			if(!IsValidClient(victim))
				continue;

			PrintToConsole(client, "Damage dealt to %N [%s]: %i in %i hits", victim, class_names[g_Class[victim]], g_DamageDealt[client][victim], g_HitsMade[client][victim]);

			totalDamageDealt += g_DamageDealt[client][victim];
			totalHitsDealt   += g_HitsMade[client][victim];
		}
	}

	for(attacker = 1; attacker <= MaxClients; attacker++)
	{
		if(!IsValidClient(attacker))
			continue;

		if((g_DamageTaken[client][attacker] > 0) && (g_HitsTaken[client][attacker] > 0))
		{
			PrintToConsole(client, "Damage taken from %N [%s]: %i in %i hits", attacker, class_names[g_Class[attacker]], g_DamageTaken[client][attacker], g_HitsTaken[client][attacker]);

			totalDamageTaken += g_DamageTaken[client][attacker];
			totalHitsTaken	 += g_HitsTaken[client][attacker];
		}
	}

	PrintToConsole(client, "Total damage dealt: %i in %i hits", totalDamageDealt, totalHitsDealt);
	PrintToConsole(client, "Total damage received from players: %i in %i hits", totalDamageTaken, totalHitsTaken);
	PrintToConsole(client, "------------------------------------------------");

	g_SeenReport[client] = true;
}

RewardAssists(client, killer, mode)
{
	new damage, hits, attacker;

	new target_damage = GetConVarInt(g_hAssistDamage);
	new reward_points = GetConVarInt(g_hAssistPoints);

	for(attacker = 1; attacker <= MaxClients; attacker++)
	{
		if(attacker == killer)
			continue; // Ignore the killer

		if(!IsValidClient(attacker))
			continue;

		if(GetClientTeam(client) == GetClientTeam(attacker))
			continue; // Ignore team damage

		damage = g_DamageTaken[client][attacker];
		hits = g_HitsTaken[client][attacker];

		if((damage <= 0) || (hits <= 0))
			continue; //No damage or hits

		switch(mode)
		{
			case 0: // Gives out X points only when player assisted with X damage to dead player
			{
				if(damage < target_damage)
					continue; // Didn't do enough damage to get anything

				AddPlayerXP(attacker, reward_points);

				PrintToChat(attacker, "[NT°] You gained %i XP for doing %i damage to %N", reward_points, damage, client);
				PrintToConsole(attacker, "[NT°] You gained %i XP for doing %i damage to %N", reward_points, damage, client);

				LogKillAssist(attacker);
			}
			case 1: // Sums all assisted damage and gives out X points after X damage done
			{ 
				PrintToChat(attacker, "[NT°] You assisted killing %N by doing %i damage", client, damage);
				PrintToConsole(attacker, "[NT°] You assisted killing %N by doing %i damage", client, damage);

				// Add to total assist buffer
				g_PlayerAssist[attacker] += damage;

				// Check if points should be given to player
				if(g_PlayerAssist[attacker] >= target_damage)
				{
					g_PlayerAssist[attacker] -= target_damage;

					AddPlayerXP(attacker, reward_points);

					PrintToChat(attacker, "[NT°] You gained %i XP for assists", reward_points);
					PrintToConsole(attacker, "[NT°] You gained %i XP for assists", reward_points);

					LogKillAssist(attacker);
				}
			}
		}
	}
}

LogKillAssist(client)
{
	// Log kill_assist event
	new userID, String:steamID[64], String:team[18];
	
	userID = GetClientUserId(client);
	GetClientAuthId(client, AuthId_Steam2, steamID, 64);
	GetTeamName(GetClientTeam(client), team, sizeof(team));

	LogToGame("\"%N<%d><%s><%s>\" triggered \"kill_assist\"", client, userID, steamID, team);
}

AddPlayerXP(client, xp)
{
	SetPlayerXP(client, GetPlayerXP(client) + xp);
	UpdatePlayerRank(client);
}
