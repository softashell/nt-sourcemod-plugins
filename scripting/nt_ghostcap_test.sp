#pragma semicolon 1

#include <sourcemod>

#include <nt_ghostcap_natives>

public Plugin:myinfo =
{
    name = "NEOTOKYO° Ghost capture test",
    author = "soft as HELL",
    description = "Gets the ghost capture forward",
    version = "0.4",
    url = "https://github.com/softashell/nt-sourcemod-plugins"
};

public void OnAllPluginsLoaded()
{
	// Picking an entity index that is guaranteed to never match an actual tracked value.
	int fictional_capzone_entity_index = GetMaxEntities() + 1;

	int native_remove_res = GhostEvents_RemoveCapzone(fictional_capzone_entity_index);
	int native_update_res = GhostEvents_UpdateCapzone(fictional_capzone_entity_index);

	PrintToServer("Native return values: %d, %d", native_remove_res, native_update_res);
}

public OnGhostSpawn(ghost)
{
	PrintToChatAll("Ghost spawned!");
}

public OnGhostCapture(client)
{
	PrintToChatAll("%N (%d) retrieved the ghost!", client, client);
}

public OnGhostPickUp(client)
{
  PrintToChatAll("%N (%d) picked up the ghost!", client, client);
}

public OnGhostDrop(client)
{
  PrintToChatAll("%N (%d) dropped the ghost!", client, client);
}
