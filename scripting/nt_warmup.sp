/**************************************************************
 NEOTOKYO° Warmup Deathmatch

 Plugin licensed under the GPLv3
 
 Coded by Agiel and soft as HELL.
**************************************************************/

#include <sourcemod>
#include <sdktools>
#include <neotokyo>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
    name = "NEOTOKYO° Warmup",
    author = "Agiel, soft as HELL",
    description = "Enables TDM after map change for a few minutes",
    version = "1.1",
    url = "https://github.com/softashell/nt-sourcemod-plugins"
};

ConVar cWarmupEnabled, cWarmupTimelimit, cWarmupProtection, cRestartCommand;

Handle hWarmupTimer;

bool bWarmupEnabled;

bool clientProtected[MAXPLAYERS+1];
int clientHP[MAXPLAYERS+1];

public void OnPluginStart()
{
	cWarmupEnabled = CreateConVar("sm_nt_warmup_enabled", "1", "Enables or Disables warmup after map change.", _, true, 0.0, true, 1.0);
	cWarmupTimelimit = CreateConVar("sm_nt_warmup_timelimit", "2.0", "Sets deathmatch timelimit.", _, true, 1.0, true, 60.0);
	cWarmupProtection = CreateConVar("sm_nt_warmup_spawnprotect", "2.0", "Length of time to protect spawned players", _, true, 0.0, true, 30.0);

	AutoExecConfig(true);

	cRestartCommand = FindConVar("neo_restart_this");

	cWarmupTimelimit.AddChangeHook(OnTimeLimitChanged);

	HookEvent("player_spawn", OnPlayerSpawn);
	HookEvent("player_hurt", OnPlayerHurt);
}

public void OnConfigsExecuted()
{
	bWarmupEnabled = false;

	if(cWarmupEnabled.BoolValue)
	{
		StartWarmup();

		bWarmupEnabled = true;
	}
}

void StartWarmup()
{
	float timeLimit = cWarmupTimelimit.FloatValue * 60;

	GameRules_SetPropFloat("m_fRoundTimeLeft", timeLimit);

	hWarmupTimer = CreateTimer(timeLimit, timer_EndWarmup, _, TIMER_FLAG_NO_MAPCHANGE);
}

public void OnTimeLimitChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if(bWarmupEnabled)
	{
		float timeLimit = cWarmupTimelimit.FloatValue * 60;

		GameRules_SetPropFloat("m_fRoundTimeLeft", timeLimit);

		if(hWarmupTimer != INVALID_HANDLE)
		{
			KillTimer(hWarmupTimer);

			hWarmupTimer = INVALID_HANDLE;
		}

		hWarmupTimer = CreateTimer(timeLimit, timer_EndWarmup, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public void OnPlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
	if(bWarmupEnabled)
	{
		int client = GetClientOfUserId(GetEventInt(event, "userid"));

		if(GetClientTeam(client) > 1)
		{
			CreateTimer(0.1, timer_GetHealth, client);
			
			//Enable Protection on the client
			clientProtected[client] = true;

			CreateTimer(cWarmupProtection.FloatValue, timer_PlayerProtect, client);
		}
	}
}

// Restore players health if they take damage while protected
public void OnPlayerHurt(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	if(clientProtected[client])
	{
		SetEntProp(client, Prop_Data, "m_iHealth", clientHP[client]);
		SetEntProp(client, Prop_Send, "m_iHealth", clientHP[client]);
	}
}

//Get the player's health after they spawn
public Action timer_GetHealth(Handle timer, int client)
{
	if(IsClientConnected(client) && IsClientInGame(client))
	{
		clientHP[client] = GetClientHealth(client);
	}
}

//Player protection expires
public Action timer_PlayerProtect(Handle timer, int client)
{
	//Disable protection on the Client
	clientProtected[client] = false;
}

public Action timer_EndWarmup(Handle timer)
{
	bWarmupEnabled = false;

	if(!ShouldRestartMatch())
		return;

	PrintToChatAll("Warmup ended!");

	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsValidClient(i)) // Maybe ignore spectators as well?
			continue;

		SetPlayerXP(i, 0);
		SetPlayerDeaths(i, 0);

		//ClientCommand(i, "classmenu");
	}

	CreateTimer(1.0, timer_RestartMatch);
}

public Action timer_RestartMatch(Handle timer)
{
	cRestartCommand.SetInt(1);
}

bool ShouldRestartMatch()
{
	int players;

	for(int client = 1; client <= MaxClients; client++)
	{
		if(!IsValidClient(client))
			continue;

		int team = GetClientTeam(client);

		if(team == TEAM_JINRAI || team == TEAM_NSF)
			players++;
	}

	if(players > 1)
		return true;

	return false;
}
