#include <sourcemod>
#include <zombiereloaded>

public Plugin myinfo =
{
	name = "Boost Watch",
	author = "Vauff",
	description = "Sends a warning message to admins when a suspected zombie boost takes place",
	version = "1.1",
	url = "https://github.com/Vauff/BoostWatch"
};

ConVar minDamage;
ConVar delay;
int nextIndex = 0;
int gameTimes[5];
int damagedIDs[5];
int attackerIDs[5];

public void OnPluginStart()
{
	minDamage = CreateConVar("sm_boostwatch_mindamage", "200", "The minimum amount of damage to a zombie needed to generate a boost warning");
	delay = CreateConVar("sm_boostwatch_delay", "15", "How many seconds after getting boosted can a zombie still trip the warning by infecting someone");
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("round_start", Event_RoundStart);
}

public Action Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	if (event.GetInt("dmg_health") >= minDamage.IntValue && event.GetInt("hitgroup") == 1)
	{
		char weapon[64];
		event.GetString("weapon", weapon, sizeof(weapon));

		if (StrEqual(weapon, "awp") || StrEqual(weapon, "deagle"))
		{
			gameTimes[nextIndex] = GetTime();
			damagedIDs[nextIndex] = event.GetInt("userid");
			attackerIDs[nextIndex] = event.GetInt("attacker");
			nextIndex++;

			if (nextIndex == 5)
				nextIndex = 0;
		}
	}
}

public ZR_OnClientInfected(client, attacker, bool:motherInfect, bool:respawnOverride, bool:respawn)
{
	int index = -1;
	int boostedID;
	int boosterID;

	for (int i = 0; i < 5; i++)
	{
		if (attacker == GetClientOfUserId(damagedIDs[i]) && gameTimes[i] > GetTime() - delay.IntValue)
		{
			index = i;
			boostedID = damagedIDs[i];
			boosterID = attackerIDs[i];
			gameTimes[i] = 0;
			damagedIDs[i] = 0;
			attackerIDs[i] = 0;
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
		gameTimes[i] = 0;
		damagedIDs[i] = 0;
		attackerIDs[i] = 0;
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