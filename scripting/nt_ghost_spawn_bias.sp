#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <neotokyo>

#pragma semicolon 1
#pragma newdecls required

#define DEBUG 0
#define MAXGHOSTSPAWNS 32

#define PLUGIN_VERSION	"0.2.2"

public Plugin myinfo =
{
	name = "NEOTOKYO° Ghost spawn bias",
	author = "soft as HELL",
	description = "Very biased random ghost spawns",
	version = PLUGIN_VERSION,
	url = "https://github.com/softashell/nt-sourcemod-plugins"
};

// Globals
int ghost;
int nextSpawn;
bool nextSpawnChanged;

int ghostSpawnPoints;
int ghostSpawnEntity[MAXGHOSTSPAWNS+1];
float ghostSpawnOrigin[MAXGHOSTSPAWNS+1][3];
float ghostSpawnRotation[MAXGHOSTSPAWNS+1][3];

ArrayList  validSpawnArray;
ArrayList  badSpawnArray;

Handle hRestartGame;
ConVar cvarBiasEnabled, cvarBiasMoveRounds;

public void OnPluginStart()
{
	CreateConVar("sm_nt_ghost_bias_version", PLUGIN_VERSION, "NEOTOKYO° Ghost spawn bias version", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	cvarBiasEnabled = CreateConVar("sm_nt_ghost_bias_enabled", "1", "Enable/Disable ghost spawn bias", _, true, 0.0, true, 1.0);
	cvarBiasMoveRounds = CreateConVar("sm_nt_ghost_bias_rounds", "2", "Move ghost every X rounds", _, true, 1.0, true, 4.0);

	HookEvent("game_round_start", OnRoundStart, EventHookMode_Post);

	hRestartGame = FindConVar("neo_restart_this");
	if(hRestartGame != INVALID_HANDLE)
	{
		HookConVarChange(hRestartGame, OnGameRestart);
	}

	#if DEBUG > 0
	RegConsoleCmd("nt_ghost_randomize", CommandMoveGhost);
	RegConsoleCmd("nt_ghost_movenext", CommandMoveGhostFair);
	#endif

	validSpawnArray = new ArrayList();
	badSpawnArray = new ArrayList();
}

#if DEBUG > 0
public Action CommandMoveGhost(int client, int args)
{
	MoveGhost(GetURandomInt() % ghostSpawnPoints);

	return Plugin_Handled;
}

public Action CommandMoveGhostFair(int client, int args)
{
	GameRules_SetProp("m_iRoundNumber", GameRules_GetProp("m_iRoundNumber") + 1);
	CheckSpawnedGhost(ghost);

	return Plugin_Handled;
}
#endif

public void OnGameRestart(Handle convar, const char[] oldValue, const char[] newValue)
{
	if(StringToInt(newValue) == 0)
		return; // Not restarting

	ResetVariables();
}

public void OnMapEnd()
{
	ghost = -1;
	ghostSpawnPoints = 0;

	ResetVariables();
}

public void ResetVariables()
{
	#if DEBUG > 0
	PrintToServer("[nt_ghost_spawn_bias] Resetting everything");
	#endif

	nextSpawnChanged = false;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(!cvarBiasEnabled.BoolValue)
		return;

	if(StrEqual(classname, "weapon_ghost"))
	{
		#if DEBUG > 0
		PrintToServer("[nt_ghost_spawn_bias] Ghost spawned");
		#endif

		ghost = EntIndexToEntRef(entity);
	}
	else if(StrEqual(classname, "neo_ghostspawnpoint"))
	{
		#if DEBUG > 0
		PrintToServer("[nt_ghost_spawn_bias] Ghost spawn point created %d", entity);
		#endif

		AddGhostSpawn(entity);
	}
}

void CheckSpawnedGhost(int ghostRef)
{
	if(!ghostSpawnPoints || !IsValidEntity(ghost))
	{
		return;
	}

	int entity = EntRefToEntIndex(ghostRef);

	float entitySpawnOrigin[3];

	GetEntPropVector(entity, Prop_Data, "m_vecOrigin", entitySpawnOrigin);

	#if DEBUG > 0
	PrintToServer("[nt_ghost_spawn_bias] Ghost spawn post!! #%d - Location: {%.0f, %.0f, %.0f}", entity, entitySpawnOrigin[0], entitySpawnOrigin[1], entitySpawnOrigin[2]);
	#endif

	int closestSpawn = -1;
	float closestDistance = -1.0;
	for(int spawn = 0; spawn < ghostSpawnPoints; spawn++)
	{
		float distance = GetVectorDistance(entitySpawnOrigin, ghostSpawnOrigin[spawn]);
		if(distance < closestDistance  || closestSpawn == -1)
		{
			closestSpawn = spawn;
			closestDistance = distance;
		}

		#if DEBUG > 1
		PrintToServer("[nt_ghost_spawn_bias] Checking closest spawn #%d Distance: %.0f - Location: {%.0f, %.0f, %.0f}", spawn, distance, ghostSpawnOrigin[spawn][0], ghostSpawnOrigin[spawn][1], ghostSpawnOrigin[spawn][2]);
		#endif
	}

	if(closestSpawn != -1.0)
	{
		#if DEBUG > 0
		PrintToServer("[nt_ghost_spawn_bias] Found closest spawn #%d Distance: %.0f - Location: {%.0f, %.0f, %.0f}", closestSpawn, closestDistance, ghostSpawnOrigin[closestSpawn][0], ghostSpawnOrigin[closestSpawn][1], ghostSpawnOrigin[closestSpawn][2]);
		#endif

		if(closestSpawn != validSpawnArray.Get(nextSpawn))
		{
			#if DEBUG > 0
			PrintToServer("[nt_ghost_spawn_bias] Moving ghost from spawn #%d to #%d", closestSpawn, nextSpawn);
			#endif

			MoveGhost(validSpawnArray.Get(nextSpawn));
		}

		if(GameRules_GetProp("m_iRoundNumber") % cvarBiasMoveRounds.IntValue == 0)
		{
			nextSpawn++;
			if(nextSpawn >= validSpawnArray.Length)
			{
				nextSpawn = 0;
			}

			#if DEBUG > 0
			PrintToServer("[nt_ghost_spawn_bias] Changing next spawn to %d", nextSpawn);
			#endif
		}
	}
}

void MoveGhost(int spawnPointId)
{
	#if DEBUG > 0
	PrintToServer("[nt_ghost_spawn_bias] Moving ghost to position %d - Location: {%.0f, %.0f, %.0f} Total points: %d Valid points: %d", spawnPointId, ghostSpawnOrigin[spawnPointId][0], ghostSpawnOrigin[spawnPointId][1], ghostSpawnOrigin[spawnPointId][2], ghostSpawnPoints, validSpawnArray.Length);
	#endif
	
	if(!IsValidEntity(ghost))
	{
		return;
	}

	int ghostCarrier = GetEntPropEnt(ghost, Prop_Data, "m_hOwnerEntity");
	if(IsValidClient(ghostCarrier))
	{
		return;
	}

	// Need to pass this to avoid prop being stuck in air
	float vecVelocity[3] = { 0.0, 0.01, 0.0 };

	TeleportEntity(ghost, ghostSpawnOrigin[spawnPointId], ghostSpawnRotation[spawnPointId], vecVelocity);
}

void AddGhostSpawn(int entity)
{
	ghostSpawnPoints++;

	#if DEBUG > 0
	PrintToServer("[nt_ghost_spawn_bias] Updating ghost spawn point location %d Total points: %d", entity, ghostSpawnPoints);
	#endif

	int spawn = ghostSpawnPoints-1;

	ghostSpawnEntity[spawn] = EntIndexToEntRef(entity);
}

void UpdateGhostSpawn(int spawnPointId)
{
	int entity = EntRefToEntIndex(ghostSpawnEntity[spawnPointId]);

	// Update location
	GetEntPropVector(entity, Prop_Data, "m_vecOrigin", ghostSpawnOrigin[spawnPointId]);
	GetEntPropVector(entity, Prop_Data, "m_angRotation", ghostSpawnRotation[spawnPointId]);

	#if DEBUG > 0
	float distanceFromLast = 0.0;
	if(spawnPointId > 0)
	{
		distanceFromLast = GetVectorDistance(ghostSpawnOrigin[spawnPointId-1], ghostSpawnOrigin[spawnPointId]);
	}

	PrintToServer("[nt_ghost_spawn_bias] #%d - Location: {%.0f, %.0f, %.0f} - Distance from last: %.0f", entity, ghostSpawnOrigin[spawnPointId][0], ghostSpawnOrigin[spawnPointId][1], ghostSpawnOrigin[spawnPointId][2], distanceFromLast);
	#endif
}

public void OnRoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	if(!cvarBiasEnabled.BoolValue)
		return;

	if(!ghostSpawnPoints)
		return;

	#if DEBUG > 0
	PrintToServer("[nt_ghost_spawn_bias] Updating ghost data at round start");
	#endif

	if(!nextSpawnChanged && ghostSpawnPoints)
	{
		for(int spawn = 0; spawn < ghostSpawnPoints; spawn++)
		{
			UpdateGhostSpawn(spawn);
		}

		GenerateValidSpawnPoints();

		if(validSpawnArray.Length)
			nextSpawn = GetURandomInt() % validSpawnArray.Length;

		#if DEBUG > 0
		PrintToServer("[nt_ghost_spawn_bias] Initial spawn %d Valid points: %d", nextSpawn, validSpawnArray.Length);
		#endif

		nextSpawnChanged = true;
	}

	CheckSpawnedGhost(ghost);
}

public void GenerateValidSpawnPoints()
{
	badSpawnArray.Clear();
	validSpawnArray.Clear();

	for(int spawn = 0; spawn < ghostSpawnPoints; spawn++)
	{
		validSpawnArray.Push(spawn);
	}

	for(int spawn = 0; spawn < ghostSpawnPoints; spawn++)
	{
		if(badSpawnArray.FindValue(spawn) != -1)
			continue;

		for(int targetSpawn = 0; targetSpawn < ghostSpawnPoints; targetSpawn++)
		{
			if(targetSpawn == spawn)
				continue;

			if(badSpawnArray.FindValue(targetSpawn) != -1)
				continue;

			float distance = GetVectorDistance(ghostSpawnOrigin[spawn], ghostSpawnOrigin[targetSpawn]);
			if(distance < 100)
			{
				badSpawnArray.Push(targetSpawn);
			}
		}
	}

	int size = badSpawnArray.Length;
	int removed;
	for (int i = 0; i < size; i++)
	{
		int value = badSpawnArray.Get(i);
		int spawnIndex = validSpawnArray.FindValue(value);
		if(spawnIndex != -1)
		{
			validSpawnArray.Erase(spawnIndex);
			removed++;
		}
	}
	badSpawnArray.Clear();

	#if DEBUG > 0
	if(removed)
	{
		PrintToServer("[nt_ghost_spawn_bias] Removed %d bad spawn points, Valid spawns: %d", removed, validSpawnArray.Length);
	}
	#endif

	validSpawnArray.Sort(Sort_Random, Sort_Integer);
}
