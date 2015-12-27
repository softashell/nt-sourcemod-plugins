#pragma semicolon 1

#include <sdkhooks>
#include <sdktools>
#include <neotokyo>

#pragma newdecls required

#define DEBUG 0
#define SF_NORESPAWN (1 << 30)

public Plugin myinfo = 
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

#if DEBUG > 0
float g_fLastWeaponUse[MAXPLAYERS+1];
#endif

public void OnPluginStart()
{
	HookEvent("player_death", OnPlayerDeath, EventHookMode_Pre);

	// Hook equp if plugin is restarted
	for(int client = 1; client <= MaxClients; client++)
	{
		if(IsValidClient(client))
			SDKHook(client, SDKHook_WeaponEquip, OnWeaponEquip); 
	}
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_WeaponEquip, OnWeaponEquip); 
}

public Action OnPlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	if(!IsValidClient(client))
		return;

	#if DEBUG > 0
	PrintToServer("%N (%d) dropping weapons on death", client, client);
	#endif

	static int hMyWeapons;

	if (!hMyWeapons && (hMyWeapons = FindSendPropInfo("CBasePlayer", "m_hMyWeapons")) == -1)
	{
		ThrowError("Failed to obtain: \"m_hMyWeapons\"!");
	}

	for(int slot; slot <= 5; slot++)
	{
		int weapon = GetEntDataEnt2(client, hMyWeapons + (slot * 4));

		DropWeapon(client, weapon);
	}
}

public Action OnWeaponPickup(int weapon, int other)
{
	int owner = GetEntPropEnt(weapon, Prop_Data, "m_hOwnerEntity");

	if(other != owner)
		return; // Didn't pick up weapon

	if(!IsPlayerAlive(owner))
		return;

	// Remove current hook
	SDKUnhook(weapon, SDKHook_TouchPost, OnWeaponPickup);

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

public Action OnWeaponEquip(int client, int weapon) 
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

			DropWeapon(client, active_weapon);

			g_bTossHeld[client] = true;
		}
	}
	else 
	{
		g_bTossHeld[client] = false;
	}
	#if DEBUG > 0
	// Does player is pressing +USE button and cooldown for dropped weapons is expired?
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

		if(distance > 108.0) // Around the same distance as ghost pickup
			return; // Too far away

		char classname[30];
		if(!GetEntityClassname(weapon, classname, sizeof(classname)))
			return; // Can't get class name

		if(StrEqual(classname, "weapon_ghost"))
			return; // Let the game deal with it

		// TODO: Deal with ghost weapons created by respawn flag

		int slot = GetWeaponSlot(weapon);

		if((slot == SLOT_MELEE) || (slot == SLOT_GRENADE))
			return; // Not a weapon

		if(GetGameTime() - g_fLastWeaponUse[client] < 0.5)
			return; // Spamming use

		//PrintToChat(client, "use %s - id: %d, slot: %d, distance: %.1f", classname, weapon, slot, distance);

		int currentweapon = GetWeaponFromSlot(client, slot);

		if((currentweapon != -1) && IsValidEdict(currentweapon))
		{
			// Set active weapon
			SetEntPropEnt(client, Prop_Data, "m_hActiveWeapon", currentweapon);

			// Press toss button once
			buttons |= IN_TOSS;

			// Deal with dropped weapon as usual
			DropWeapon(client, currentweapon);
		}

		DataPack pack;
		CreateDataTimer(0.1, TakeWeapon, pack);

		// Pass data to timer
		pack.WriteCell(client);
		pack.WriteCell(weapon);
		pack.WriteCell(slot);

		g_fLastWeaponUse[client] = GetGameTime();

	}
	#endif
}

public Action TakeWeapon(Handle timer, Handle pack)
{
	ResetPack(pack);

	int client = ReadPackCell(pack);
	int weapon = ReadPackCell(pack);
	int slot   = ReadPackCell(pack);

	// Pick up weapon
	AcceptEntityInput(weapon, "use", client, client);

	// Sometimes gets called twice if you stand close enough, but doesn't seem to cause any problems
	OnWeaponPickup(weapon, client);

	// Switch to target slot
	ClientCommand(client, "slot%d", slot+1);
}

void DropWeapon(int client, int weapon)
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
	CreateDataTimer(0.1, DropWeaponPost, pack);

	// Pass data to timer
	pack.WriteCell(client);
	pack.WriteCell(weapon);
	pack.WriteCell(ammotype);
	pack.WriteCell(ammo);
}

public Action DropWeaponPost(Handle timer, Handle pack)
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

	ChangeSpawnFlags(weapon);

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

void ChangeSpawnFlags(int weapon)
{
	// Prepare spawnflags datamap offset
	static int spawnflags;

	// Try to find datamap offset for m_spawnflags property
	if(!spawnflags && (spawnflags = FindDataMapOffs(weapon, "m_spawnflags")) == -1)
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
