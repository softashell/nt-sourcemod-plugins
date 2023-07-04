#pragma semicolon 1

#include <sourcemod>

#define PLUGIN_VERSION	"0.6.4"

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

new bool:MirrorEnabled = false;

public OnPluginStart()
{
	CreateConVar("sm_ntmirrordamage_version", PLUGIN_VERSION, "NEOTOKYO° Mirror team damage timer", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);

	HookEvent("game_round_start", Event_RoundStart, EventHookMode_Post);
	HookEvent("game_round_end", Event_RoundEnd, EventHookMode_Post);

	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Post);

	hMirrorDamage = FindConVar("neo_ff_feedback");
}

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	MirrorEnabled = true;

	// Actually enable damage mirroring using built in console command
	ChangeFeedbackValue(FF_FEEDBACK_ON);

	// Disable mirror damage after 15(freeztime) + FF_PROTECTION_TIME seconds
	hMirrorTimer = CreateTimer(15.0+FF_PROTECTION_TIME, DisableMirror);
}

public Action:Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	if((hMirrorTimer != INVALID_HANDLE) && MirrorEnabled)
	{
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

	if(!IsValidClient(attacker) || victim == attacker)
		return;

	new team_victim = GetClientTeam(victim);
	new team_attacker = GetClientTeam(attacker);

	// Attacking teammate
	if(team_attacker == team_victim)
	{
		if(health >= FF_RESTORE_MIN)
			return; // Victim has enough health

		// Restore HP
		SetEntProp(victim, Prop_Send, "m_iHealth", FF_RESTORE_HP, 1);
		SetEntProp(victim, Prop_Data, "m_iHealth", FF_RESTORE_HP, 1);
	}
	else // Player is attacking enemy and timer hasn't run out yet
	{
		if(hMirrorTimer == INVALID_HANDLE)
			return;

		DisableMirror(hMirrorTimer);
	}
}

public Action:DisableMirror(Handle:timer)
{
	if (!MirrorEnabled)
		return;

	MirrorEnabled = false;

	ChangeFeedbackValue(FF_FEEDBACK_OFF);

	KillTimer(timer);

	hMirrorTimer = INVALID_HANDLE;
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

stock bool:IsValidClient(client)
{
	if ((client < 1) || (client > MaxClients))
		return false;

	if (!IsClientInGame(client))
		return false;

	if (IsFakeClient(client))
		return false;

	return true;
}