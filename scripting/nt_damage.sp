#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <neotokyo>

#define PLUGIN_VERSION	"0.5.1"

public Plugin:myinfo =
{
    name = "NEOTOKYO° Damage counter",
    author = "soft as HELL",
    description = "Shows detailed damage list on death/round end",
    version = PLUGIN_VERSION,
    url = ""
};

new Handle:g_hRewardAssists, Handle:g_hAssistDamage, Handle:g_hAssistPoints;

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

	g_hRewardAssists = CreateConVar("sm_ntdamage_assists", "0", "Enable/Disable rewarding of assists");
	g_hAssistDamage = CreateConVar("sm_ntdamage_damage", "100", "Total damage required to trigger assist");
	g_hAssistPoints = CreateConVar("sm_ntdamage_points", "2", "Points given for each assist");

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

	if(GetConVarInt(g_hRewardAssists) > 0)
		RewardAssists(victim, attacker);
}

DamageReport(client)
{
	new totalDamageDealt, totalDamageTaken, totalHitsDealt, totalHitsTaken, victim, attacker;

	PrintToConsole(client, "================================================");
	for(victim = 1; victim <= MaxClients; victim++)
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

	for(attacker = 1; attacker <= MaxClients; attacker++)
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

RewardAssists(client, killer)
{
	new damage, hits, attacker;

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

		PrintToChat(attacker, "[NT°] You assisted killing %N by doing %i damage", client, damage);
		PrintToConsole(attacker, "[NT°] You assisted killing %N by doing %i damage", client, damage);

		g_PlayerAssist[attacker] += damage;

		CheckAssists(attacker);
	}
}

CheckAssists(client)
{
	if(!IsValidClient(client))
		return;

	new target_damage = GetConVarInt(g_hAssistDamage);
	new reward_points = GetConVarInt(g_hAssistPoints);

	if(g_PlayerAssist[client] >= target_damage)
	{
		SetPlayerXP(client, GetPlayerXP(client) + reward_points);

		g_PlayerAssist[client] -= target_damage;

		PrintToChat(client, "[NT°] You gained %i XP for assists", reward_points);
		PrintToConsole(client, "[NT°] You gained %i XP for assists", reward_points);

		LogKillAssist(client);
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
