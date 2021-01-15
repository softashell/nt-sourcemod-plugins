#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <neotokyo>

#pragma semicolon 1
#pragma newdecls required

#define DEBUG 0
#define PRECISE 1
#define MAXCAPZONES 4
#define INACCURACY 0.35

#define PLUGIN_VERSION	"1.8.0"

public Plugin myinfo =
{
	name = "NEOTOKYO° Ghost capture event",
	author = "soft as HELL",
	description = "Logs ghost capture event",
	version = PLUGIN_VERSION,
	url = "https://github.com/softashell/nt-sourcemod-plugins"
};

Handle g_hRoundTime, g_hForwardCapture, g_hForwardSpawn, g_hForwardPickUp, g_hForwardDrop;

// Globals
int ghost, totalCapzones;
bool roundReset = true;
float fStartRoundTime;

// Capture point data
int capzones[MAXCAPZONES+1], capTeam[MAXCAPZONES+1], capRadius[MAXCAPZONES+1];
float capzoneVector[MAXCAPZONES+1][3];
bool capzoneDataUpdated[MAXCAPZONES+1];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	// These names must be guaranteed globally unique.
	// Also note that renaming them may break other plugins relying on these native call.
	CreateNative("GhostEvents_RemoveCapzone", Native_RemoveCapzone);
	CreateNative("GhostEvents_UpdateCapzone", Native_UpdateCapzone);
	return APLRes_Success;
}

public void OnPluginStart()
{
	CreateConVar("sm_ntghostcap_version", PLUGIN_VERSION, "NEOTOKYO° Ghost cap event version", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);

	g_hRoundTime = FindConVar("neo_round_timelimit");

	g_hForwardCapture = CreateGlobalForward("OnGhostCapture", ET_Event, Param_Cell);
	g_hForwardSpawn = CreateGlobalForward("OnGhostSpawn", ET_Event, Param_Cell);
	g_hForwardPickUp = CreateGlobalForward("OnGhostPickUp", ET_Event, Param_Cell);
	g_hForwardDrop = CreateGlobalForward("OnGhostDrop", ET_Event, Param_Cell);

	HookEvent("game_round_start", OnRoundStart, EventHookMode_Post);

	// Hook again if plugin is restarted
	for(int client = 1; client <= MaxClients; client++)
	{
		if(IsValidClient(client))
		{
			OnClientPutInServer(client);
		}
	}

	#if PRECISE < 1
	CreateTimer(0.25, CheckGhostPosition, _, TIMER_REPEAT);
	#endif
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_WeaponEquipPost, OnWeaponEquip);
	SDKHook(client, SDKHook_WeaponDropPost, OnWeaponDrop);
}

public void OnWeaponEquip(int client, int weapon)
{
	if(!IsValidEdict(weapon) || !IsPlayerAlive(client))
		return;

	char classname[32];
	if(!GetEntityClassname(weapon, classname, sizeof(classname)))
		return; // Can't get class name

	if(StrEqual(classname, "weapon_ghost"))
	{
		PushOnGhostPickUp(client);
	}
}

public void OnWeaponDrop(int client, int weapon)
{
	if(!IsValidEdict(weapon) || !IsPlayerAlive(client))
		return;

	char classname[32];
	if(!GetEntityClassname(weapon, classname, sizeof(classname)))
		return;

	if(StrEqual(classname, "weapon_ghost"))
	{
		PushOnGhostDrop(client);
	}
}

public void OnMapEnd()
{
	#if DEBUG > 0
	PrintToServer("[nt_ghostcap] Map ended, resetting everything and marking zones for update");
	#endif

	totalCapzones = 0;
	roundReset = true;

	for(int i = 0; i <= MAXCAPZONES; i++)
	{
		capzones[i] = 0;
		capzoneDataUpdated[i] = false;
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(StrEqual(classname, "weapon_ghost"))
	{
		ghost = EntIndexToEntRef(entity);

		PushOnGhostSpawn(ghost);
	}
	else if(StrEqual(classname, "neo_ghost_retrieval_point"))
	{
		totalCapzones++;

		if(totalCapzones > MAXCAPZONES)
		{
			ThrowError("Too many capture points in map! Consider changing MAXCAPZONES. (#%i)", totalCapzones);
		}

		capzones[totalCapzones] = EntIndexToEntRef(entity);
	}
}

public void OnRoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	fStartRoundTime = GetGameTime();

	if(!totalCapzones)
		return; // No cap zones

	#if DEBUG > 0
	PrintToServer("[nt_ghostcap] Updating capture point data at round start");
	#endif

	for(int capzone = 0; capzone <= totalCapzones; capzone++)
	{
		if(capzones[capzone] == 0 || !IsValidEdict(capzones[capzone])) // Worldspawn
			continue;

		if(!capzoneDataUpdated[capzone]) // Gets called on first round after a map change
			capzoneDataUpdated[capzone] = UpdateCapzoneData(capzone);

		// Update current owning team
		capTeam[capzone] = GetEntProp(capzones[capzone], Prop_Send, "m_OwningTeamNumber");

		#if DEBUG > 0
		char teamname[10];
		GetTeamName(capTeam[capzone], teamname, 10);

		PrintToServer("[nt_ghostcap] #%d %s - Radius: %d, Location: {%.0f, %.0f, %.0f}", capzone, teamname, capRadius[capzone], capzoneVector[capzone][0], capzoneVector[capzone][1], capzoneVector[capzone][2]);
		#endif
	}

	// Allow logging of ghost capture again
	roundReset = true;
}

#if PRECISE > 0
public void OnGameFrame()
{
	CheckGhostPosition(INVALID_HANDLE);
}
#endif

public Action CheckGhostPosition(Handle timer)
{
	if(!totalCapzones || !IsValidEdict(ghost))
		return; // No capzones or no ghost

	if(HasRoundEnded())
		return;

	int capzone, carrier, carrierTeamID;
	float ghostVector[3], distance;

	carrier = GetEntPropEnt(ghost, Prop_Data, "m_hOwnerEntity");

	if(!IsValidClient(carrier) || !IsPlayerAlive(carrier))
		return;

	carrierTeamID = GetClientTeam(carrier);
	GetClientAbsOrigin(carrier, ghostVector);

	for(capzone = 0; capzone <= totalCapzones; capzone++)
	{
		if(capzones[capzone] == 0 || !IsValidEdict(capzones[capzone]) || (capRadius[capzone] <= 0))
			continue; // Doesn't exist or no radius

		distance = GetVectorDistance(ghostVector, capzoneVector[capzone]);

		if(distance > capRadius[capzone])
			continue; // Too far away

		if(carrierTeamID != capTeam[capzone])
		{
			PrintCenterText(carrier, "- WRONG RETRIEVAL ZONE -");

 			// Wrong capture point with no chance of standing on correct one as well
			break;
		}
		else if(IsAnyEnemyStillAlive(carrierTeamID))
		{
			roundReset = false; // Won't spam any more events unless value is set to true

			PushOnGhostCapture(carrier);

			LogGhostCapture(carrier, carrierTeamID);

			 //We're done here, no point in continuing loop
			break;
		}
	}
}

bool IsAnyEnemyStillAlive(int team)
{
	int enemyTeam, i;

	for(i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i) || !IsPlayerAlive(i))
			continue;

		enemyTeam = GetClientTeam(i);

		if((team == TEAM_JINRAI && enemyTeam == TEAM_NSF) || (team == TEAM_NSF && enemyTeam == TEAM_JINRAI))
			return true;
	}

	return false;
}

bool UpdateCapzoneData(int capzone)
{
	int entity = capzones[capzone];

	if(!IsValidEdict(entity))
		return false;

	#if DEBUG > 0
	PrintToServer("[nt_ghostcap] Updating outdated information for capture point #%d!", capzone);
	#endif

	// Update radius
	capRadius[capzone]  = GetEntProp(entity, Prop_Send, "m_Radius");

	// Update location
	GetEntPropVector(entity, Prop_Data, "m_vecOrigin", capzoneVector[capzone]);

	return true;
}

bool HasRoundEnded()
{
	if(!roundReset)
		return true;

	float maxRoundTime = GetConVarFloat(g_hRoundTime) * 60;
	float currentRoundTime = GetGameTime() - fStartRoundTime;

	if(currentRoundTime > maxRoundTime + INACCURACY)
		return true; // This round has already ended, don't trigger caps until next round starts

	return false;
}

void LogGhostCapture(int client, int team)
{
	char carrierSteamID[64], carrierTeam[18];
	int carrierUserID = GetClientUserId(client);

	GetClientAuthId(client, AuthId_Steam2, carrierSteamID, 64);
	GetTeamName(team, carrierTeam, sizeof(carrierTeam));

	LogToGame("Team \"%s\" triggered \"ghost_capture_team\"", carrierTeam);
	LogToGame("\"%N<%d><%s><%s>\" triggered \"ghost_capture\"", client, carrierUserID, carrierSteamID, carrierTeam);
}

void PushOnGhostCapture(int client)
{
	#if DEBUG > 0
	PrintToServer("[nt_ghostcap] Ghost captured by %N (%d)! Pushing OnGhostCapture forward", client, client);
	#endif

	Call_StartForward(g_hForwardCapture);
	Call_PushCell(client);
	Call_Finish();
}

void PushOnGhostSpawn(int entity)
{
	#if DEBUG > 0
	PrintToServer("[nt_ghostcap] Ghost spawned! Pushing OnGhostSpawn forward");
	#endif

	Call_StartForward(g_hForwardSpawn);
	Call_PushCell(entity);
	Call_Finish();
}

void PushOnGhostPickUp(int client)
{
	#if DEBUG > 0
	PrintToServer("[nt_ghostcap] Ghost picked up by %N (%d)! Pushing OnGhostPickedUp forward", client, client);
	#endif

	Call_StartForward(g_hForwardPickUp);
	Call_PushCell(client);
	Call_Finish();
}
void PushOnGhostDrop(int client)
{
	#if DEBUG > 0
	PrintToServer("[nt_ghostcap] Ghost dropped by %N (%d)! Pushing OnGhostDropped forward", client, client);
	#endif

	Call_StartForward(g_hForwardDrop);
	Call_PushCell(client);
	Call_Finish();
}

// Purpose: Removes a capzone from this plugin's tracking entirely, as if it was removed.
// This can be useful to call before dynamically deleting a capzone, to avoid plugin conflicts.
//
//	Input: a valid capzone entity index
//	Output:
//		- 1 if capzone was recognized and removed from this plugin's tracking
//		- 0 if the capzone was not found
// Note that either return value may not be an error, but merely a side effect of the plugin load order.
public int Native_RemoveCapzone(Handle plugin, int numParams)
{
	int capzone_entity = GetNativeCell(1);

	for(int i = 0; i <= totalCapzones; i++)
	{
		if (capzones[i] == 0)
			continue;

		int ent = EntRefToEntIndex(capzones[i]);
		if (ent == INVALID_ENT_REFERENCE)
			continue;

		if (ent != capzone_entity)
			continue;

		capzones[i] = 0;
		capzoneDataUpdated[i] = false;
		return 1;
	}
	return 0;
}

// Purpose: Updates capzone positions info, etc, for a capzone tracked by this plugin.
// This can be useful after dynamically moving a capzone to a different position or changing its radius.
//
//	Input: a valid capzone entity index
//	Output:
//		- 1 if capzone was recognized, and it was also successfully updated in this plugin's tracking
//		- 0 if the capzone was not found
// Note that either return value may not be an error, but merely a side effect of the plugin load order.
public int Native_UpdateCapzone(Handle plugin, int numParams)
{
	int capzone_entity = GetNativeCell(1);

	for(int capzone = 0; capzone <= totalCapzones; capzone++)
	{
		if (capzones[capzone] == 0)
			continue;

		int ent = EntRefToEntIndex(capzones[capzone]);
		if (ent == INVALID_ENT_REFERENCE)
			continue;

		if (ent != capzone_entity)
			continue;

		capzoneDataUpdated[capzone] = UpdateCapzoneData(capzone);
		return capzoneDataUpdated[capzone] ? 1 : 0;
	}
	return 0;
}
