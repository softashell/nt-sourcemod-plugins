#pragma semicolon 1

#include <neotokyo>

public Plugin:myinfo =
{
	name = "NEOTOKYO° Input tweaks",
	author = "soft as HELL",
	description = "Tweaks some questionable inputs",
	version = "0.2.1",
	url = ""
}

bool g_bAimHeld[MAXPLAYERS+1];

public Action OnPlayerRunCmd(int client, int &buttons)
{
	if((buttons & IN_AIM) == IN_AIM)
	{
		if(g_bAimHeld[client])
		{
			buttons &= ~IN_AIM; // Release key so it zooms in
		}
		else
		{
			if((GetClientTeam(client) == TEAM_SPECTATOR) || !IsPlayerAlive(client))
			{
				FakeClientCommand(client, "spec_prev");
			}

			g_bAimHeld[client] = true;
		}
	}
	else
	{
		g_bAimHeld[client] = false;
	}

	if((buttons & IN_THERMOPTIC) == IN_THERMOPTIC)
	{
		if((GetClientTeam(client) == TEAM_SPECTATOR) || !IsPlayerAlive(client))
		{
			buttons &= ~IN_THERMOPTIC; // Release key to block camo
		}
	}

	return Plugin_Continue;
}