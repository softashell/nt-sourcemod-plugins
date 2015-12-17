#pragma semicolon 1

#include <sourcemod>

public Plugin:myinfo =
{
    name = "NEOTOKYO° Ghost capture test",
    author = "soft as HELL",
    description = "Gets the ghost capture forward",
    version = "0.1",
    url = ""
};

public OnGhostCapture(client)
{
	PrintToChatAll("Another plugin knows that %i just captured the ghost!", client);
}