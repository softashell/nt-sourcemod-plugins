#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <neotokyo>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "0.2.1"
#define FIREMODE_DELAY 0.5
#define DEBUG 0

public Plugin myinfo =
{
	name = "NEOTOKYO° Tachi fix",
	author = "soft as HELL",
	description = "Make Tachi great again",
	version	= PLUGIN_VERSION,
	url	= "https://github.com/softashell/nt-sourcemod-plugins"

}

float g_fLastFireModeChange[NEO_MAXPLAYERS + 1];

public void OnPluginStart()
{
	CreateConVar("sm_nt_tachifix_version", PLUGIN_VERSION, "NEOTOKYO° Tachi fix version", FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY);

	HookEvent("game_round_start", OnRoundStart, EventHookMode_Post);
	HookEvent("player_spawn", OnPlayerSpawn, EventHookMode_Pre);
}

public void OnPlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
	#if DEBUG > 0
	PrintToServer("[nt_tachifix] OnPlayerSpawn %d", GetGameTime() - FIREMODE_DELAY);
	#endif

	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	g_fLastFireModeChange[client] = GetGameTime() - FIREMODE_DELAY;
}

public void OnRoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	#if DEBUG > 0
	PrintToServer("[nt_tachifix] OnRoundStart %d", GetGameTime() - FIREMODE_DELAY);
	#endif

	for(int client = 1; client <= NEO_MAXPLAYERS; client++)
	{
		g_fLastFireModeChange[client] = GetGameTime() - FIREMODE_DELAY;
	}
}

public Action OnPlayerRunCmd(int client, int &buttons)
{
	if(!IsPlayerAlive(client))
		return Plugin_Continue;

	#if DEBUG > 2
	PrintToServer("[nt_tachifix] %d m_bFreezePeriod %b %b", client, GameRules_GetProp("m_bFreezePeriod"), (GetGameTime() - g_fLastFireModeChange[client] >= FIREMODE_DELAY));
	#endif

	if((buttons & IN_ATTACK2) == IN_ATTACK2 && (GetGameTime() - g_fLastFireModeChange[client] >= FIREMODE_DELAY))
	{
		if(!GameRules_GetProp("m_bFreezePeriod"))
			return Plugin_Continue;

		int activeweapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
		if (!activeweapon)
		{
			#if DEBUG > 0
			PrintToServer("[nt_tachifix] No weapon???");
			#endif
			return Plugin_Continue;
		}

		char classname[32];
		if(GetEntityClassname(activeweapon, classname, 32) && StrEqual(classname, "weapon_tachi"))
		{
			#if DEBUG > 0
			PrintToServer("[nt_tachifix] %d change firemode", client, !GetEntProp(activeweapon, Prop_Send, "m_iFireMode"));
			#endif
			SetEntProp(activeweapon, Prop_Send, "m_iFireMode", !GetEntProp(activeweapon, Prop_Send, "m_iFireMode"));
			buttons &= ~IN_ATTACK2;
			g_fLastFireModeChange[client] = GetGameTime();
		}
		else
		{
			#if DEBUG > 0
			PrintToServer("[nt_tachifix] No tachi???");
			#endif
		}
	}

	return Plugin_Continue;
}