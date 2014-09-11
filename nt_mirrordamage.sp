#pragma semicolon 1

#include <sourcemod>

#define PLUGIN_VERSION	"0.5"

// How much of applied damage attacker recieves (maximum is x4.0)
#define FF_FEEDBACK_ON 2.0 //Attacker takes double damage
#define FF_FEEDBACK_OFF 0.0

#define FF_RESTORE_MIN 100 // Gives player FF_RESTORE_HP if health falls below this value
#define FF_RESTORE_HP 100 // Sets health to FF_RESTORE_HP if itfalls below FF_RESTORE_MIN from team damage

#define FF_PROTECTION_TIME 7.0

public Plugin:myinfo =
{
    name = "NEOTOKYO° Mirror team damage timer",
    author = "Soft as HELL",
    description = "Enable team damage mirror at round start",
    version = PLUGIN_VERSION,
    url = ""
};

new Handle:hMirrorDamage;
new Handle:hMirrorTimer;

new bool:IsAttackingEnemy[MAXPLAYERS+1] = false;
new bool:MirrorEnabled = false;

public OnPluginStart()
{
	CreateConVar("sm_ntmirrordamage_version", PLUGIN_VERSION, "NEOTOKYO° Mirror team damage timer", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	
	HookEvent("game_round_start", Event_RoundStart, EventHookMode_Post);
	HookEvent("game_round_end", Event_RoundEnd, EventHookMode_Post);

	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Post);

	hMirrorDamage = FindConVar("neo_ff_feedback");

}

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	for (new i = 0; i <= MaxClients; i++)
	{
		if(IsValidClient(i))
			IsAttackingEnemy[i] = false;
	}

	MirrorEnabled = true;

	ChangeFeedbackValue(FF_FEEDBACK_ON);

	// Disable mirror damage after 15(freeztime) + FF_PROTECTION_TIME seconds
	hMirrorTimer = CreateTimer(15.0+FF_PROTECTION_TIME, DisableMirror);
}

public Action:Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	if((hMirrorTimer != Handle:0) && MirrorEnabled)
	{
		KillTimer(hMirrorTimer);

		DisableMirror(hMirrorTimer);
	}
}

public Action:Event_PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(!MirrorEnabled)
		return;

	new victimId = GetEventInt(event, "userid");
	new attackerId = GetEventInt(event, "attacker");

	new health = GetEventInt(event, "health");

	new victim = GetClientOfUserId(victimId);
	new attacker = GetClientOfUserId(attackerId);

	if(!IsValidClient(attacker) || (victim == attacker))
		return;

	new team_victim = GetClientTeam(victim);
	new team_attacker = GetClientTeam(attacker);

	if(team_attacker == team_victim)
	{
		if(health <= FF_RESTORE_MIN)
		{
			SetEntProp(victim, Prop_Send, "m_iHealth", FF_RESTORE_HP, 1);
			SetEntProp(victim, Prop_Data, "m_iHealth", FF_RESTORE_HP, 1);
		}
	}
	
	else
	{
		IsAttackingEnemy[attacker] = true;
		CreateTimer(3.0, Timer_EnableMirrorAfterEngage(attacker));
	}
}

public Action:Timer_EnableMirrorAfterEngage(Handle:timer, any:attacker)
{
	IsAttackingEnemy[attacker] = false;
}

public Action:DisableMirror(Handle:timer)
{
	if (!MirrorEnabled)
		return;

	MirrorEnabled = false;

	ChangeFeedbackValue(FF_FEEDBACK_OFF);
}

// Change neo_ff_feedback value and supress notification
ChangeFeedbackValue(Float:feedback)
{
	new flags = GetConVarFlags(hMirrorDamage);

	flags &= ~FCVAR_NOTIFY;
	SetConVarFlags(hMirrorDamage, flags);

	SetConVarFloat(hMirrorDamage, feedback);

	flags |= FCVAR_NOTIFY;
	SetConVarFlags(hMirrorDamage, flags);
}

bool:IsValidClient(client){
	
	if (client == 0)
		return false;
	
	if (!IsClientConnected(client))
		return false;
	
	if (IsFakeClient(client))
		return false;
	
	if (!IsClientInGame(client))
		return false;
	
	return true;
}