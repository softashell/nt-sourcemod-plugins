#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <neotokyo>

public Plugin:myinfo =
{
    name = "NEOTOKYO° Double cap prevention",
    author = "soft as HELL",
    description = "Removes ghost as soon as it's captured",
    version = "0.4.0",
    url = ""
};

new ghost;

public OnGhostSpawn(entity)
{
	// Save current ghost id for later use
	ghost = entity;

	PrintToServer("Ghost %i spawned", ghost);
}

public OnGhostCapture(client)
{
	// Might have to delay this for a bit, 0.5 seconds?
	RemoveGhost(client);
}

RemoveGhost(client)
{
	if(!IsValidEdict(ghost))
	{
		return;
	}

	PrintToServer("Removing current ghost %i", ghost);

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

	// Delete ghost
	AcceptEntityInput(ghost, "Kill");
}
