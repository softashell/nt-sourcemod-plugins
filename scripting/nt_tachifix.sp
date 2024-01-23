#include <sourcemod>
#include <neotokyo>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "0.1.0"

public Plugin myinfo =
{
	name		= "NEOTOKYO° Tachi fix",
	author		= "soft as HELL",
	description = "Make Tachi great again",
	version		= PLUGIN_VERSION,
	url			= ""

}

bool  g_bAttack2Held[NEO_MAXPLAYERS + 1];
float g_fLastFireModeChange[NEO_MAXPLAYERS + 1];

public void OnPluginStart()
{
	CreateConVar("sm_nt_tachifix_version", PLUGIN_VERSION, "NEOTOKYO° Tachi fix version", FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY);
}

public Action OnPlayerRunCmd(int client, int &buttons)
{
	if(!IsPlayerAlive(client))
		return Plugin_Continue;

	if((buttons & IN_ATTACK2) == IN_ATTACK2 && !g_bAttack2Held[client])
	{
		if(!GameRules_GetProp("m_bFreezePeriod"))
			return Plugin_Continue;

		if(GetGameTime() - g_fLastFireModeChange[client] < 0.5)
			return Plugin_Continue;

		g_bAttack2Held[client] = true;

		int activeweapon	   = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
		if (!activeweapon)
		{
			return Plugin_Continue;
		}

		char classname[32];
		if(GetEntityClassname(activeweapon, classname, 32) && StrEqual(classname, "weapon_tachi"))
		{
			SetEntProp(activeweapon, Prop_Send, "m_iFireMode", !GetEntProp(activeweapon, Prop_Send, "m_iFireMode"));
			buttons &= ~IN_ATTACK2;
			g_fLastFireModeChange[client] = GetGameTime();
		}
	}
	else
	{
		g_bAttack2Held[client] = false;
	}

	return Plugin_Continue;
}