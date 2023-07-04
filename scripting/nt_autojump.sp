#include <sourcemod>

#pragma semicolon 1

public Plugin:myinfo =
{
	name = "NEOTOKYO° Jump Queuing",
	author = "soft as HELL",
	description = "Jump as soon as you land",
	version = "0.1.1",
	url = ""
};

bool g_bJumpHeld[MAXPLAYERS+1];
bool g_bJumped[MAXPLAYERS+1];

public Action OnPlayerRunCmd(int client, int &buttons)
{
	if(!IsPlayerAlive(client))
	{
		return Plugin_Continue; // Nothing to do with spooky skeletons
	}

	// Pressing jump
	if(buttons & IN_JUMP) {
		if(g_bJumpHeld[client])
		{
			if(GetEntityMoveType(client) & MOVETYPE_LADDER)
			{
				return Plugin_Continue; // Do nothing on ladder
			}

			if(GetEntityFlags(client) & FL_ONGROUND)
			{
				g_bJumped[client] = true;
			}
			else if(!g_bJumped[client])
			{
				// Player is in air, and hasn't hit ground once since starting
				buttons &= ~IN_JUMP; // Release jump!
			}
		}
		else
		{
			// First time pressing jump, reset jump state
			g_bJumpHeld[client] = true;

			if(GetEntityFlags(client) & FL_ONGROUND)
			{
				// Holding jump from ground
				g_bJumped[client] = true;
			}
			else
			{
				// Holding jump from midair
				g_bJumped[client] = false;
			}
		}
	}
	else
	{
		// Released jump
		g_bJumpHeld[client] = false;
		g_bJumped[client] = false;
	}
	return Plugin_Continue;
}
