#pragma semicolon 1

#include <sourcemod>

public Plugin:myinfo =
{
    name = "NEOTOKYO° Ghost capture test",
    author = "soft as HELL",
    description = "Gets the ghost capture forward",
    version = "0.2",
    url = ""
};

public OnGhostSpawn(ghost)
{
	PrintToChatAll("Ghost spawned!");
}

public OnGhostCapture(client)
{
	PrintToChatAll("%N retrieved the ghost!", client);
}