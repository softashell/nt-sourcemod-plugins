#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <neotokyo>

public Plugin:myinfo =
{
    name = "NEOTOKYO° Double cap prevention",
    author = "soft as HELL",
    description = "Removes ghost as soon as it's captured",
    version = "0.6.0",
    url = ""
};

int ghost = INVALID_ENT_REFERENCE;
int ghoster_userid;

public void OnPluginStart()
{
	if (!HookEventEx("game_round_end", OnGameRoundEnd))
	{
		SetFailState("Failed to hook game_round_end");
	}
}

public void OnGameRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	UnEquipGhost(GetClientOfUserId(ghoster_userid));
	RemoveGhost();
}

public OnGhostSpawn(entity)
{
	// Save current ghost id for later use
	ghost = entity;
}

public OnGhostCapture(client)
{
	// Might have to delay this for a bit, 0.5 seconds?
	UnEquipGhost(client);
	RemoveGhost();
}

public void OnGhostPickUp(int client)
{
	ghoster_userid = GetClientUserId(client);
}

public void OnGhostDrop(int client)
{
	ghoster_userid = 0;
}

void RemoveGhost()
{
	if (IsValidEdict(ghost))
	{
		AcceptEntityInput(ghost, "Kill");
	}
}

void UnEquipGhost(int client)
{
	if(!IsValidEdict(ghost))
	{
		return;
	}

	// Switch to last weapon if player is still alive and has ghost active
	if(IsValidClient(client) && IsPlayerAlive(client))
	{
		new activeweapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
		new ghost_index = EntRefToEntIndex(ghost);

		if(activeweapon == ghost_index)
		{
			new lastweapon = GetEntPropEnt(client, Prop_Data, "m_hLastWeapon");

			if(IsValidEdict(lastweapon))
			{
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
		}
	}
}
