#pragma semicolon 1

#include <sdkhooks>
#include <sdktools>
#include <neotokyo>

#define DEBUG 0
#define SF_NORESPAWN (1 << 30)

public Plugin:myinfo = 
{
	name = "NEOTOKYO° Weapon Drop Tweaks",
	author = "soft as HELL",
	description = "Drops weapon with ammo and disables ammo pickup",
	version = "0.4",
	url = ""
}

char weapon_blacklist[][] = {
	"weapon_knife",
	"weapon_remotedet",
	"weapon_grenade",
	"weapon_smokegrenade",
	"weapon_ghost"
};

bool g_bTossHeld[MAXPLAYERS+1];

public OnPluginStart()
{
	HookEvent("player_death", event_PlayerDeath, EventHookMode_Pre);

	// Hook equp if plugin is restarted
	for(int client = 1; client <= MaxClients; client++)
	{
		if(IsValidClient(client))
			SDKHook(client, SDKHook_WeaponEquip, OnWeaponEquip); 
	}
}

public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_WeaponEquip, OnWeaponEquip); 
}

public Action OnWeaponEquip(client, weapon) 
{ 
	// Blocks ammo pickup from dropped weapons
	return Plugin_Handled;
}

public Action OnPlayerRunCmd(int client, int &buttons)
{	
	if(buttons & IN_TOSS)
	{
		if(g_bTossHeld[client])
		{
			buttons &= ~IN_TOSS; // Weapon only gets dropped on release
		}
		else 
		{
			int active_weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");

			HandleWeaponDrop(client, active_weapon);

			g_bTossHeld[client] = true;
		}
	}
	else 
	{
		g_bTossHeld[client] = false;
	}
}

public Action timer_DropWeaponPost(Handle timer, Handle pack)
{
	ResetPack(pack);

	int client = ReadPackCell(pack);
	int weapon = ReadPackCell(pack);
	int ammotype = ReadPackCell(pack);
	int ammo = ReadPackCell(pack);

	if(!IsValidEdict(weapon))
		return; // Are you trying to tick me again?

	int owner = GetEntPropEnt(weapon, Prop_Data, "m_hOwnerEntity");

	if(owner != -1)
		return;

	#if DEBUG > 0
	char classname[30];
	if(!GetEntityClassname(weapon, classname, sizeof(classname)))
		return; // Can't get class name

	PrintToChat(client, "%s dropped by %N with %d ammo", classname, client, ammo);
	#endif

	// Prepare spawnflags datamap offset
	static spawnflags;

	// Try to find datamap offset for m_spawnflags property
	if(!spawnflags && (spawnflags = FindDataMapOffs(weapon, "m_spawnflags")) == -1)
	{
		ThrowError("Failed to obtain offset: \"m_spawnflags\"!");
	}

	// Remove SF_NORESPAWN flag from m_spawnflags datamap
	SetEntData(weapon, spawnflags, GetEntData(weapon, spawnflags) & ~SF_NORESPAWN);

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

	SDKHook(weapon, SDKHook_TouchPost, OnWeaponPickup);
}

public event_PlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	if(!IsValidClient(client))
		return;

	#if DEBUG > 0
	PrintToServer("%N (%d) dropping weapons on death", client, client);
	#endif

	static hMyWeapons;

	if (!hMyWeapons && (hMyWeapons = FindSendPropInfo("CBasePlayer", "m_hMyWeapons")) == -1)
	{
		ThrowError("Failed to obtain: \"m_hMyWeapons\"!");
	}

	for(int slot; slot <= 5; slot++)
	{
		int weapon = GetEntDataEnt2(client, hMyWeapons + (slot * 4));

		HandleWeaponDrop(client, weapon);
	}
}

public OnWeaponPickup(int weapon, int other)
{
	int owner = GetEntPropEnt(weapon, Prop_Data, "m_hOwnerEntity");

	if(other != owner)
		return; // Didn't pick up weapon

	// Remove current hook
	SDKUnhook(weapon, SDKHook_TouchPost, OnWeaponPickup);

	if(!IsPlayerAlive(owner))
		return;

	int ammotype = GetAmmoType(weapon);
	int current_ammo = GetWeaponAmmo(owner, ammotype);
	int ammo = GetEntProp(weapon, Prop_Data, "m_iSecondaryAmmoCount");

	// Remove secondary ammo
	SetEntProp(weapon, Prop_Data, "m_iSecondaryAmmoCount", 0);

	// Set the weapons secondary ammo as primary ammo
	SetWeaponAmmo(owner, ammotype, current_ammo + ammo);

	#if DEBUG > 0
	char classname[30];
	if(!GetEntityClassname(weapon, classname, sizeof(classname)))
		return; // Can't get class name

	PrintToChatAll("%s picked up by %N with %d ammo", classname, owner, ammo);
	#endif
}

HandleWeaponDrop(int client, int weapon)
{
	if(!IsValidEdict(weapon))
		return;

	char classname[30];
	if(!GetEntityClassname(weapon, classname, sizeof(classname)))
		return; // Can't get class name

	if(!IsWeaponDroppable(classname))
		return;

	if(GetEntProp(weapon, Prop_Data, "m_bInReload"))
		return;

	// Convert index to entity reference
	weapon = EntIndexToEntRef(weapon);

	int ammotype = GetAmmoType(weapon);
	int ammo = GetWeaponAmmo(client, ammotype);

	#if DEBUG > 0
	PrintToServer("%N (%d) dropped weapon: %s with %d ammo", client, client, classname, ammo);
	#endif

	// Store ammo as secondary on weapon since it isn't used for anything
	SetEntProp(weapon, Prop_Data, "m_iSecondaryAmmoCount", ammo);

	DataPack pack;
	CreateDataTimer(0.1, timer_DropWeaponPost, pack);

	// Pass data to timer
	pack.WriteCell(client);
	pack.WriteCell(weapon);
	pack.WriteCell(ammotype);
	pack.WriteCell(ammo);
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
