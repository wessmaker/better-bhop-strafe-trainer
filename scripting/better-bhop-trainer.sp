#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <clientprefs>

#pragma newdecls required

#define TRAINER_TICK_INTERVAL 7	// This could be dymanicly controlled by the client

FLOAT g_fClientLastAngle[MAXPLAYERS + 1] = 0;
Handle g_hStrafeTrainerCookie;

int g_iClientTickCount[MAXPLAYERS + 1];
float g_fClientGains[MAXPLAYERS + 1][TRAINER_TICK_INTERVAL];
bool g_bStrafeTrainer[MAXPLAYERS + 1] = {false, ...};

public Plugin myinfo = 
{
	name = "better bhop strafetrainer",
	author = "Wessmaker",
	description = "A better bhop strafe trainer",
	version = "0.1",
	url = "https://github.com/wessmaker/better-bhop-trainer"
};


public void OnPluginStart()
{	
	Engine g_Game = GetEngineVersion();
	if(g_Game != Engine_CSGO && g_Game != Engine_CSS)
	{
		SetFailState("Wrong engine found! This plugin is for CSGO/CSS only.");	
	}
	RegConsoleCmd("sm_strafetrainer", Command_StrafeTrainer, "Toggles the Strafe trainer.");
	g_hStrafeTrainerCookie = RegClientCookie("strafetrainer_enabled", "strafetrainer_enabled", CookieAccess_Protected);
	for(int i = 1; i <= MaxClients; i++)
	{
		if(AreClientCookiesCached(i))
		{
			OnClientCookiesCached(i);
		}
	}
}


public Action Command_StrafeTrainer(int client, int args)
{
	if (client != 0)
	{
		g_bStrafeTrainer[client] = !g_bStrafeTrainer[client];
		SetClientCookieBool(client, g_hStrafeTrainerCookie, g_bStrafeTrainer[client]);
		ReplyToCommand(client, "[SM] Strafe Trainer %s!", g_bStrafeTrainer[client] ? "enabled" : "disabled");
	}
	else
	{
		ReplyToCommand(client, "[SM] Invalid client!");
	}
	return Plugin_Handled;
}


float GetNormalizedAngle(float angle)
{
	float newAngle = angle;
	while (newAngle <= -180.0) newAngle += 360.0;
	while (newAngle > 180.0) newAngle -= 360.0;
	return newAngle;
}


float GetClientVelocity(int client)
{
	float vecVelocity[2];
	vecVelocity[0] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[0]");
	vecVelocity[1] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[1]");
	return SquareRoot(vecVelocity[0] * vecVelocity[0] + vecVelocity[1] * vecVelocity[1]);
}


public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (g_bStrafeTrainer[client] && (GetEntityMoveType(client) == MOVETYPE_NOCLIP) || (GetEntityMoveType(client) == MOVETYPE_LADDER))
		return Plugin_Continue; // dont run when disabled
	
	int avgGain = 0;
	if (g_iClientTickCount[client] < TRAINER_TICK_INTERVAL)
	{
		// Calculating client's horizontal angle difference from last tick DIVIDED by perfect angle for given speed for given tick 
		// Simply: Δangle / perfAngle
		g_fClientGains[client][g_iClientTickCount[client]] = 
			FloatAbs(GetNormalizedAngle(g_fClientLastAngle[client] - angles[1])) / GetPerfectStrafeAngle(GetClientVelocity(client));
		g_iClientTickCount[client]++;		// Increment client's tick count	
		g_fClientLastAngle[client] = angles[1];	// Capture client's last angle
		return Plugin_Continue;			// Break out of the function
	} 

	float gainSum = 0.0;
	for (int i = 0; i < TRAINER_TICK_INTERVAL; i++)
	{
		gainSum += g_fClientGains[client][i];
		g_fClientGains[client][i] = 0.0;
	}
	int avgGain = RoundFloat(gainSum / TRAINER_TICK_INTERVAL);
	g_iClientTickCount[client] = 0;	

	RenderGainSlider(avgGain); // Render classic gain slider on screen
}


void RenderGainSlider(int gain)
{
	char gainSliderStr[32];
	int maxLength = sizeof(gainSliderStr);
	if (gain && gain <= 100)
	{
		int spaceCount = RoundFloat(gain * 2 / 3);
		for (int i = 0; i <= spaceCount + 1; i++)
		{
			FormatEx(gainSliderStr, maxLength, "%s ", gainSliderStr);
		}
		FormatEx(gainSliderStr, maxLength, "%s|", gainSliderStr);
		for (int i = 0; i <= (21 - spaceCount); i++)
		{
			FormatEx(gainSliderStr, maxLength, "%s ", gainSliderStr);
		}
	}
	else
	{
		Format(gainSliderStr, maxLength, "%s", percentage < 1.0 ? "|                   " : "                    |");
	}


	char sMessage[256];
	Format(sMessage, sizeof(sMessage), "%d%", avgGain);
	Format(sMessage, sizeof(sMessage), "%s\n  ════^════  ", sMessage);	//This could and should be cached
	Format(sMessage, sizeof(sMessage), "%s\n %s ", sMessage, gainSliderStr);
	Format(sMessage, sizeof(sMessage), "%s\n  ════^════  ", sMessage);
	
	Handle hText = CreateHudSynchronizer();
	if(hText != INVALID_HANDLE)
	{
		int rgb[3] = GetGainRGB(avgGain);
		SetHudTextParams(-1.0, 0.2, 0.1, rgb[0], rgb[1], rgb[2], 255, 0, 0.0, 0.0, 0.1); //This could have customisation for position
		ShowSyncHudText(client, hText, sMessage);
		CloseHandle(hText);
	}
}


int[] GetGainRGB(int percentage)
{
	if (percentage > 95.0) return {0, 255, 0};	// Green
	else if (percentage > 90) return {128, 255, 0}; // Yellow-Green
	else if (percentage < 75) return {255, 255, 0}; // Yellow
	else if (percentage < 50) return {255, 128, 0};	// Orange
	else return {255, 0, 0};			// Red
}


float GetPerfectStrafeAngle(float speed)
{
	return RadToDeg(ArcTangent(30 / speed));
}


stock bool GetClientCookieBool(int client, Handle cookie)
{
	char sValue[8];
	GetClientCookie(client, g_hStrafeTrainerCookie, sValue, sizeof(sValue));
	return (sValue[0] != '\0' && StringToInt(sValue));
}


stock void SetClientCookieBool(int client, Handle cookie, bool value)
{
	char sValue[8];
	IntToString(value, sValue, sizeof(sValue));
	SetClientCookie(client, cookie, sValue);
}

public void OnClientDisconnect(int client)
{
	g_bStrafeTrainer[client] = false;
}

public void OnClientCookiesCached(int client)
{
	g_bStrafeTrainer[client] = GetClientCookieBool(client, g_hStrafeTrainerCookie);
}