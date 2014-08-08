#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION	"0.3"

public Plugin:myinfo =
{
    name = "NEOTOKYO° Damage counter",
    author = "Soft as HELL",
    description = "Shows detailed damage list on death/round end",
    version = PLUGIN_VERSION,
    url = ""
};

new g_PlayerHealth[MAXPLAYERS+1];
new g_PlayerAssist[MAXPLAYERS+1];

new g_DamageDealt[MAXPLAYERS+1][MAXPLAYERS+1];
new g_HitsMade[MAXPLAYERS+1][MAXPLAYERS+1];

new g_DamageTaken[MAXPLAYERS+1][MAXPLAYERS+1];
new g_HitsTaken[MAXPLAYERS+1][MAXPLAYERS+1];

public OnPluginStart()
{
	CreateConVar("sm_ntdamage_version", PLUGIN_VERSION, "NEOTOKYO° Damage counter", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	
	HookEvent("game_round_start", Event_RoundStart, EventHookMode_Post);
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Post);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);

}

public OnClientPutInServer(client)
{
	g_PlayerAssist[client] = 0;
}

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client;

	for(client = 1; client <= MaxClients; client++)
	{
		if(IsValidClient(client) && GetClientTeam(client) > 1)
			DamageReport(client);
	}

	// Reset everything on new round
	for(client = 1; client <= MaxClients; client++)
	{
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
	AvardAssists(victim, attacker);
}

public DamageReport(client)
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

public AvardAssists(client, killer)
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

stock CheckAssists(client)
{
	if(!IsValidClient(client))
		return;

	if(g_PlayerAssist[client] >= 100)
	{
		SetXP(client, GetXP(client) + 2);

		g_PlayerAssist[client] -= 100;

		PrintToChat(client, "[NT°] You gained 2 XP for assists");
		PrintToConsole(client, "[NT°] You gained 2 XP for assists");

		// Log kill_assist event
		new userID, String:steamID[64], String:team[18];
		
		userID = GetClientUserId(client);
		GetClientAuthString(client, steamID, 64);
		GetTeamName(GetClientTeam(client), team, sizeof(team));

		LogToGame("\"%N<%d><%s><%s>\" triggered \"kill_assist\"", client, userID, steamID, team);
	}
}

stock SetXP(client, xp)
{
	new rank;

	if(xp <= -1)
		rank = 0;
	else if(xp >= 0 && xp <= 3)
		rank = 1;
	else if(xp >= 4 && xp <= 9)
		rank = 2;
	else if(xp >= 10 && xp <= 19)
		rank = 3;
	else if(xp >= 20)
		rank = 4;

	SetEntProp(client, Prop_Data, "m_iFrags", xp);
	SetEntProp(client, Prop_Send, "m_iRank", rank);
}

stock GetXP(client)
{
	return GetClientFrags(client);
}

stock bool:IsValidClient(client)
{
	if ((client < 1) || (client > MaxClients))
		return false;
	
	if (!IsClientInGame(client))
		return false;
	
	if (IsFakeClient(client))
		return false;
	
	return true;
}