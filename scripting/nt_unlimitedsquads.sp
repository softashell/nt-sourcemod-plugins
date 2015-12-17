#pragma semicolon 1

#include <sourcemod>

#define PLUGIN_VERSION	"1.2"

new Handle:g_hSquadLock, Handle:g_hDefaultSquad;

public Plugin:myinfo =
{
    name = "NEOTOKYO° Unlimited squad size",
    author = "Agiel and soft as HELL",
    description = "Automatically assigns players to ALPHA and allows unlimited squad size",
    version = PLUGIN_VERSION,
    url = ""
};

public OnPluginStart()
{
	CreateConVar("sm_nt_unlimitesquad_version", PLUGIN_VERSION, "NEOTOKYO° Unlimited squad size version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);

	g_hSquadLock = CreateConVar("sm_nt_squadlock", "0", "Prevents players from changing their assigned squad");
	g_hDefaultSquad = CreateConVar("sm_nt_squadautojoin", "1", "Assigns squad which players will autojoin on first spawn", _, true, 1.0, true, 5.0);

	RegConsoleCmd("joinstar", cmd_JoinStar);

	HookEvent("game_round_start", Event_RoundStart);
	HookEvent("player_spawn", event_PlayerSpawn);
}

public Action:cmd_JoinStar(client, args)
{
	new String:arg[2], star;

	GetCmdArg(1, arg, sizeof(arg));

	star = StringToInt(arg);

	if(GetConVarInt(g_hSquadLock) > 0 && (GetPlayerStar(client) != 0))
	{
		PrintToConsole(client, "Squad change blocked");
		return Plugin_Handled;
	}

	SetPlayerStar(client, star);

	return Plugin_Handled;
}

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(GetConVarInt(g_hSquadLock) == 0)
		return;

	for(new client = 1; client <= MaxClients; client++)
	{
		if (!IsValidClient(client))
			continue;

		SetPlayerStar(client, GetConVarInt(g_hDefaultSquad));
	}
}

public event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (!IsValidClient(client))
		return;

	// Don't assign a star if already in one.
	if ( GetPlayerStar(client) != 0)
		return;

	SetPlayerStar(client, GetConVarInt(g_hDefaultSquad));
}

bool:IsValidClient(client)
{
	if (client == 0 || client > MaxClients)
		return false;
	
	if (!IsClientInGame(client))
		return false;

	if (GetClientTeam(client) == 0)
		return false;

	return true;
}

SetPlayerStar(client, star)
{
	if(star > 5)
		return;

	SetEntProp(client, Prop_Send, "m_iStar", star);
}

GetPlayerStar(client)
{
	return GetEntProp(client, Prop_Send, "m_iStar");
}