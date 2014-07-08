#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define PLUGIN_VERSION	"1.0.1"

#define MAXCAPZONES 4

new ghost, totalcapzones = 0, capzones[MAXCAPZONES], capteam[MAXCAPZONES], capradius[MAXCAPZONES], bool:round_reset = true;

public Plugin:myinfo =
{
    name = "NEOTOKYO° Ghost capture event",
    author = "Soft as HELL",
    description = "Logs ghost capture event",
    version = PLUGIN_VERSION,
    url = ""
};

public OnPluginStart()
{
    CreateConVar("sm_ntghostcapevent_version", PLUGIN_VERSION, "NEOTOKYO° Ghost cap event version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);

    HookEvent("game_round_start", Event_RoundStart, EventHookMode_Post);

    CreateTimer(0.5, CheckGhostPosition, _, TIMER_REPEAT);
}

public OnMapStart()
{
    new maxentities = GetMaxEntities(); // the highest number of entities on the map.

    decl String:classname[32];
    new capzone = 0, entity;

    for (entity = MAXPLAYERS + 1; entity <= maxentities; entity++) {

            if (!IsValidEdict(entity)) // if the int isn't a valid entity index, then stop
                continue;

            GetEdictClassname(entity, classname, sizeof(classname));

            if(StrEqual(classname, "neo_ghost_retrieval_point")) {
                capzones[capzone]   = entity;
                capradius[capzone]  = GetEntProp(entity, Prop_Send, "m_Radius");

                if(capzone < 4)
                    capzone++;
            }

    }

    totalcapzones = capzone;
}

public OnEntityCreated(entity, const String:classname[])
{
    if (StrEqual(classname, "weapon_ghost"))
        ghost = entity;
    
}

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast) {

    round_reset = true; // Allow logging of capture again

    if(!totalcapzones) // No cap zones
        return;

    // Update capzone team every round
    for (new capzone = 0; capzone < totalcapzones; capzone++) {
        if(capzones[capzone] == 0) // Worldspawn
            return;

        //PrintToChatAll("Capzone: %d", capzones[capzone]);
        capteam[capzone] = GetEntProp(capzones[capzone], Prop_Send, "m_OwningTeamNumber");
    }
}

public Action:CheckGhostPosition(Handle:timer) {
    decl Float:ghostVector[3], Float:capzoneVector[3], Float:distance;
    decl String:carrierSteamID[64], String:carrierTeam[18];

    new capzone, entity, carrier, carrierTeamID;

    carrier = GetEntPropEnt(ghost, Prop_Data, "m_hOwnerEntity");

    if(!round_reset || carrier == -1)
        return;

    if (IsClientInGame(carrier) && IsPlayerAlive(carrier)) {
        carrierTeamID = GetClientTeam(carrier);

        GetClientAbsOrigin(carrier, ghostVector);

        if(!totalcapzones) // No cap zones
            return;

        for (capzone=0; capzone < totalcapzones; capzone++) {

            entity = capzones[capzone];

            if(entity == 0) // Worldspawn
                continue;

            if(carrierTeamID != capteam[capzone]) // Wrong capture zone
                continue;

            GetEntPropVector(entity, Prop_Data, "m_vecOrigin", capzoneVector); // Yeah, I know it's retarded getting it every time, but I just couldn't find a nice way to cache it

            distance = GetVectorDistance(ghostVector, capzoneVector);

            if(distance <= capradius[capzone]) {
                if (!IsAnyEnemyStillAlive(carrierTeamID))
                    return; // Don't get anything if enemy team is dead already

                round_reset = false; // Won't spam any more events unless value is set to true
                
                //PrintToChatAll("Captured the ghost!");
                
                new carrierUserID = GetClientUserId(carrier);

                GetClientAuthString(carrier, carrierSteamID, 64);
                GetTeamName(carrierTeamID, carrierTeam, sizeof(carrierTeam));

                LogToGame("Team \"%s\" triggered \"ghost_capture_team\"", carrierTeam);
                LogToGame("\"%N<%d><%s><%s>\" triggered \"ghost_capture\"", carrier, carrierUserID, carrierSteamID, carrierTeam);

                break; //No point in continuing loop
            }
        }
    } 

}

public bool:IsAnyEnemyStillAlive(team){
    new enemyTeam;
    for(new i = 1; i <= MaxClients; i++) {
        if(IsClientConnected(i) && IsPlayerAlive(i)) {
            enemyTeam = GetClientTeam(i);

            if((team == 2 && enemyTeam == 3) || (team == 3 && enemyTeam == 2))
                return true;
        }
    }

    return false;
}
