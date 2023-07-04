#pragma semicolon 1

#include <sourcemod>
#include <neotokyo>

public Plugin:myinfo =
{
    name = "NEOTOKYO° Player count events",
    author = "soft as HELL",
    description = "Provides notifications for certain events",
    version = "1.0",
    url = "https://github.com/softashell/nt-sourcemod-plugins"
};

#define MESSAGE_LASTMAN "You're the last man standing!"
#define MESSAGE_DUEL 	"You're dueling against enemy last player, don't drag this out!"

new bool:g_MessageShownLast[MAXPLAYERS];
new Handle:hPlayerCounter;

public OnPluginStart()
{
	HookEvent("game_round_start", Event_RoundStart, EventHookMode_Post);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Post);
}

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client;

	for(client = 1; client <= MaxClients; client++)
		g_MessageShownLast[client] = false;

	if(hPlayerCounter != INVALID_HANDLE)
		KillTimer(hPlayerCounter);

	hPlayerCounter = INVALID_HANDLE;
}

public Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(hPlayerCounter == INVALID_HANDLE)
		hPlayerCounter = CreateTimer(1.0, CountPlayers);
}

public Action CountPlayers(Handle timer)
{
	new countTotal, countJin, countNsf, lastJin, lastNsf;

	hPlayerCounter = INVALID_HANDLE;

	for(int client = 1; client <= MaxClients; client++)
	{
		if(!IsValidClient(client))
			continue;

		if(!IsPlayerAlive(client))
		{
			countTotal++;
			continue;
		}

		switch(GetClientTeam(client))
		{
			case TEAM_JINRAI:
			{
				countTotal++;
				countJin++;

				lastJin = client;
			}
			case TEAM_NSF:
			{
				countTotal++;
				countNsf++;

				lastNsf = client;
			}
		}
	}

	if(countJin == 1 && countNsf == 1)
	{
		if(countTotal <= 2)
			return Plugin_Stop;

		CreateTimer(3.0, LastManStanding, GetClientUserId(lastNsf));
		CreateTimer(3.0, LastManStanding, GetClientUserId(lastJin));
		return Plugin_Stop;
#if(0)
		//Duel(lastJin);
		//Duel(lastNsf);
#endif
	}
	else if(countJin >= 2)
	{
		if(countNsf == 1)
		{
			CreateTimer(3.0, LastManStanding, GetClientUserId(lastNsf));
		}
	}
	else if (countNsf >= 2)
	{
		if(countJin == 1)
		{
			CreateTimer(3.0, LastManStanding, GetClientUserId(lastJin));
		}
	}

	return Plugin_Stop;
}

public Action LastManStanding(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);

	if(client == 0 || !IsPlayerAlive(client) || g_MessageShownLast[client])
		return Plugin_Stop;

	PrintToChat(client, MESSAGE_LASTMAN);

	g_MessageShownLast[client] = true;

	return Plugin_Stop;
}

public void Event_PlayerDisconnect(Handle event, const char[] name, bool dontBroadcast)
{
	if(hPlayerCounter == INVALID_HANDLE)
		hPlayerCounter = CreateTimer(0.1, CountPlayers);

	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	g_MessageShownLast[client] = false;
}

#if(0)
void Duel(client)
{
	PrintToChat(client, MESSAGE_DUEL);
}
#endif