#pragma semicolon 1

#include <neotokyo>

public Plugin:myinfo = 
{
	name = "NEOTOKYO° Input tweaks",
	author = "soft as HELL",
	description = "Tweaks some questionable inputs",
	version = "0.1",
	url = ""
}

new bool:g_bAimHeld[MAXPLAYERS+1];

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
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
}