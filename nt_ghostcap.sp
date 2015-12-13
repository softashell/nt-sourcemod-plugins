#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define PLUGIN_VERSION	"1.3.1"

#define MAXCAPZONES 4

new capzones[MAXCAPZONES+1], capTeam[MAXCAPZONES+1], capRadius[MAXCAPZONES+1], Float:capzoneVector[MAXCAPZONES+1][3], bool:capzoneDataUpdated[MAXCAPZONES+1];

new ghost, totalCapzones, thisRoundCapper = 0, bool:roundReset = true;

public Plugin:myinfo =
{
	name = "NEOTOKYO° Ghost capture event",
	author = "Soft as HELL",
	description = "Logs ghost capture event",
	version = PLUGIN_VERSION,
	url = ""
};

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	CreateNative("Ghostcap_CapInfo", Ghostcap_CapInfo);
	
	return APLRes_Success;
}

public OnPluginStart()
{
	CreateConVar("sm_ntghostcapevent_version", PLUGIN_VERSION, "NEOTOKYO° Ghost cap event version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);

	HookEvent("game_round_start", Event_RoundStart, EventHookMode_Post);

	CreateTimer(0.5, CheckGhostPosition, _, TIMER_REPEAT);
}

public OnMapEnd() {
	totalCapzones = 0;
	roundReset = true;

	for(new i; i <= MAXCAPZONES; i++)
	{
		capzones[i] = 0;
		capzoneDataUpdated[i] = false;
	}
}

public OnEntityCreated(entity, const String:classname[])
{
	if (StrEqual(classname, "weapon_ghost"))
	{
		ghost = entity;
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

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	// After freezetime, reset last round's capper info native.
	// Any 3rd party plugin should have called the native by now during the roundstart event.
	CreateTimer(10.0, Timer_ResetCapperInfo_LastRound);
	
	if(!totalCapzones) // No cap zones
		return;
	
	roundReset = true; // Allow logging of capture again

	// Update capzone team every round
	for (new capzone = 0; capzone <= totalCapzones; capzone++)
	{
		if(capzones[capzone] == 0) // Worldspawn
			continue;

		if(!capzoneDataUpdated[capzone])
			capzoneDataUpdated[capzone] = UpdateCapzoneData(capzone);

		//PrintToChatAll("Capzone: %d, Radius: %i, Location: %.1f %.1f %.1f", capzones[capzone], capRadius[capzone], capzoneVector[capzone][0], capzoneVector[capzone][1], capzoneVector[capzone][2]);
		capTeam[capzone] = GetEntProp(capzones[capzone], Prop_Send, "m_OwningTeamNumber");

		//Set capzone radius to 0 to disable double capping
		SetEntProp(capzones[capzone], Prop_Send, "m_Radius", 0);
	}

	//Enable capzones again after 2 seconds from round start
	CreateTimer(2.0, timer_EnableCapzones);
}

public Action:timer_EnableCapzones(Handle:timer, any:client)
{
	PrintToServer("Enabling capzones");

	for (new capzone = 0; capzone <= totalCapzones; capzone++)
	{
		if(capzones[capzone] == 0) // Worldspawn
			continue;

		// Set radius to default value again
		SetEntProp(capzones[capzone], Prop_Send, "m_Radius", capRadius[capzone]);
	}
}

public Action:CheckGhostPosition(Handle:timer)
{
	if (!totalCapzones || !IsValidEdict(ghost))
		return; // No capzones or no ghost

	decl Float:ghostVector[3], Float:distance;
	decl String:carrierSteamID[64], String:carrierTeam[18];

	new capzone, entity, carrier, carrierTeamID;

	carrier = GetEntPropEnt(ghost, Prop_Data, "m_hOwnerEntity");

	if(!roundReset || carrier < 1 || carrier > MaxClients)
		return;

	if (IsClientInGame(carrier) && IsPlayerAlive(carrier))
	{
		carrierTeamID = GetClientTeam(carrier);

		GetClientAbsOrigin(carrier, ghostVector);

		for (capzone=0; capzone <= totalCapzones; capzone++)
		{
			entity = capzones[capzone];

			if(entity == 0) // Worldspawn
				continue;

			if(carrierTeamID != capTeam[capzone]) // Wrong capture zone
				continue;

			distance = GetVectorDistance(ghostVector, capzoneVector[capzone]);

			// If capzone has no radius ingore it
			if(capRadius[capzone] <= 0)
				continue;

			if(distance <= capRadius[capzone])
			{
				if (!IsAnyEnemyStillAlive(carrierTeamID))
					return; // Don't get anything if enemy team is dead already

				roundReset = false; // Won't spam any more events unless value is set to true
				
				//PrintToChatAll("Captured the ghost! Capzone: %i", capzone);
				
				new carrierUserID = GetClientUserId(carrier);
				
				new team = GetClientTeam(carrier);
				thisRoundCapper = team;
				
				GetClientAuthId(carrier, AuthId_Steam2, carrierSteamID, 64);
				GetTeamName(carrierTeamID, carrierTeam, sizeof(carrierTeam));

				LogToGame("Team \"%s\" triggered \"ghost_capture_team\"", carrierTeam);
				LogToGame("\"%N<%d><%s><%s>\" triggered \"ghost_capture\"", carrier, carrierUserID, carrierSteamID, carrierTeam);

				break; //No point in continuing loop
			}
		}
	} 

}

public Action:Timer_ResetCapperInfo_LastRound(Handle:timer)
{
	thisRoundCapper = 0;
}

public bool:IsAnyEnemyStillAlive(team)
{
	new enemyTeam;
	for(new i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i))
			continue;

		if(IsPlayerAlive(i)) {
			enemyTeam = GetClientTeam(i);

			if((team == 2 && enemyTeam == 3) || (team == 3 && enemyTeam == 2))
				return true;
		}
	}

	return false;
}

bool:UpdateCapzoneData(capzone)
{
	new entity = capzones[capzone];

	if(!IsValidEdict(entity))
		return false;

	capRadius[capzone]  = GetEntProp(entity, Prop_Send, "m_Radius");

	GetEntPropVector(entity, Prop_Data, "m_vecOrigin", capzoneVector[capzone]);

	//PrintToServer("Updating data! Capzone: %d, Radius: %i, Location: %.1f %.1f %.1f", capzones[capzone], capRadius[capzone], capzoneVector[capzone][0], capzoneVector[capzone][1], capzoneVector[capzone][2]);

	return true;
}

public Ghostcap_CapInfo(Handle:plugin, numParams)
{
	return thisRoundCapper;
}