#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <neotokyo>

public Plugin myinfo =
{
	name = "NEOTOKYO° Double cap prevention",
	author = "soft as HELL",
	description = "Removes ghost as soon as it's captured",
	version = "0.6.1",
	url = "https://github.com/softashell/nt-sourcemod-plugins"
};

new ghost = INVALID_ENT_REFERENCE;
int ghoster;
bool loaded_late;
Handle timer_roundState = INVALID_HANDLE;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	loaded_late = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	HookEvent("game_round_start", OnRoundStart);

	if (loaded_late)
	{
		char cls[32];
		for (int i = MaxClients + 1; i < GetMaxEntities(); ++i)
		{
			if (!IsValidEdict(i) || !GetEdictClassname(i, cls, sizeof(cls)))
			{
				continue;
			}
			if (StrEqual(cls, "weapon_ghost"))
			{
				ghost = EntIndexToEntRef(i);
				break;
			}
		}
	}
}

public void OnMapEnd()
{
	timer_roundState = INVALID_HANDLE;
}

public void OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (timer_roundState != INVALID_HANDLE)
	{
		CloseHandle(timer_roundState);
	}
	timer_roundState = CreateTimer(1.0, Timer_CheckGameState, _,
		TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public void OnGhostPickUp(int client)
{
	ghoster = client;
}

public void OnGhostDrop(int client)
{
	ghoster = 0;
}

public void OnGhostSpawn(int entity)
{
	// Save current ghost id for later use
	ghost = entity;
}

public void OnGhostCapture(int client)
{
	delete timer_roundState;
	UnEquipGhost(client);
	RemoveGhost();
}

void UnEquipGhost(int client)
{
	if (!IsValidClient(client) || !IsPlayerAlive(client))
	{
		return;
	}

	int ghost_index = EntRefToEntIndex(ghost);
	if (ghost_index == INVALID_ENT_REFERENCE)
	{
		return;
	}

	int activeweapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
	if(activeweapon != ghost_index)
	{
		return;
	}

	int lastweapon = GetEntPropEnt(client, Prop_Data, "m_hLastWeapon");
	if(!IsValidEdict(lastweapon))
	{
		return;
	}

	int owner = GetEntPropEnt(lastweapon, Prop_Data, "m_hOwnerEntity");
	// If the player dropped all of their weapons except the ghost,
	// their m_hLastWeapon will point to a gun that's not on them,
	// and trying to set it as m_hActiveWeapon will crash the server.
	// This can happen for knifeless players, ie. supports.
	if (client == owner)
	{
		SetEntPropEnt(client, Prop_Data, "m_hActiveWeapon", lastweapon);
	}
}

void RemoveGhost()
{
	if (ghost == INVALID_ENT_REFERENCE)
	{
		return;
	}

	if (AcceptEntityInput(ghost, "Kill"))
	{
		ghost = INVALID_ENT_REFERENCE;
	}
}

public Action Timer_CheckGameState(Handle timer)
{
#define GAMESTATE_WAITING_FOR_PLAYERS 1
#define GAMESTATE_ROUND_ACTIVE 2
#define GAMESTATE_ROUND_OVER 3
	if (GameRules_GetProp("m_iGameState") != GAMESTATE_ROUND_OVER)
	{
		return Plugin_Continue;
	}

	UnEquipGhost(ghoster);
	RemoveGhost();

	timer_roundState = INVALID_HANDLE;
	return Plugin_Stop;
}
