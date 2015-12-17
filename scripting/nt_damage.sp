#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <neotokyo>

#define PLUGIN_VERSION	"0.4"

public Plugin:myinfo =
{
    name = "NEOTOKYO° Damage counter",
    author = "Soft as HELL",
    description = "Shows detailed damage list on death/round end",
    version = PLUGIN_VERSION,
    url = ""
};

new Handle:g_hAwardAssists, Handle:g_hAwardDamage, Handle:g_hAwardPoints;

new bool:g_SeenReport[MAXPLAYERS+1];

new g_PlayerHealth[MAXPLAYERS+1];
new g_PlayerAssist[MAXPLAYERS+1];

new g_DamageDealt[MAXPLAYERS+1][MAXPLAYERS+1];
new g_HitsMade[MAXPLAYERS+1][MAXPLAYERS+1];

new g_DamageTaken[MAXPLAYERS+1][MAXPLAYERS+1];
new g_HitsTaken[MAXPLAYERS+1][MAXPLAYERS+1];

public OnPluginStart()
{
	CreateConVar("sm_ntdamage_version", PLUGIN_VERSION, "NEOTOKYO° Damage counter", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);

	g_hAwardAssists = CreateConVar("sm_ntdamage_assists", "0", "Enable/Disable rewarding of assists");
	g_hAwardDamage = CreateConVar("sm_ntdamage_damage", "100", "Total damage required to trigger assist");
	g_hAwardPoints = CreateConVar("sm_ntdamage_points", "2", "Points given for each assist");

	
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
		if(IsValidClient(client) && GetClientTeam(client) > 1)
		{
			if(!g_SeenReport[client])
				DamageReport(client);
		}
	}

	// Reset everything on new round
	for(client = 1; client <= MaxClients; client++)
	{
		g_SeenReport[client] = false;
		g_PlayerHealth[client] = 100;

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

	g_SeenReport[victim] = true;

	if(GetConVarInt(g_hAwardAssists) > 0)
		AwardAssists(victim, attacker);
}

DamageReport(client)
{
	new totalDamageDealt, totalDamageTaken, totalHitsDealt, totalHitsTaken;

	PrintToConsole(client, "================================================");
	for(new victim = 1; victim <= MaxClients; victim++)
	{
		if((g_DamageDealt[client][victim] > 0) && (g_HitsMade[client][victim] > 0))
		{
			if(!IsValidClient(victim))
				continue;

			PrintToConsole(client, "Damage dealt to %N: %i in %i hits", victim, g_DamageDealt[client][victim], g_HitsMade[client][victim]);

			totalDamageDealt += g_DamageDealt[client][victim];
			totalHitsDealt   += g_HitsMade[client][victim];
		}
	}

	for(new attacker = 1; attacker <= MaxClients; attacker++)
	{
		if(!IsValidClient(attacker))
			continue;

		if((g_DamageTaken[client][attacker] > 0) && (g_HitsTaken[client][attacker] > 0))
		{
			PrintToConsole(client, "Damage taken from %N: %i in %i hits", attacker, g_DamageTaken[client][attacker], g_HitsTaken[client][attacker]);

			totalDamageTaken += g_DamageTaken[client][attacker];
			totalHitsTaken	 += g_HitsTaken[client][attacker];
		}
	}

	PrintToConsole(client, "Total damage dealt: %i in %i hits", totalDamageDealt, totalHitsDealt);
	PrintToConsole(client, "Total damage received from players: %i in %i hits", totalDamageTaken, totalHitsTaken);
	PrintToConsole(client, "================================================");
}

AwardAssists(client, killer)
{
	new damage, hits;

	for(new attacker = 1; attacker <= MaxClients; attacker++)
	{
		if(attacker == killer)
			continue; // Don't give assist to player who killed client

		if(!IsValidClient(attacker))
			continue;

		if(GetClientTeam(client) == GetClientTeam(attacker))
			continue; // Ignore teammate damage

		damage = g_DamageTaken[client][attacker];
		hits = g_HitsTaken[client][attacker];

		if((damage <= 0) && (hits <= 0))
			continue; //No damage or hits

		g_PlayerAssist[attacker] += damage;

		PrintToChat(attacker, "[NT°] You assisted killing %N by doing %i damage", client, damage);
		PrintToConsole(attacker, "[NT°] You assisted killing %N by doing %i damage", client, damage);

		CheckAssists(attacker);
	}
}

CheckAssists(client)
{
	if(!IsValidClient(client))
		return;

	new target_damage = GetConVarInt(g_hAwardDamage);

	if(g_PlayerAssist[client] >= target_damage)
	{
		SetPlayerXP(client, GetPlayerXP(client) + GetConVarInt(g_hAwardPoints));

		g_PlayerAssist[client] -= target_damage;

		PrintToChat(client, "[NT°] You gained 2 XP for assists");
		PrintToConsole(client, "[NT°] You gained 2 XP for assists");

		// Log kill_assist event
		new userID, String:steamID[64], String:team[18];
		
		userID = GetClientUserId(client);
		GetClientAuthId(client,AuthId_Steam2, steamID, 64);
		GetTeamName(GetClientTeam(client), team, sizeof(team));

		LogToGame("\"%N<%d><%s><%s>\" triggered \"kill_assist\"", client, userID, steamID, team);
	}
}
