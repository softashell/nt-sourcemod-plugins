#pragma semicolon 1

#include <sourcemod>

#define PLUGIN_VERSION	"1.0"

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

	RegConsoleCmd("joinstar", cmd_JoinStar);

	HookEvent("player_spawn", event_PlayerSpawn);
}

public Action:cmd_JoinStar(client, args)
{
	new String:arg[2], star;

	GetCmdArg(1, arg, sizeof(arg));

	star = StringToInt(arg);

	SetPlayerStar(client, star);
}

public event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (!IsValidClient(client))
		return;

	// Don't set star for spectators.
	if (GetClientTeam(client) == 0)
		return;

	// Don't assign a star if already in one.
	if ( GetPlayerStar(client) != 0)
		return;

	SetPlayerStar(client, 1);
}

bool:IsValidClient(client)
{
	if (client == 0)
		return false;
	
	if (!IsClientConnected(client))
		return false;
	
	if (IsFakeClient(client))
		return false;
	
	if (!IsClientInGame(client))
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