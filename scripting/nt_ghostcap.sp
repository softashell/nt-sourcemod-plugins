#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <neotokyo>

#pragma semicolon 1
#pragma newdecls required

#define DEBUG 0
#define MAXCAPZONES 6
#define INACCURACY 0.35

#define PLUGIN_VERSION	"1.5.9"

public Plugin myinfo =
{
	name = "NEOTOKYO° Ghost capture event",
	author = "soft as HELL",
	description = "Logs ghost capture event",
	version = PLUGIN_VERSION,
	url = ""
};

Handle g_hRoundTime, g_hForwardCapture, g_hForwardSpawn, g_hForwardPickedUp, g_hForwardDropped;

// Globals
int ghost, totalCapzones, lastCarrier;
bool roundReset = true;
float fStartRoundTime;

// Capture point data
int capzones[MAXCAPZONES+1], capTeam[MAXCAPZONES+1], capRadius[MAXCAPZONES+1];
float capzoneVector[MAXCAPZONES+1][3];
bool capzoneDataUpdated[MAXCAPZONES+1];
bool g_bGhostIsHeld;

public void OnPluginStart()
{
	CreateConVar("sm_ntghostcap_version", PLUGIN_VERSION, "NEOTOKYO° Ghost cap event version", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);

	g_hRoundTime = FindConVar("neo_round_timelimit");

	g_hForwardCapture = CreateGlobalForward("OnGhostCapture", ET_Event, Param_Cell);
	g_hForwardSpawn = CreateGlobalForward("OnGhostSpawn", ET_Event, Param_Cell);
	g_hForwardPickedUp = CreateGlobalForward("OnGhostPickedUp", ET_Event, Param_Cell);
	g_hForwardDropped = CreateGlobalForward("OnGhostDropped", ET_Event, Param_Cell);

	HookEvent("game_round_start", OnRoundStart, EventHookMode_Post);

	CreateTimer(0.25, CheckGhostPosition, _, TIMER_REPEAT);
}

public void OnMapEnd()
{
	#if DEBUG > 0
	PrintToServer("[nt_ghostcap] Map ended, resetting everything and marking zones for update");
	#endif

	g_bGhostIsHeld = false;
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
	g_bGhostIsHeld = false;
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
	{
		g_bGhostIsHeld = false;
		UpdateGhostPickedUpStatus();
		return;
	}
	else
	{
		lastCarrier = carrier;
		g_bGhostIsHeld = true;
		UpdateGhostPickedUpStatus();
	}
	
	carrierTeamID = GetClientTeam(carrier);
	GetClientAbsOrigin(carrier, ghostVector);

	for(capzone = 0; capzone <= totalCapzones; capzone++)
	{
		if(!IsValidEdict(capzones[capzone]) || (capRadius[capzone] <= 0))
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


void UpdateGhostPickedUpStatus()
{
	static int icounter;

	if(g_bGhostIsHeld)
	{
		if(icounter <= -1)
			icounter += 2;
		else
			icounter += 1;
	}
	else if(!g_bGhostIsHeld)
	{
		if(icounter >= 1)
			icounter -= 2;
		else
			icounter -= 1;
	}
	
	if(icounter > 2)
		icounter -= 1;
	if(icounter < -2)
		icounter += 1;
	

	if(icounter == 1)
	{
		PushOnGhostPickup(lastCarrier);
	}
	else if(icounter == -1)
	{		
		PushOnGhostDropped(lastCarrier);
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
	PrintToServer("[nt_ghostcap] Ghost captured by (%d)! Pushing OnGhostCapture forward", client);
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

void PushOnGhostPickup(int client)
{
	if(client < 1 || client > MaxClients)
		return;
	
	#if DEBUG > 0
	PrintToServer("[nt_ghostcap] Ghost picked up by %N (%d)! Pushing OnGhostPickedUp forward", client, client);
	#endif

	Call_StartForward(g_hForwardPickedUp);
	Call_PushCell(client);
	Call_Finish();
}
void PushOnGhostDropped(int client)
{
	if(client < 1 || client > MaxClients)
		return;
	
	#if DEBUG > 0
	PrintToServer("[nt_ghostcap] Ghost dropped by %N (%d)! Pushing OnGhostDropped forward", client, client);
	#endif
	
	Call_StartForward(g_hForwardDropped);
	Call_PushCell(client);
	Call_Finish();
}
