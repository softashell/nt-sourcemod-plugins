#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <neotokyo>

#define PLUGIN_VERSION	"1.1.0"

char Playlist[][] = {
	"#../soundtrack/101 - annul.mp3",
	"#../soundtrack/102 - tinsoldiers.mp3",
	"#../soundtrack/103 - beacon.mp3",
	"#../soundtrack/104 - imbrium.mp3",
	"#../soundtrack/105 - automata.mp3",
	"#../soundtrack/106 - hiroden 651.mp3",
	"#../soundtrack/109 - mechanism.mp3",
	"#../soundtrack/110 - paperhouse.mp3",
	"#../soundtrack/111 - footprint.mp3",
	"#../soundtrack/112 - out.mp3",
	"#../soundtrack/202 - scrap.mp3",
	"#../soundtrack/207 - carapace.mp3",
	"#../soundtrack/208 - stopgap.mp3",
	"#../soundtrack/209 - radius.mp3",
	"#../soundtrack/210 - rebuild.mp3"
};

bool RadioEnabled[NEO_MAXPLAYERS+1];

public Plugin myinfo = 
{
    name = "NEOTOKYO° Radio",
    author = "Soft as HELL",
    description = "Play original soundtrack in game",
    version = PLUGIN_VERSION,
    url = ""
};

public void OnPluginStart()
{
	CreateConVar("sm_ntradio_version", PLUGIN_VERSION, "NEOTOKYO° Radio Version", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);

	HookEvent("game_round_start", Event_RoundStart, EventHookMode_Post);

	RegConsoleCmd("sm_radio", 	 Cmd_Radio);
	RegConsoleCmd("sm_radiooff", Cmd_Radio);
}

public void OnClientPutInServer(int client)
{
	RadioEnabled[client] = false;
}

public void OnClientDisconnect(int client)
{
	RadioEnabled[client] = false;
}

void Play(int client) {
	if(!IsValidClient(client))
		return;

	int Song = GetRandomInt(0, sizeof(Playlist)-1);

	ClientCommand(client, "play \"%s\"", Playlist[Song][0]);
}

public Action Cmd_Radio(int client, int args)
{
	RadioEnabled[client] = !RadioEnabled[client];

	if(RadioEnabled[client])
	{
		PrintToChat(client, "[SM] You are now listening to NEOTOKYO° radio. Type !radio again to turn it off.");
		Play(client);
	}
	else {
		ClientCommand(client, "play common/null.wav"); //Stop sound
	}

	return Plugin_Handled;
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast){
	for(int i = 1; i <= MaxClients; i++)
		if(IsValidClient(i) && RadioEnabled[i])
			Play(i);

	return Plugin_Continue;
}
