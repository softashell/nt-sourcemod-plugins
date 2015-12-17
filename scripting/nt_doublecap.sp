#pragma semicolon 1

#include <sourcemod>
#include <neotokyo>

public Plugin:myinfo =
{
    name = "NEOTOKYO° Double cap prevention",
    author = "soft as HELL",
    description = "Removes ghost as soon as it's captured",
    version = "0.1",
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
	PrintToServer("Removing current ghost %i", ghost);

	// Switch to last weapon if player is still alive
	if(IsValidClient(client) && IsPlayerAlive(client))
	{
		new weapon = GetEntPropEnt(client, Prop_Data, "m_hLastWeapon");
		SetEntPropEnt(client, Prop_Data, "m_hActiveWeapon", weapon);
	}

	// Delete ghost
	RemoveEdict(ghost);
}
