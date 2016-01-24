#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <neotokyo>
#define DEBUG 0
#pragma newdecls required

public Plugin myinfo =
{
    name = "NEOTOKYO° Double cap prevention",
    author = "soft as HELL, glub",
    description = "Removes ghost as soon as it's captured, or when round ended",
    version = "0.4",
    url = ""
};

int ghost;
Handle convar_roundtimelimit = INVALID_HANDLE;
Handle KillGhostTimer = INVALID_HANDLE;
int carrier;

public void OnPluginStart()
{
	HookEvent("game_round_end", OnRoundEnd);
	HookEvent("game_round_start", OnRoundStart); //needs start in case we foce restart
	
	convar_roundtimelimit = FindConVar("neo_round_timelimit");
}


public Action OnRoundEnd(Handle event, const char[] name, bool dontBroadcast)
{
	if(KillGhostTimer != INVALID_HANDLE)
	{
		#if DEBUG > 0
		PrintToServer("OnRoundEnd: trigerring timer!");
		#endif 
		
		TriggerTimer(KillGhostTimer);
	}
	else
	{
		#if DEBUG > 0
		PrintToChatAll("OnRoundEnd: trying to remove ghost!");
		PrintToServer("OnRoundEnd: trying to remove ghost!");
		#endif
		
		if(!IsValidEntity(ghost))
			return;
		
		char classname[50];
		GetEntityClassname(ghost, classname, sizeof(classname));
		
		if(!StrEqual(classname, "weapon_ghost"))
			return;
		
		carrier = GetEntPropEnt(ghost, Prop_Data, "m_hOwnerEntity");
		
		if((MaxClients > carrier > 0) && IsPlayerAlive(carrier))
		{
			#if DEBUG > 0
			PrintToChatAll("OnRoundEnd: removed ghost from carrier %i!", carrier);
			PrintToServer("OnRoundEnd: removed ghost from carrier %i!", carrier);
			#endif
			
			RemoveGhost(carrier);
		}
		else
		{
			if(IsValidEdict(ghost))
			{
				#if DEBUG > 0
				PrintToChatAll("OnRoundEnd: removed ghost %i classname %s!", ghost, classname);
				PrintToServer("OnRoundEnd: removed ghost %i classname %s!", ghost, classname);
				#endif
				
				RemoveEdict(ghost);
			}
		}
	}

}

public Action OnRoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	if(KillGhostTimer != INVALID_HANDLE)
		KillTimer(KillGhostTimer);
	
	KillGhostTimer = CreateTimer((GetConVarFloat(convar_roundtimelimit) * 60.0 ) + 5.0, timer_RemoveGhost, _, TIMER_FLAG_NO_MAPCHANGE); //+sec after round end
}

public Action timer_RemoveGhost(Handle timer)
{
	if(!IsValidEntity(ghost))
	{
		KillGhostTimer = INVALID_HANDLE;
		return Plugin_Handled;
	}
	
	char classname[50];
	GetEntityClassname(ghost, classname, sizeof(classname));
	
	if(!StrEqual(classname, "weapon_ghost"))
	{
		KillGhostTimer = INVALID_HANDLE;
		return Plugin_Handled;
	}


	carrier = GetEntPropEnt(ghost, Prop_Data, "m_hOwnerEntity");
	
	#if DEBUG > 0
	PrintToChatAll("Timer: carrier = %i", carrier);
	#endif
	
	if((MaxClients > carrier > 0) && IsPlayerAlive(carrier))
	{
		#if DEBUG > 0
		PrintToChatAll("Timer: removed ghost from carrier %i!", carrier);
		#endif
		
		RemoveGhost(carrier);
	}
	else
	{
		if(IsValidEdict(ghost))
		{
			#if DEBUG > 0
			PrintToChatAll("Timer: removed ghost %i classname %s!", ghost, classname);
			PrintToServer("Timer: removed ghost %i classname %s!", ghost, classname);
			#endif
			
			RemoveEdict(ghost);
		}
	}
	
	KillGhostTimer = INVALID_HANDLE;
	
	return Plugin_Handled;
}


public void OnGhostSpawn(int entity)
{
	// Save current ghost id for later use
	ghost = entity;
	
	#if DEBUG > 0
	PrintToServer("Ghost %i spawned", ghost);
	#endif
}

public void OnGhostCapture(int client)
{
	// Might have to delay this for a bit, 0.5 seconds?
	RemoveGhost(client);
}

void RemoveGhost(int client)
{
	#if DEBUG > 0
	PrintToServer("Removing current ghost %i", ghost);
	#endif

	// Switch to last weapon if player is still alive and has ghost active
	if(IsValidClient(client) && IsPlayerAlive(client))
	{
		int activeweapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
		int ghost_index = EntRefToEntIndex(ghost);

		if(activeweapon == ghost_index)
		{
			
			//TODO: force TOSS? since viewmodel is not updated correctly due to latency latency
			
			int lastweapon = GetEntPropEnt(client, Prop_Data, "m_hLastWeapon");

			if(IsValidEdict(lastweapon))
				SetEntPropEnt(client, Prop_Data, "m_hActiveWeapon", lastweapon);
		}
	}

	// Delete ghost
	if(IsValidEdict(ghost))
		RemoveEdict(ghost);
}

public void OnMapEnd()
{
	KillGhostTimer = INVALID_HANDLE;
}
