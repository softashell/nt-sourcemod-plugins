#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define PLUGIN_VERSION	"0.2"

public Plugin:myinfo =
{
    name = "NEOTOKYO° Noob renamer",
    author = "Soft as HELL",
    description = "Gives random name to NeotokyoNoobs",
    version = PLUGIN_VERSION,
    url = ""
};

new String:Prefixes[][] = {
	"[POD] ",
	"[P0D] ",
	"[P*D] "
};

new String:PlayerNames[][] = {
	"Danny_Devito",
	"Clint_Eastwood",
	"Wesley_Snipes",
	"Joe_Pesci",
	"George_Hamilton",
	"Jackie_Chan",
	"Jet_Li",
	"Jack_Palance",
	"Sean_Penn",
	"John_Malkovich",
	"Bruce_Lee",
	"Nicole_Kidman",
	"Chris_Tucker",
	"Larry_Fishbourne",
	"Samuel_L_Jackson",
	"Keanau_Reeves",
	"Will_Smith",
	"Tommy_Lee_Jones",
	"Woody_Harrelson",
	"Sean_Connery",
	"Harrison_Ford",
	"Jeff_Bridges",
	"Stacy_Keech",
	"George_Clooney",
	"Sylvester_Stallone",
	"Jean_Claude_Van_Damme",
	"Arnold_Schwarzenegger",
	"Kim_Basinger",
	"Tom_Cruise",
	"Robert_Redford",
	"Andrew_Dice_Clay",
	"Jennifer_Anniston",
	"Matt_Damon"
};

public OnPluginStart()
{
	CreateConVar("sm_ntnoobname_version", PLUGIN_VERSION, "NEOTOKYO° Noob renamer version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
}

public OnClientConnected(client)
{
	decl String:name[64];

	GetClientName(client, name, sizeof(name));

	if(StrContains(name, "NeotokyoNoob") != -1)
	{
		decl String:newname[64];

		new prefnum = GetRandomInt(0, sizeof(Prefixes)-1);
		new namenum, count;
		do 
		{
			count++;
			namenum = GetRandomInt(0, sizeof(PlayerNames)-1);

			PrintToServer("Finding name. try #%i", count);

			strcopy(newname, sizeof(newname), PlayerNames[namenum][0]);

			if(count >= sizeof(PlayerNames))
				break;
		} 
		while(IsNameTaken(newname));

		Format(newname, sizeof(newname), "%s%s", Prefixes[prefnum], PlayerNames[namenum]);
		
		ClientCommand(client, "name %s", newname);

		PrintToServer("Renaming %s to %s", name, newname);
	}
}

public bool:IsNameTaken(String:name[64])
{
	decl String:_name[64];

	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i))
		{
			GetClientName(i, _name, sizeof(_name));

			if(StrContains(_name, name) != -1)
			{
				PrintToServer("Name already used (%s, %s)", _name, name);
				return true;
			}
		}
	}

	return false;
}