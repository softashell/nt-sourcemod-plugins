#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <neotokyo>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION	"1.5.5"

#define MAXCAPZONES 4
#define INACCURACY 0.35

Handle g_hRoundTime, g_hForwardCapture, g_hForwardSpawn;

int capzones[MAXCAPZONES+1], capTeam[MAXCAPZONES+1], capRadius[MAXCAPZONES+1];
float capzoneVector[MAXCAPZONES+1][3];
bool capzoneDataUpdated[MAXCAPZONES+1];

int ghost, totalCapzones;
bool roundReset = true;
float fStartRoundTime;

public Plugin myinfo =
{
	name = "NEOTOKYO° Ghost capture event",
	author = "soft as HELL",
	description = "Logs ghost capture event",
	version = PLUGIN_VERSION,
	url = ""
};

public void OnPluginStart()
{
	CreateConVar("sm_ntghostcap_version", PLUGIN_VERSION, "NEOTOKYO° Ghost cap event version", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);

	g_hRoundTime = FindConVar("neo_round_timelimit");

	g_hForwardCapture = CreateGlobalForward("OnGhostCapture", ET_Event, Param_Cell);
	g_hForwardSpawn = CreateGlobalForward("OnGhostSpawn", ET_Event, Param_Cell);

	HookEvent("game_round_start", OnRoundStart, EventHookMode_Post);

	CreateTimer(0.25, CheckGhostPosition, _, TIMER_REPEAT);
}

public void OnMapEnd() {
	totalCapzones = 0;
	roundReset = true;

	int i;

	for(i = 0; i <= MAXCAPZONES; i++)
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
			PrintToServer("Too many capzones in map! Consider changing MAXCAPZONES. (#%i)", totalCapzones);
			return;
		}

		capzones[totalCapzones]   = entity;
	}
}

public Action OnRoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	fStartRoundTime = GetGameTime();

	if(!totalCapzones) // No cap zones
		return;

	roundReset = true; // Allow logging of capture again

	// Update capzone team every round
	for (int capzone = 0; capzone <= totalCapzones; capzone++)
	{
		if(capzones[capzone] == 0) // Worldspawn
			continue;

		if(!capzoneDataUpdated[capzone])
			capzoneDataUpdated[capzone] = UpdateCapzoneData(capzone);

		//PrintToChatAll("Capzone: %d, Radius: %i, Location: %.1f %.1f %.1f", capzones[capzone], capRadius[capzone], capzoneVector[capzone][0], capzoneVector[capzone][1], capzoneVector[capzone][2]);
		capTeam[capzone] = GetEntProp(capzones[capzone], Prop_Send, "m_OwningTeamNumber");
	}
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

	if(carrier < 1 || carrier > MaxClients)
		return;

	if(IsClientInGame(carrier) && IsPlayerAlive(carrier))
	{
		carrierTeamID = GetClientTeam(carrier);

		for(capzone = 0; capzone <= totalCapzones; capzone++)
		{
			if(capzones[capzone] == 0) // Worldspawn
				continue;

			if(carrierTeamID != capTeam[capzone]) // Wrong capture zone
				continue;

			GetClientAbsOrigin(carrier, ghostVector);

			distance = GetVectorDistance(ghostVector, capzoneVector[capzone]);

			// If capzone has no radius ingore it
			if(capRadius[capzone] <= 0)
				continue;

			if(distance <= capRadius[capzone])
			{
				if (!IsAnyEnemyStillAlive(carrierTeamID))
					return; // Don't get anything if enemy team is dead already

				roundReset = false; // Won't spam any more events unless value is set to true

				PushOnGhostCapture(carrier);

				LogGhostCapture(carrier, carrierTeamID);

				break; //No point in continuing loop
			}
		}
	}

}

bool IsAnyEnemyStillAlive(int team)
{
	int enemyTeam, i;

	for(i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i))
			continue;

		if(IsPlayerAlive(i)) {
			enemyTeam = GetClientTeam(i);

			if((team == TEAM_JINRAI && enemyTeam == TEAM_NSF) || (team == TEAM_NSF && enemyTeam == TEAM_JINRAI))
				return true;
		}
	}

	return false;
}

bool UpdateCapzoneData(int capzone)
{
	int entity = capzones[capzone];

	if(!IsValidEdict(entity))
		return false;

	capRadius[capzone]  = GetEntProp(entity, Prop_Send, "m_Radius");

	GetEntPropVector(entity, Prop_Data, "m_vecOrigin", capzoneVector[capzone]);

	//PrintToServer("Updating data! Capzone: %d, Radius: %i, Location: %.1f %.1f %.1f", capzones[capzone], capRadius[capzone], capzoneVector[capzone][0], capzoneVector[capzone][1], capzoneVector[capzone][2]);

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
	Call_StartForward(g_hForwardCapture);
	Call_PushCell(client);
	Call_Finish();
}

void PushOnGhostSpawn(int entity)
{
	Call_StartForward(g_hForwardSpawn);
	Call_PushCell(entity);
	Call_Finish();
}
