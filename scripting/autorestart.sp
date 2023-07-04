#include <sourcemod>
#include <neotokyo>

#pragma semicolon 1
#pragma newdecls required

ConVar cvarEnabled;
ConVar cvarTime;

public const Plugin myinfo =
{
	name = "AutoRestart",
	author = "MikeJS, soft as HELL",
	description = "Automatically restarts the server when it's empty.",
	version = "1.5.3",
	url = "http://forums.alliedmods.net/showthread.php?t=87291",
}

public void OnPluginStart()
{
	cvarEnabled = CreateConVar("sm_autorestart", "1", "Enable AutoRestart.", _, true, 0.0, true, 1.0);
	cvarTime = CreateConVar("sm_autorestart_interval", "6", "Minimum interval in hours between automatic restarts.", _, true, 1.0, true, 48.0);

	CreateTimer(300.0, CheckRestart, _, TIMER_REPEAT);
}

public Action CheckRestart(Handle timer)
{
	if(!cvarEnabled.BoolValue || IsAnyoneConnected())
	{
		return Plugin_Continue;
	}

	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "data/lastrestart.txt");

	bool read = false;
	int lastRestart = 0;

	File file = OpenFile(path, "r");
	if(file != INVALID_HANDLE)
	{
		read = file.ReadInt32(lastRestart);
		file.Close();
	}

	if(!read)
	{
		// Probably first time starting the plugin
		LogMessage("Couldn't read timestamp from %s", path);
	}

	int currentTime = GetTime();
	int nextRestart = lastRestart + cvarTime.IntValue * 3600;

	// Is it too early to restart?
	if(currentTime < nextRestart && currentTime > lastRestart)
	{
		return Plugin_Continue;
	}

	bool written = false;

	file = OpenFile(path, "w");
	if(file != INVALID_HANDLE)
	{
		// Write the current timestamp
		written = file.WriteInt32(currentTime);
		file.Close();
	}

	// Don't restart endlessly if we can't write the file
	if(!written)
	{
		LogError("Couldn't write timestamp to %s.", path);
		return Plugin_Continue;
	}

	// ｷﾀ━━━━━━(ﾟ∀ﾟ)━━━━━━ !!!!!
	LogMessage("It's time to die !!!!");

	// Doesn't actually restart but crashes the server just like any of the shutdown commands in neotokyo
	// So this will most likely not work unless you have external script to auto start the server if it dies
	ServerCommand("_restart");
	return Plugin_Continue;
}

bool IsAnyoneConnected()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i) && IsClientConnected(i) && !IsFakeClient(i))
		{
			int team = GetClientTeam(i);

			if (team == TEAM_JINRAI || team == TEAM_NSF) {
				return true;
			}
		}
	}

	return false;
}