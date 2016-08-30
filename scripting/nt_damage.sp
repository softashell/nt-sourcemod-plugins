#include <sourcemod>
#include <sdktools>
#include <neotokyo>

#pragma semicolon 1
#pragma newdecls required

#define DEBUG 0

public Plugin myinfo =
{
    name = "NEOTOKYO° Damage counter",
    author = "soft as HELL",
    description = "Shows detailed damage list on death/round end",
    version = "0.7.3",
    url = ""
};

ConVar g_Cvar_AssistsEnabled, g_Cvar_AssistMode, g_Cvar_AssistDamage, g_Cvar_AssistPoints;

bool g_SeenReport[MAXPLAYERS+1];

int g_PlayerClass[MAXPLAYERS+1], g_PlayerHealth[MAXPLAYERS+1], g_PlayerAssist[MAXPLAYERS+1];

int g_DamageDealt[MAXPLAYERS+1][MAXPLAYERS+1];
int g_HitsMade[MAXPLAYERS+1][MAXPLAYERS+1];

int g_DamageTaken[MAXPLAYERS+1][MAXPLAYERS+1];
int g_HitsTaken[MAXPLAYERS+1][MAXPLAYERS+1];

char class_names[][] = {
	"-",
	"Recon",
	"Assault",
	"Support"
};

public void OnPluginStart()
{
	g_Cvar_AssistsEnabled = CreateConVar("sm_ntdamage_assists", "0", "Enable/Disable rewarding of assists", _, true, 0.0, true, 1.0);
	g_Cvar_AssistMode 	= CreateConVar("sm_ntdamage_assistmode", "0", "Switches assist mode", _, true, 0.0, true, 1.0);
	g_Cvar_AssistDamage = CreateConVar("sm_ntdamage_damage", "45", "Damage required to trigger assist or total damage needed to reward assist", _, true, 45.0);
	g_Cvar_AssistPoints = CreateConVar("sm_ntdamage_points", "1", "Points given for each assist", _, true, 1.0);

	AutoExecConfig(true);

	HookEvent("game_round_start", OnRoundStart, EventHookMode_Post);
	HookEvent("player_spawn", OnPlayerSpawn, EventHookMode_Post);
	HookEvent("player_hurt", OnPlayerHurt, EventHookMode_Post);
	HookEvent("player_death", OnPlayerDeath, EventHookMode_Post);
}

public void OnClientPutInServer(int client)
{
	g_SeenReport[client] = false;
	g_PlayerAssist[client] = 0;
	g_PlayerClass[client] = CLASS_NONE;
}

public Action OnRoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	int client, victim;

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
		g_PlayerClass[client] = CLASS_NONE;

		for(victim = 1; victim <= MaxClients; victim++)
		{
			g_DamageDealt[client][victim] = 0;
			g_HitsMade[client][victim] = 0;

			g_DamageTaken[client][victim] = 0;
			g_HitsTaken[client][victim] = 0;
		}
	}
}

public void OnPlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
	// Player class can be wrong at this point so we will have to wait until game deals with that
	CreateTimer(0.5, OnPlayerSpawnPost, GetEventInt(event, "userid"));
}

public Action OnPlayerSpawnPost(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);

	if(!IsValidClient(client) || GetClientTeam(client) <= TEAM_SPECTATOR)
		return;

	g_PlayerClass[client] = GetPlayerClass(client);
	g_PlayerHealth[client] = GetClientHealth(client);

	#if DEBUG > 0
	PrintToChatAll("[OnPlayerSpawnPost] Player %N (%d) spawned with class %d and %d health", client, client, g_PlayerClass[client], g_PlayerHealth[client]);
	#endif
}

public Action OnPlayerHurt(Handle event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));

	int health = GetEventInt(event, "health"); // Only reports new health

	// Calculate damage
	int damage = g_PlayerHealth[victim] - health;

	// Update current health
	g_PlayerHealth[victim] = health;

	if(!IsValidClient(attacker) || (victim == attacker))
		return;

	g_DamageDealt[attacker][victim] += damage;
	g_HitsMade[attacker][victim] += 1;

	g_DamageTaken[victim][attacker] += damage;
	g_HitsTaken[victim][attacker] += 1;
}

public void OnPlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));

	if(!IsValidClient(victim))
		return;

	DamageReport(victim);

	if(g_Cvar_AssistsEnabled.BoolValue)
		RewardAssists(victim, attacker, g_Cvar_AssistMode.IntValue);
}

void DamageReport(int client)
{
	int totalDamageDealt, totalDamageTaken, totalHitsDealt, totalHitsTaken, victim, attacker;

	PrintToConsole(client, "------------------------------------------------");
	for(victim = 1; victim <= MaxClients; victim++)
	{
		if(!IsValidClient(victim))
			continue;

		if((g_DamageDealt[client][victim] > 0) && (g_HitsMade[client][victim] > 0))
		{
			PrintToConsole(client, "Damage dealt to %N [%s]: %i in %i hits", victim, class_names[g_PlayerClass[victim]], g_DamageDealt[client][victim], g_HitsMade[client][victim]);

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
			PrintToConsole(client, "Damage taken from %N [%s]: %i in %i hits", attacker, class_names[g_PlayerClass[attacker]], g_DamageTaken[client][attacker], g_HitsTaken[client][attacker]);

			totalDamageTaken += g_DamageTaken[client][attacker];
			totalHitsTaken	 += g_HitsTaken[client][attacker];
		}
	}

	PrintToConsole(client, "Total damage dealt: %i in %i hits", totalDamageDealt, totalHitsDealt);
	PrintToConsole(client, "Total damage received from players: %i in %i hits", totalDamageTaken, totalHitsTaken);
	PrintToConsole(client, "------------------------------------------------");

	g_SeenReport[client] = true;
}

void RewardAssists(int client, int killer, int mode)
{
	int damage, hits, attacker;

	int target_damage = g_Cvar_AssistDamage.IntValue;
	int reward_points = g_Cvar_AssistPoints.IntValue;

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

void LogKillAssist(int client)
{
	// Log kill_assist event
	int userID;
	char steamID[64], team[18];

	userID = GetClientUserId(client);
	GetClientAuthId(client, AuthId_Steam2, steamID, 64);
	GetTeamName(GetClientTeam(client), team, sizeof(team));

	LogToGame("\"%N<%d><%s><%s>\" triggered \"kill_assist\"", client, userID, steamID, team);
}

void AddPlayerXP(int client, int xp)
{
	SetPlayerXP(client, GetPlayerXP(client) + xp);
	UpdatePlayerRank(client);
}
