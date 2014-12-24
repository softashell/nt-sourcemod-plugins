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

public OnPluginStart()
{
	HookEvent("game_round_start", Event_RoundStart, EventHookMode_Post);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
}

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client;

	for(client = 1; client <= MaxClients; client++)
		g_MessageShownLast[client] = false;
}

public Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client, countTotal, countJin, countNsf, lastJin, lastNsf;

	for(client = 1; client <= MaxClients; client++)
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
		if(countTotal <=2)
			return;

		Duel(lastJin);
		Duel(lastNsf);
	}
	if(countJin > 1)
	{
		if(countNsf == 1)
		{
			LastManStanding(lastNsf);
		}
	}
	else if (countNsf > 1)
	{
		if(countJin == 1)
		{
			LastManStanding(lastJin);
		}
	}

}

LastManStanding(client)
{
	if(!IsPlayerAlive(client) || g_MessageShownLast[client])
		return;

	PrintCenterText(client, MESSAGE_LASTMAN);
	PrintToChat(client, MESSAGE_LASTMAN);

	g_MessageShownLast[client] = true;
}

Duel(client)
{
	PrintCenterText(client, MESSAGE_DUEL);
	PrintToChat(client, MESSAGE_DUEL);
}