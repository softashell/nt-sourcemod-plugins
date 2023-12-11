#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <dhooks>
#include <neotokyo>

#pragma semicolon 1
#pragma newdecls required

#define DEBUG 0
#define EF_NODRAW 32

#define NEO_MAX_PLAYERS 32

// set to true if you want to enable taking weapons with +use (f by default)
#define ENABLE_USE false

public Plugin myinfo =
{
	name = "NEOTOKYO° Weapon Drop Tweaks",
	author = "soft as HELL",
	description = "Drops weapon with ammo and disables ammo pickup",
	version = "0.8.4",
	url = ""
}

char weapon_blacklist[][] = {
	"weapon_knife",
	"weapon_remotedet",
	"weapon_grenade",
	"weapon_smokegrenade",
	"weapon_ghost"
};

#if ENABLE_USE
float g_fLastWeaponUse[NEO_MAX_PLAYERS+1];
#endif
float g_fLastWeaponSwap[NEO_MAX_PLAYERS+1];

ConVar g_cNoDespawn;

DynamicHook g_hDh = null;

public void OnPluginStart()
{
	g_hDh = new DynamicHook(202, HookType_Entity, ReturnType_Void,
		ThisPointer_CBaseEntity);
	if (g_hDh == null)
	{
		SetFailState("Failed to create dynamic hook");
	}

	HookEvent("player_death", OnPlayerDeath, EventHookMode_Pre);

	// Hook again if plugin is restarted
	for(int client = 1; client <= MaxClients; client++)
	{
		if(IsValidClient(client))
		{
			OnClientPutInServer(client);
		}
	}

	#if DEBUG > 0
	RegConsoleCmd("sm_wipe", CommandWipe);
	#endif

	// Clean up dead weapons
	CreateTimer(60.0, WipeDeadWeapons, _, TIMER_REPEAT);

	g_cNoDespawn = CreateConVar("sm_ntdrop_nodespawn", "1",
		"Whether to disallow weapons to de-spawn after 30 seconds (as is NT default)",
		_, true, 0.0, true, 1.0);
}

public void OnClientPutInServer(int client)
{
	#if DEBUG > 0
	PrintToServer("OnClientPutInServer: Hooking and resetting use and swap time for %N (%d)", client, client);
	#endif

	SDKHook(client, SDKHook_WeaponEquipPost, OnWeaponEquip);
	SDKHook(client, SDKHook_WeaponDropPost, OnWeaponDrop);

	#if ENABLE_USE
	g_fLastWeaponUse[client] = 0.0;
	#endif
	g_fLastWeaponSwap[client] = 0.0;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (IsWeapon(entity))
	{
		if (g_hDh.HookEntity(Hook_Pre, entity, SetPickupTouch) == INVALID_HOOK_ID)
		{
			SetFailState("Failed to hook %d (%s)", entity, classname);
		}
	}
}

public void OnPlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	if(!IsValidClient(client))
		return;

	#if DEBUG > 0
	PrintToServer("[nt_drop] %N (%d) dropping all weapons on death", client, client);
	#endif
}

public Action OnWeaponTouch(int weapon, int client)
{
	if(!IsValidClient(client) || !IsPlayerAlive(client))
		return Plugin_Continue;

	if(GetGameTime() - g_fLastWeaponSwap[client] < 0.5)
		return Plugin_Handled; // Currently swapping weapons with +use, block touch

	char classname[32];
	if(!GetEntityClassname(weapon, classname, sizeof(classname)))
		return Plugin_Continue; // Can't get class name

	// Get current weapon from target slot
	int slot = GetWeaponSlot(weapon);
	int currentweapon = GetPlayerWeaponSlot(client, slot);

	if(IsValidEdict(currentweapon))
	{
		char classname2[32];
		if(GetEntityClassname(currentweapon, classname2, 32) && StrEqual(classname, classname2))
		{
			#if DEBUG > 2
			PrintToChat(client, "OnWeaponTouch: Blocking picking up %s [%d] ammo from %s [%d]", classname, currentweapon, classname2, weapon);
			#endif

			return Plugin_Handled;
		}
	}

	return Plugin_Continue;
}

public void OnWeaponEquip(int client, int weapon)
{
	if(!IsValidEdict(weapon) || !IsPlayerAlive(client))
		return;

	char classname[32];
	if(!GetEntityClassname(weapon, classname, sizeof(classname)))
		return; // Can't get class name

	if(!IsWeaponDroppable(classname))
		return; // Don't care if it doesn't have ammo

	int ammotype = GetAmmoType(weapon);
	int current_ammo = GetWeaponAmmo(client, ammotype);
	int ammo = GetEntProp(weapon, Prop_Data, "m_iSecondaryAmmoCount");

	if(ammo < 0)
		return; // Weapon wasn't dropped

	// Remove secondary ammo
	SetEntProp(weapon, Prop_Data, "m_iSecondaryAmmoCount", -1);

	// Set the weapons secondary ammo as primary ammo
	SetWeaponAmmo(client, ammotype, current_ammo + ammo);

	#if DEBUG > 0
	PrintToServer("[nt_drop] %N (%d) picked up %d %s with %d ammo", client, client, weapon, classname, ammo);
	PrintToChat(client, "picked up %d %s with %d ammo", weapon, classname, ammo);
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

	int ammotype = GetAmmoType(weapon);
	int ammo = GetWeaponAmmo(client, ammotype);

	#if DEBUG > 0
	PrintToServer("[nt_drop] %N (%d) dropped weapon: %d %s with %d ammo", client, client, weapon, classname, ammo);
	PrintToChat(client, "dropped %d %s with %d ammo", weapon, classname, ammo);
	#endif

	// Store ammo as secondary on weapon since it isn't used for anything
	SetEntProp(weapon, Prop_Data, "m_iSecondaryAmmoCount", ammo);

	// Convert index to entity reference
	weapon = EntIndexToEntRef(weapon);

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

	SDKHook(weapon, SDKHook_Touch, OnWeaponTouch);
}

#if ENABLE_USE
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

			#if DEBUG > 0
			PrintToChatAll("[OnPlayerRunCmd] %d %d", client, weapon);
			#endif

			DataPack pack;

			CreateDataTimer(0.1, TakeWeapon, pack);

			// Pass data to timer
			pack.WriteCell(client);
			pack.WriteCell(weapon);

			g_fLastWeaponUse[client] = GetGameTime();
		}
	}
}

public Action TakeWeapon(Handle timer, DataPack pack)
{
	pack.Reset();

	int client = pack.ReadCell();
	int weapon = pack.ReadCell();

	pack.Close();

	#if DEBUG > 0
	PrintToChatAll("[TakeWeapon] %d %d", client, weapon);
	#endif

	if(!IsValidEdict(weapon))
		return;

	int slot = GetWeaponSlot(weapon);
	int currentweapon = GetPlayerWeaponSlot(client, slot);

	if((currentweapon != -1) && IsValidEdict(currentweapon))
	{
		#if DEBUG > 0
		PrintToChatAll("[TakeWeapon] %d can't equip %d because we picked up %d already", client, weapon, currentweapon);
		#endif

		return;
	} else {
		// Equip weapon
		EquipPlayerWeapon(client, weapon);

		// Switch to active weapon
		SetEntPropEnt(client, Prop_Data, "m_hActiveWeapon", weapon);
		ChangeEdictState(client, FindDataMapInfo(client, "m_hActiveWeapon"));
	}
}
#endif

bool IsWeapon(int entity)
{
	return HasEntProp(entity, Prop_Send, "m_iPrimaryAmmoType");
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

// This supercedes CBaseCombatWeapon::SetPickupTouch, only setting the touch
// function, and skipping the SetThink SUB_Remove path.
// In case you're wondering why we're not simply toggling the SF_NORESPAWN
// flag, there's a strange issue here where repeatedly picking up and dropping
// a gun can cause this dataprop state to go out of sync somehow, which results
// in unintended weapon duplication, which can be abused by players.
// Whatever the underlying issue with SF_NORESPAWN here was, leaving that value
// alone and doing some memory magic seems to get what we want, so that's what
// we're doing here.
public MRESReturn SetPickupTouch(int wep)
{
	// If want to prevent this gun from de-spawning from the world after 30 secs,
	// which is the default NT behaviour for guns lying around
	if (g_cNoDespawn.BoolValue)
	{
		// Equivalent of SetTouch(&CBaseCombatWeapon::DefaultTouch)
		StoreToAddress(GetEntityAddress(wep) + view_as<Address>(0x70),
			0x220e28c0, NumberType_Int32);
		return MRES_Supercede;
	}
	return MRES_Ignored;
}

public Action WipeDeadWeapons(Handle timer)
{
	#if DEBUG > 0
	int removed;
	#endif

	char classname[64];

	for (int i = MaxClients+1; i < 2048; i++)
	{
		if (IsValidEntity(i))
		{
			GetEntityClassname(i, classname, sizeof(classname));

			if (StrContains(classname, "weapon_") != -1)
			{
				int fEffects = GetEntProp(i, Prop_Data, "m_fEffects");
				if(fEffects & EF_NODRAW)
				{
					// Player weapons aren't drawn until you have switched to them at least once, avoid removing them by checking for no valid owner
					int owner = GetEntPropEnt(i, Prop_Data, "m_hOwnerEntity");

					if(owner != -1)
						continue;

					AcceptEntityInput(i, "Kill");

					#if DEBUG > 0
					PrintToServer("Removing %d %s", i, classname);
					removed++;
					#endif
				}
			}
		}
	}

	#if DEBUG > 0
	PrintToServer("Removed %d dead weapons", removed);
	#endif

	return Plugin_Continue;
}

#if DEBUG > 0
public Action CommandWipe(int client, int args)
{
	WipeDeadWeapons(INVALID_HANDLE);

	return Plugin_Handled;
}
#endif
