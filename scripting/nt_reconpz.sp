#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <neotokyo>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = 
{
	name = "NEOTOKYO° Recon PZ",
	author = "soft as HELL",
	description = "Allow Recons to pick up weapon_pz",
	version = "0.1",
	url = ""
}

float g_fLastWeaponDroppedTime[MAXPLAYERS+1];

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_WeaponDropPost, OnWeaponDrop);

	g_fLastWeaponDroppedTime[client] = 0.0;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(!IsValidEdict(entity) || !StrEqual(classname, "weapon_pz"))
		return;

	// StartTouch would be better but it doesn't let you pick it up again after dropping it below and not moving
	SDKHook(entity, SDKHook_TouchPost, OnWeaponTouch);
}

public void OnWeaponTouch(int weapon, int client)
{
	if(!IsValidClient(client) || !IsPlayerAlive(client))
		return;

	if(GetPlayerClass(client) != CLASS_RECON)
		return; // Only Recons aren't allowed to pick it up

	if(GetGameTime() - g_fLastWeaponDroppedTime[client] < 1.0)
		return; // Just dropped a PZ

	// Get current weapon from target slot
	int currentweapon = GetPlayerWeaponSlot(client, SLOT_PRIMARY);

	if(IsValidEdict(currentweapon))
		return; // Already have a weapon
	
	// Equip it
	EquipPlayerWeapon(client, weapon);
}

public void OnWeaponDrop(int client, int weapon)
{
	if(!IsValidEdict(weapon))
		return;

	char classname[32];
	if(!GetEntityClassname(weapon, classname, sizeof(classname)))
		return; 

	if(!StrEqual(classname, "weapon_pz"))
		return;

	g_fLastWeaponDroppedTime[client] = GetGameTime();
}
