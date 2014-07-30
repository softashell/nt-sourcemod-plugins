#if defined _neotokyo_included
  #endinput
#endif
#define _neotokyo_included

#define TEAM_NONE		0
#define TEAM_SPECTATOR	1
#define TEAM_JINRAI 	2
#define TEAM_NSF		3

#define AMMO_GRENADE	1
#define AMMO_SMOKE		2
#define AMMO_PRIMARY	4
#define AMMO_SECONDARY	5
#define AMMO_PZ			7
#define AMMO_SHOTGUN	11

#define VISION_NONE		0
#define VISION_NIGHT	2
#define VISION_THERMAL 	3
#define VISION_MOTION	4

stock GetPlayerRank(client)
{
	return GetEntProp(client, Prop_Send, "m_iRank");
}

stock SetPlayerRank(client, rank)
{
	return SetEntProp(client, Prop_Send, "m_iRank", rank);
}

stock GetPlayerStar(client)
{
	return GetEntProp(client, Prop_Send, "m_iStar");
}

stock SetPlayerStar(client, star)
{
	if(star < 0 || star > 5)
		return;

	return SetEntProp(client, Prop_Send, "m_iStar", star);
}

stock SetPlayerClass(client, class)
{
	return SetEntProp(client, Prop_Send, "m_iClassType", class);
}

stock GetPlayerClass(client)
{
	return GetEntProp(client, Prop_Send, "m_iClassType");
}

stock GetAmmoType(weapon)
{
	return GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
}

stock GetWeaponAmmo(client, type)
{
    new offsetAmmo = FindSendPropInfo("CBasePlayer", "m_iAmmo");

    return GetEntData(client, offsetAmmo + (type * 4));
}  

stock SetWeaponAmmo(client, type, ammo)
{
    new offsetAmmo = FindSendPropInfo("CBasePlayer", "m_iAmmo");

    return SetEntData(client, offsetAmmo + (type * 4), ammo);
}

stock GetActiveWeapon(client)
{
	return GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
}

stock GetPlayerVision(client)
{
	return GetEntProp(i, Prop_Send, "m_iVision");
}

stock SetPlayerVision(client, vision)
{
	return SetEntProp(i, Prop_Send, "m_iVision", vision);
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

stock StripPlayerWeapons(client, bool:knife=false)
{
	new String:classname[13];
	new offsetMyWeapons = FindSendPropInfo("CBasePlayer", "m_hMyWeapons");

	for(new weapon; weapon <= 5; weapon++)
	{
			new ent = GetEntDataEnt2(i, offsetMyWeapons + (weapon * 4));

			if(!IsValidEntity(ent))
				continue;

			if(knife)
			{
				if(!GetEdictClassname(wpn, classname, 13))
					continue;

				if(StrEqual(classname, "weapon_knife"))
					continue;
			}

			RemovePlayerItem(client, wpn);
			RemoveEdict(wpn);
	}

	return weapons;
}