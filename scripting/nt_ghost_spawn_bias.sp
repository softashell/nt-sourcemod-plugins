#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <neotokyo>

#pragma semicolon 1
#pragma newdecls required

#define DEBUG 1
#define MAXGHOSTSPAWNS 32

#define PLUGIN_VERSION	"0.1.0"

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

int ghostSpawnPoints;
int ghostSpawnEntity[MAXGHOSTSPAWNS+1];
float ghostSpawnOrigin[MAXGHOSTSPAWNS+1][3];
float ghostSpawnRotation[MAXGHOSTSPAWNS+1][3];

public void OnPluginStart()
{
	CreateConVar("sm_nt_ghost_bias_version", PLUGIN_VERSION, "NEOTOKYO° Ghost spawn bias version", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);

	HookEvent("game_round_start", OnRoundStart, EventHookMode_Post);

	#if DEBUG > 0
	RegConsoleCmd("nt_ghost_randomize", CommandMoveGhost);
	#endif
}

#if DEBUG > 0
public Action CommandMoveGhost(int client, int args)
{
	MoveGhost(GetRandomInt(0, ghostSpawnPoints-1));

	return Plugin_Handled;
}
#endif

public void OnMapEnd()
{
	#if DEBUG > 0
	PrintToServer("[nt_ghost_spawn_bias] Map ended, resetting everything");
	#endif

	ghost = -1;
	ghostSpawnPoints = 0;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(StrEqual(classname, "weapon_ghost"))
	{
		#if DEBUG > 0
		PrintToServer("[nt_ghost_spawn_bias] Ghost spawned");
		#endif

		ghost = EntIndexToEntRef(entity);

		CheckSpawnedGhost(entity);
	}
	else if(StrEqual(classname, "neo_ghostspawnpoint"))
	{
		#if DEBUG > 0
		PrintToServer("[nt_ghost_spawn_bias] Ghost spawn point created %d", entity);
		#endif

		AddGhostSpawn(entity);
	}
	else if(StrEqual(classname, "info_player_attacker"))
	{
		#if DEBUG > 0
		PrintToServer("[nt_ghost_spawn_bias] Attacker spawn point created %d", entity);
		#endif
	}
	else if(StrEqual(classname, "info_player_defender"))
	{
		#if DEBUG > 0
		PrintToServer("[nt_ghost_spawn_bias] Defender spawn point created %d", entity);
		#endif
	}
}

void CheckSpawnedGhost(int entity)
{
	if(!ghostSpawnPoints)
	{
		return;
	}

	// TODO: Find source spawn point and figure out if it needs moving
}

void MoveGhost(int spawnPointId)
{
	#if DEBUG > 0
	PrintToServer("[nt_ghost_spawn_bias] Moving ghost to position %d Total points: %d", spawnPointId, ghostSpawnPoints);
	#endif
	
	if(!IsValidEntity(EntRefToEntIndex(ghost)))
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

	TeleportEntity(EntRefToEntIndex(ghost), ghostSpawnOrigin[spawnPointId], ghostSpawnRotation[spawnPointId], vecVelocity);
}

void AddGhostSpawn(int entity)
{
	ghostSpawnPoints++;

	#if DEBUG > 0
	PrintToServer("[nt_ghost_spawn_bias] Upadting ghost spawn point location %d Total points: %d", entity, ghostSpawnPoints);
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
	PrintToServer("[nt_ghost_spawn_bias] #%d - Location: {%.0f, %.0f, %.0f}", entity, ghostSpawnOrigin[spawnPointId][0], ghostSpawnOrigin[spawnPointId][1], ghostSpawnOrigin[spawnPointId][2]);
	#endif
}

public void OnRoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	if(!ghostSpawnPoints)
		return;

	#if DEBUG > 0
	PrintToServer("[nt_ghost_spawn_bias] Updating ghost data at round start");
	#endif

	for(int spawn = 0; spawn < ghostSpawnPoints; spawn++)
	{
		UpdateGhostSpawn(spawn);
	}

	// TODO: Save current ghost spawn point history
}