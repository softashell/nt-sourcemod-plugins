#include <sdkhooks>
#include <sdktools>
#include <neotokyo>

#pragma semicolon 1
#pragma newdecls required

#define DEBUG 1
#define SF_NORESPAWN (1 << 30)
#define EF_NODRAW 32

public Plugin myinfo = 
{
	name = "NEOTOKYO° Weapon Drop Tweaks",
	author = "soft as HELL",
	description = "Drops weapon with ammo and disables ammo pickup",
	version = "0.7.0",
	url = ""
}

char weapon_blacklist[][] = {
	"weapon_knife",
	"weapon_remotedet",
	"weapon_grenade",
	"weapon_smokegrenade",
	"weapon_ghost"
};

float g_fLastWeaponUse[MAXPLAYERS+1], g_fLastWeaponSwap[MAXPLAYERS+1];

public void OnPluginStart()
{
	HookEvent("player_death", OnPlayerDeath, EventHookMode_Pre);

	// Hook again if plugin is restarted
	for(int client = 1; client <= MaxClients; client++)
	{
		if(IsValidClient(client))
		{
			OnClientPutInServer(client);
		}
	}
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_WeaponEquipPost, OnWeaponEquip);
	SDKHook(client, SDKHook_WeaponDropPost, OnWeaponDrop);
}

public Action OnPlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	if(!IsValidClient(client))
		return;

	#if DEBUG > 0
	PrintToServer("%N (%d) dropping weapons on death", client, client);
	#endif
}

public Action OnWeaponTouch(int weapon, int client)
{
	if(!IsValidClient(client) || !IsPlayerAlive(client))
		return Plugin_Continue;

	if(GetGameTime() - g_fLastWeaponSwap[client] < 0.5)
		return Plugin_Handled; // Currently swapping weapons with +use, block touch
	
	return Plugin_Continue;
}

public void OnWeaponEquip(int client, int weapon) 
{ 
	if(!IsValidEdict(weapon) || !IsPlayerAlive(client))
		return;

	// Remove current hook
	SDKUnhook(weapon, SDKHook_StartTouch, OnWeaponTouch);

	char classname[32];
	if(!GetEntityClassname(weapon, classname, sizeof(classname)))
		return; // Can't get class name

	if(!IsWeaponDroppable(classname))
		return; // Don't care if it doesn't have ammo

	int ammotype = GetAmmoType(weapon);
	int current_ammo = GetWeaponAmmo(client, ammotype);
	int ammo = GetEntProp(weapon, Prop_Data, "m_iSecondaryAmmoCount");

	if(ammo != -1)
	{
		// Remove secondary ammo
		SetEntProp(weapon, Prop_Data, "m_iSecondaryAmmoCount", -1);

		// Set the weapons secondary ammo as primary ammo
		SetWeaponAmmo(client, ammotype, current_ammo + ammo);
	}

	#if DEBUG > 0
	PrintToChatAll("%s picked up by %N with %d ammo", classname, client, ammo);
	#endif
}

public void OnWeaponDrop(int client, int weapon)
{
	if(!IsValidEdict(weapon))
		return;

	char classname[32];
	if(!GetEntityClassname(weapon, classname, sizeof(classname)))
		return; // Can't get class name

	if(!IsWeaponDroppable(classname))
		return;

	// Convert index to entity reference
	weapon = EntIndexToEntRef(weapon);

	int ammotype = GetAmmoType(weapon);
	int ammo = GetWeaponAmmo(client, ammotype);

	#if DEBUG > 0
	PrintToServer("%N (%d) dropped weapon: %s with %d ammo", client, client, classname, ammo);
	PrintToChat(client, "%s dropped by %N with %d ammo", classname, client, ammo);
	#endif

	// Store ammo as secondary on weapon since it isn't used for anything
	SetEntProp(weapon, Prop_Data, "m_iSecondaryAmmoCount", ammo);

	// Have to delay spawnflag setting for a bit
	CreateTimer(0.1, ChangeSpawnFlags, weapon);

	if(IsPlayerAlive(client))
	{
		// It's possible to drop a weapon and pick up a new one before ammo has been removed
		// So I'm trying to remove dropped ammo without touching new one
		int current_ammo = GetWeaponAmmo(client, ammotype);
		int new_ammo = current_ammo - ammo;

		if(new_ammo < 0)
			new_ammo = 0;

		// Remove ammo from original owener
		SetWeaponAmmo(client, ammotype, new_ammo);
	}

	SDKHook(weapon, SDKHook_StartTouch, OnWeaponTouch);
}

public Action OnPlayerRunCmd(int client, int &buttons)
{	
	if(buttons & IN_USE)
	{
		// Get the entity a client is aiming at
		int weapon = GetClientAimTarget(client, false);

		// If we found an entity - make sure its valid
		if(!IsValidEdict(weapon))
			return;

		// Retrieve the client's eye position and entity origin vector to compare distance
		float vec1[3], vec2[3], distance;
		GetClientEyePosition(client, vec1);
		GetEntPropVector(weapon, Prop_Send, "m_vecOrigin", vec2);
		distance = GetVectorDistance(vec1, vec2);

		if(distance >= 100.0) // Around the same distance as ghost pickup
			return; // Too far away

		char classname[30];
		if(!GetEntityClassname(weapon, classname, sizeof(classname)))
			return; // Can't get class name

		int slot = GetWeaponSlot(weapon);

		if((slot == SLOT_PRIMARY) || (slot == SLOT_SECONDARY))
		{
			if(GetGameTime() - g_fLastWeaponUse[client] < 1.0)
				return; // Spamming use

			int fEffects = GetEntProp(weapon, Prop_Data, "m_fEffects");
			if(fEffects & EF_NODRAW)
				return; // Not drawn to clients, probably weapon respawn point

			#if DEBUG > 0
			PrintToChat(client, "use %s - id: %d, slot: %d, distance: %.1f", classname, weapon, slot, distance);
			#endif

			if(StrEqual(classname, "weapon_ghost"))
			{
				g_fLastWeaponUse[client] = GetGameTime();

				// Release use so the ghost gets picked up
				buttons &= ~IN_USE;

				return;
			}

			int currentweapon = GetPlayerWeaponSlot(client, slot);

			if((currentweapon != -1) && IsValidEdict(currentweapon))
			{
				// Switch active weapon
				SetEntPropEnt(client, Prop_Data, "m_hActiveWeapon", currentweapon);
				ChangeEdictState(client, FindDataMapInfo(client, "m_hActiveWeapon"));

				// Press toss button once
				buttons |= IN_TOSS; // If only SDKHooks_DropWeapon(client, currentweapon) worked
				
				// Set swap time to block weapon pickup from touch
				g_fLastWeaponSwap[client] = GetGameTime();
			}

			DataPack pack;
			CreateDataTimer(0.1, TakeWeapon, pack);

			// Pass data to timer
			pack.WriteCell(client);
			pack.WriteCell(weapon);

			g_fLastWeaponUse[client] = GetGameTime();
		}
	}
}

public Action TakeWeapon(Handle timer, Handle pack)
{
	ResetPack(pack);

	int client = ReadPackCell(pack);
	int weapon = ReadPackCell(pack);

	// Equip weapon
	EquipPlayerWeapon(client, weapon);

	// Switch to active weapon
	SetEntPropEnt(client, Prop_Data, "m_hActiveWeapon", weapon);
	ChangeEdictState(client, FindDataMapInfo(client, "m_hActiveWeapon"));
}

public Action ChangeSpawnFlags(Handle timer, int weapon)
{
	// Prepare spawnflags datamap offset
	static int spawnflags;

	// Try to find datamap offset for m_spawnflags property
	if(!spawnflags && (spawnflags = FindDataMapInfo(weapon, "m_spawnflags")) == -1)
	{
		ThrowError("Failed to obtain offset: \"m_spawnflags\"!");
	}

	// Remove SF_NORESPAWN flag from m_spawnflags datamap
	SetEntData(weapon, spawnflags, GetEntData(weapon, spawnflags) & ~SF_NORESPAWN);
}

bool IsWeaponDroppable(const char[] classname)
{
	for(int i; i < sizeof(weapon_blacklist); i++)
	{
		if(StrEqual(classname, weapon_blacklist[i]))
		{
			return false;
		}
	}

	return true;
}
