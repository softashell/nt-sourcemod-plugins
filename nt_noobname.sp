#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define PLUGIN_VERSION	"0.1"

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

public OnClientAuthorized(client, const String:auth[]) 
{
	decl String:name[64];

	GetClientName(client, name, sizeof(name));

	if(StrContains(name, "NeotokyoNoob") != -1)
	{
		decl String:newname[64];

		Format(newname, sizeof(newname), "%s%s", Prefixes[GetRandomInt(0, sizeof(Prefixes)-1)], PlayerNames[GetRandomInt(0, sizeof(PlayerNames)-1)]);
		
		ClientCommand(client, "name %s", newname);

		PrintToServer("Renaming %s to %s", name, newname);
	}
}