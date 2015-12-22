#pragma semicolon 1

#include <sdkhooks>
#include <sdktools>
#include <neotokyo>

public Plugin:myinfo = 
{
	name = "NEOTOKYO° Weapon Drop Tweaks",
	author = "soft as HELL",
	description = "Drops weapon with ammo and disables ammo pickup",
	version = "0.1",
	url = ""
}

new String:weapon_blacklist[][] = {
	"weapon_knife",
	"weapon_remotedet",
	"weapon_grenade",
	"weapon_smokegrenade",
	"weapon_ghost"
};

#define DEBUG 0

new bool:g_bTossHeld[MAXPLAYERS+1];

public OnPluginStart()
{
	HookEvent("player_death", event_PlayerDeath, EventHookMode_Pre);

	// Hook equp if plugin is restarted
	for(new client = 1; client <= MaxClients; client++)
	{
		if(IsValidClient(client))
			SDKHook(client, SDKHook_WeaponEquip, OnWeaponEquip); 
	}
}

public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_WeaponEquip, OnWeaponEquip); 
}

public Action:OnWeaponEquip(client, weapon) 
{ 
	// Blocks ammo pickup from dropped weapons
	return Plugin_Handled;
}

public event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	// Comment out to test with bots
	if(1 > client > MaxClients) 
		return;
	
	if(!IsClientInGame(client))
		return;

	#if DEBUG > 0
	PrintToServer("%N (%d) dropping weapon on death", client, client);
	#endif

	new active_weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");

	WeaponDropPost(client, active_weapon);
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{	
	if((buttons & IN_TOSS) == IN_TOSS)
	{
		if(g_bTossHeld[client])
		{
			buttons &= ~IN_TOSS; // Weapon only gets dropped on release
			return;
		}
		else 
		{
			new active_weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");

			WeaponDropPost(client, active_weapon);

			g_bTossHeld[client] = true;
		}
	}
	else 
	{
		g_bTossHeld[client] = false;
	}
}

public OnWeaponPickup(int weapon, int other)
{
	new owner = GetEntPropEnt(weapon, Prop_Data, "m_hOwnerEntity");

	decl String:classname[30];
	if(!GetEntityClassname(weapon, classname, sizeof(classname)))
		return; // Can't get class name

	if(other != owner)
		return; // Didn't pick up weapon

	// Remove current hook
	SDKUnhook(weapon, SDKHook_TouchPost, OnWeaponPickup);

	if(!IsPlayerAlive(owner))
		return;

	new ammotype = GetAmmoType(weapon);
	new current_ammo = GetWeaponAmmo(owner, ammotype);
	new ammo = GetEntProp(weapon, Prop_Data, "m_iSecondaryAmmoCount");

	// Remove secondary ammo
	SetEntProp(weapon, Prop_Data, "m_iSecondaryAmmoCount", 0);

	// Set the weapons secondary ammo as primary ammo
	SetWeaponAmmo(owner, ammotype, current_ammo + ammo);

	#if DEBUG > 0
	PrintToChatAll("%s picked up by %N with %d ammo", classname, owner, ammo);
	#endif
}

public Action:timer_DropWeapon(Handle:timer, Handle pack)
{
	ResetPack(pack);

	new client = ReadPackCell(pack);
	new weapon = ReadPackCell(pack);
	new ammotype = ReadPackCell(pack);
	new ammo = ReadPackCell(pack);

	if(!IsValidEdict(weapon))
		return; // Are you trying to tick me again?

	new owner = GetEntPropEnt(weapon, Prop_Data, "m_hOwnerEntity");

	if(owner != -1)
		return;

	#if DEBUG > 0
	decl String:classname[30];
	if(!GetEntityClassname(weapon, classname, sizeof(classname)))
		return; // Can't get class name

	PrintToChat(client, "%s dropped by %N with %d ammo", classname, client, ammo);
	#endif

	if(IsPlayerAlive(client))
	{
		// It's possible to drop a weapon and pick up a new one before ammo has been removed
		// So I'm trying to remove dropped ammo without touching new one
		new current_ammo = GetWeaponAmmo(client, ammotype);
		new new_ammo = current_ammo - ammo;

		if(new_ammo < 0)
			new_ammo = 0;

		// Remove ammo from original owener
		SetWeaponAmmo(client, ammotype, new_ammo);
	}

	SDKHook(weapon, SDKHook_TouchPost, OnWeaponPickup);
}

WeaponDropPost(client, weapon)
{
	if(!IsValidEdict(weapon))
		return;

	decl String:classname[30];
	if(!GetEntityClassname(weapon, classname, sizeof(classname)))
		return; // Can't get class name

	if(!IsWeaponDroppable(classname))
		return;

	if(GetEntProp(weapon, Prop_Data, "m_bInReload"))
		return;

	new ammotype = GetAmmoType(weapon);
	new ammo = GetWeaponAmmo(client, ammotype);

	#if DEBUG > 0
	PrintToServer("%N (%d) dropped weapon: %s with %d ammo", client, client, classname, ammo);
	#endif

	// Store ammo as secondary on weapon since it isn't used for anything
	SetEntProp(weapon, Prop_Data, "m_iSecondaryAmmoCount", ammo);

	DataPack pack;
	CreateDataTimer(0.1, timer_DropWeapon, pack);

	// Pass data to timer
	pack.WriteCell(client);
	pack.WriteCell(weapon);
	pack.WriteCell(ammotype);
	pack.WriteCell(ammo);
}

bool IsWeaponDroppable(String:classname[])
{
	new i;

	for(i = 0; i < sizeof(weapon_blacklist); i++)
	{
		if(StrEqual(classname, weapon_blacklist[i]))
		{
			return false;
		}
	}

	return true;
}
