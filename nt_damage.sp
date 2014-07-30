#pragma semicolon 1

#include <sourcemod>

#define PLUGIN_VERSION	"0.2"

public Plugin:myinfo =
{
    name = "NEOTOKYO° Damage counter",
    author = "Soft as HELL",
    description = "Shows detailed damage list on death/round end",
    version = PLUGIN_VERSION,
    url = ""
};

new g_PlayerHealth[MAXPLAYERS+1];

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

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client;
	for(client = 1; client <= MaxClients; client++)
	{
		if(IsValidClient(client) && GetClientTeam(client) > 1)
			DamageReport(client);
	}

	// Reset everything on new round
	for(client = 0; client <= MaxClients; client++)
	{
		g_PlayerHealth[client] = 100;

		for(new victim = 0; victim <= MaxClients; victim++)
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

	if(!IsValidClient(victim))
		return;

	DamageReport(victim);
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

	for(new attacker = 0; attacker <= MaxClients; attacker++)
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
	new Float:damageRatio;

	if (totalDamageTaken > 0)
		damageRatio = float(totalDamageDealt)/float(totalDamageTaken);
	else
		damageRatio = float(totalDamageDealt);

	PrintToConsole(client, "Total damage dealt: %i in %i hits", totalDamageDealt, totalHitsDealt);
	PrintToConsole(client, "Total damage received: %i in %i hits", totalDamageTaken, totalHitsTaken);
	PrintToConsole(client, "Damage ratio: %.01f", damageRatio);
	PrintToConsole(client, "================================================");
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