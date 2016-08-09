#pragma semicolon 1

#include <sourcemod>

public Plugin:myinfo =
{
    name = "NEOTOKYO° Ghost capture test",
    author = "soft as HELL",
    description = "Gets the ghost capture forward",
    version = "0.3",
    url = ""
};

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
