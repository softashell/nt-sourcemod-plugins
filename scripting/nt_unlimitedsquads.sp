#include <sourcemod>
#include <neotokyo>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
    name = "NEOTOKYO° Unlimited squad size",
    author = "Agiel and soft as HELL",
    description = "Automatically assigns players to ALPHA and allows unlimited squad size",
    version = "1.3",
    url = ""
};

Handle g_hSquadLock, g_hDefaultSquad;

public void OnPluginStart()
{
    g_hSquadLock = CreateConVar("sm_nt_squadlock", "0", "Prevents players from changing their assigned squad");
    g_hDefaultSquad = CreateConVar("sm_nt_squadautojoin", "1", "Assigns squad which players will autojoin on first spawn", _, true, 1.0, true, 5.0);

    HookEvent("game_round_start", OnRoundStart);
    HookEvent("player_spawn", OnPlayerSpawn);

    RegConsoleCmd("joinstar", cmd_joinstar);
}

public void OnRoundStart(Handle event, const char[] name, bool dontBroadcast)
{
    if(GetConVarInt(g_hSquadLock) == 0)
        return;

    for(int client = 1; client <= MaxClients; client++)
    {
        if(!IsValidClient(client))
            continue;

        SetPlayerStar(client, GetConVarInt(g_hDefaultSquad));
    }
}

public void OnPlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(event, "userid"));

    if(!IsValidClient(client) || GetClientTeam(client) == TEAM_NONE)
        return;

    if(GetPlayerStar(client) != 0)
        return; // Don't assign a star if already in one.

    SetPlayerStar(client, GetConVarInt(g_hDefaultSquad));
}

public Action cmd_joinstar(int client, int args)
{
    char arg[2];
    GetCmdArg(1, arg, sizeof(arg));

    int star = StringToInt(arg);

    if(GetConVarInt(g_hSquadLock) > 0 && (GetPlayerStar(client) != 0))
        return Plugin_Handled; // Squad change blocked

    SetPlayerStar(client, star);

    return Plugin_Handled;
}
