#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <neotokyo>

public Plugin myinfo =
{
	name = "NEOTOKYO° Double cap prevention",
	author = "soft as HELL",
	description = "Removes ghost as soon as it's captured",
	version = "2.0.0",
	url = "https://github.com/softashell/nt-sourcemod-plugins"
};

new ghost = INVALID_ENT_REFERENCE;
int ghoster;
bool loaded_late;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	loaded_late = late;
	return APLRes_Success;
}

public void OnAllPluginsLoaded()
{
#define REQ_NAME 0
#define REQ_VERSION_CVAR 1
#define REQ_DOWNLOAD_URL 2
	char reqs[2][3][] = {
		{
			"NEOTOKYO° Ghost capture event",
			"sm_ntghostcap_version",
			"https://github.com/softashell/nt-sourcemod-plugins/blob/master/scripting/nt_ghostcap.sp"
		},
		{
			"NEOTOKYO OnRoundConcluded Event",
			"sm_onroundconcluded_version",
			"https://github.com/Rainyan/sourcemod-nt-onroundconcluded-event"
		},
	};
	for (int i = 0; i < sizeof(reqs); ++i)
	{
		if (FindConVar(reqs[i][REQ_VERSION_CVAR]) == null)
		{
			SetFailState("This plugin requires the \"%s\" plugin: %s",
				reqs[i][REQ_NAME], reqs[i][REQ_DOWNLOAD_URL]);
		}
	}
}

public void OnPluginStart()
{
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

public void OnRoundConcluded(int winner)
{
	UnEquipGhost(ghoster);
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
		// If secondary was aimed-in when switching to ghost,
		// forcibly setting it active will also re-enable the aim zoom,
		// so explicitly turn off any previous aim zoom before switching.
		SetEntProp(lastweapon, Prop_Send, "bAimed", false);
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
