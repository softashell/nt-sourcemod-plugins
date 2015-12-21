#pragma semicolon 1

#include <neotokyo>

public Plugin:myinfo = 
{
	name = "NEOTOKYO° Instant aim",
	author = "soft as HELL",
	description = "Makes aim work as soon as it's pressed",
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
			return;
		}

		g_bAimHeld[client] = true;
	}
	else 
	{
		g_bAimHeld[client] = false;
	}
}