#include <sourcemod>
#include <neotokyo>
#include <sdkhooks>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "0.1.0"

public Plugin myinfo =
{
	name		= "NEOTOKYO° Ghost enemy beacons for everyone",
	author		= "soft as HELL",
	description = "Maybe useful?",
	version		= PLUGIN_VERSION,
	url			= "https://github.com/softashell/nt-sourcemod-plugins"


}

#define BEACON_TEXTURE "materials/vgui/hud/ctg/g_beacon_enemy.vmt"

int g_ghostIconEntity[NEO_MAXPLAYERS + 1];
int ghostEnt;

public void OnPluginStart()
{
	CreateConVar("sm_nt_specghost_version", PLUGIN_VERSION, "NEOTOKYO° Ghost enemy beacons for everyone", FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY);
}

public void OnMapStart()
{
	// TODO: Reuse?
	PrecacheModel(BEACON_TEXTURE);
}

public void OnGameFrame()
{
	if(!ghostEnt)
		return;

	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i) || !IsPlayerAlive(i))
			continue;

		if(!g_ghostIconEntity[i] || !IsValidEntity(g_ghostIconEntity[i]))
		{
			PrintToServer("Created beacon for %d", i);
			g_ghostIconEntity[i] = CreateGhostBeacon(i);
		}

		// TODO: Filter distance from ghost and check if ghost is enabled
		if(IsValidEntity(g_ghostIconEntity[i]))
		{
			// TODO: Don't update on every frame
			TeleportGhostBeacon(i);
		}
	}
}

public Action Hook_SetTransmitGhost(int entity, int client)
{
	if (client != GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity"))
	{
		// TODO: Filter teams/state of players
		return Plugin_Continue;
	}

	return Plugin_Handled;
}

int CreateGhostBeacon(int client)
{
	int ent = CreateEntityByName("env_sprite");

	SetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity", client);
	SetEntityModel(ent, BEACON_TEXTURE);
	DispatchKeyValue(ent, "rendercolor", "128 128 128");
	DispatchKeyValue(ent, "rendermode", "2");
	DispatchKeyValue(ent, "renderamt", "255");
	DispatchKeyValue(ent, "scale", "0.05");
	
	DispatchKeyValue(ent, "fademindist", "1");
	DispatchKeyValue(ent, "fademaxdist", "1");
	DispatchKeyValue(ent, "fadescale", "2.0");

	DispatchSpawn(ent);

	//SetEntityRenderMode(ent, RENDER_GLOW);
	SetEntityRenderMode(ent, RENDER_TRANSTEXTURE);
	//SetEntityRenderColor(ent, 0, 0, 0, 0);
	SetEntProp(ent, Prop_Data, "m_bWorldSpaceScale", 0);

	SetEdictFlags(ent, GetEdictFlags(ent) & (~FL_EDICT_ALWAYS));
	SDKHook(ent, SDKHook_SetTransmit, Hook_SetTransmitGhost);

	int entRef = EntIndexToEntRef(ent);

	// TODO: Hook player death to disable beacon

	return entRef;
}

public void OnGhostSpawn(int ghost)
{
	ghostEnt = ghost;
}

void TeleportGhostBeacon(int client)
{
	float pos[3];
	float ang[3];
	float norm[3];

	GetClientEyePosition(client, pos);
	GetClientEyeAngles(client, ang);
	GetAngleVectors(ang, norm, NULL_VECTOR, NULL_VECTOR);

	TeleportEntity(g_ghostIconEntity[client], pos, NULL_VECTOR, NULL_VECTOR );
}
