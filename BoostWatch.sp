#include <sourcemod>
#include <zombiereloaded>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name = "Boost Watch",
	author = "Vauff",
	description = "Sends a warning message to admins when a suspected zombie boost takes place",
	version = "1.2.1",
	url = "https://github.com/Vauff/BoostWatch"
};

ConVar g_MinDamage;
ConVar g_Delay;
int g_NextIndex = 0;
int g_GameTimes[5];
int g_DamagedIDs[5];
int g_AttackerIDs[5];

public void OnPluginStart()
{
	g_MinDamage = CreateConVar("sm_boostwatch_mindamage", "200", "The minimum amount of damage to a zombie needed to generate a boost warning");
	g_Delay = CreateConVar("sm_boostwatch_delay", "15", "How many seconds after getting boosted can a zombie still trip the warning by infecting someone");
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("round_start", Event_RoundStart);
}

public Action Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	if (event.GetInt("dmg_health") >= g_MinDamage.IntValue && event.GetInt("hitgroup") == 1)
	{
		char weapon[64];
		event.GetString("weapon", weapon, sizeof(weapon));

		if (StrEqual(weapon, "awp") || StrEqual(weapon, "deagle"))
		{
			g_GameTimes[g_NextIndex] = GetTime();
			g_DamagedIDs[g_NextIndex] = event.GetInt("userid");
			g_AttackerIDs[g_NextIndex] = event.GetInt("attacker");
			g_NextIndex++;

			if (g_NextIndex == 5)
				g_NextIndex = 0;
		}
	}
}

public int ZR_OnClientInfected(int client, int attacker, bool motherInfect, bool respawnOverride, bool respawn)
{
	int index = -1;
	int boostedID;
	int boosterID;

	for (int i = 0; i < 5; i++)
	{
		if (attacker == GetClientOfUserId(g_DamagedIDs[i]) && g_GameTimes[i] > GetTime() - g_Delay.IntValue && client != GetClientOfUserId(g_AttackerIDs[i]))
		{
			index = i;
			boostedID = g_DamagedIDs[i];
			boosterID = g_AttackerIDs[i];
			g_GameTimes[i] = 0;
			g_DamagedIDs[i] = 0;
			g_AttackerIDs[i] = 0;
			break;
		}
	}

	if (index != -1)
	{
		for (int c = 1; c <= MaxClients; c++)
		{
			if (CheckCommandAccess(c, "", ADMFLAG_SLAY))
			{
				char boostedName[64];
				char boostedSteamID[32];
				char boosterName[64];
				char boosterSteamID[32];

				if (IsValidClient(GetClientOfUserId(boosterID)) && IsValidClient(GetClientOfUserId(boostedID)))
				{
					GetClientName(GetClientOfUserId(boostedID), boostedName, sizeof(boostedName));
					GetClientAuthId(GetClientOfUserId(boostedID), AuthId_Engine, boostedSteamID, sizeof(boostedSteamID));
					GetClientName(GetClientOfUserId(boosterID), boosterName, sizeof(boosterName));
					GetClientAuthId(GetClientOfUserId(boosterID), AuthId_Engine, boosterSteamID, sizeof(boosterSteamID));
				}

				PrintToChat(c, " \x02[Boost Watch] \x05%s \x04[#%i] \x07infected people after being boosted by \x05%s \x04[#%i]", boostedName, boostedID, boosterName, boosterID);
				LogMessage("%s[#%i][%s] infected people after being boosted by %s[#%i][%s]", boostedName, boostedID, boostedSteamID, boosterName, boosterID, boosterSteamID);
				PrintToConsole(c, "-------------------------- [Boost Watch] --------------------------");
				PrintToConsole(c, "%s[#%i][%s] infected people after being boosted by %s[#%i][%s]", boostedName, boostedID, boostedSteamID, boosterName, boosterID, boosterSteamID);
				PrintToConsole(c, "-------------------------------------------------------------------");
			}
		}
	}
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 0; i < 5; i++)
	{
		g_GameTimes[i] = 0;
		g_DamagedIDs[i] = 0;
		g_AttackerIDs[i] = 0;
	}
}

bool IsValidClient(int client, bool nobots = false)
{
	if (client <= 0 || client > MaxClients || !IsClientConnected(client) || (nobots && IsFakeClient(client)))
	{
		return false;
	}

	return IsClientInGame(client);
}