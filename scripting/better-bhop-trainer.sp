#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <clientprefs>

#pragma newdecls required

#define GAIN_CALCULATION_INTERVAL 10

/** 
 * 1.302 was found to be number close enough without using specific formula
 * When sv_airaccelerate 1000, cl_yawspeed 118.45, +right and pressing W & D these are prestrafing gains with perf angle of 1.302:
 * gain: 100.072990, speed 289.944793
 * gain: 100.073066, speed 289.944793
 * gain: 100.072921, speed 289.944793
 * gain: 100.073097, speed 289.944824
 * gain: 100.072746, speed 289.944763
*/
#define PERFECT_PRESTRAFE_ANGLE 1.302

float g_fClientLastAngle[MAXPLAYERS + 1];
Handle g_hStrafeTrainerCookie;

int g_iClientTicks[MAXPLAYERS + 1];
float g_fClientGainSum[MAXPLAYERS + 1];
bool g_bClientTrainerEnabled[MAXPLAYERS + 1] = {false, ...};

int g_iGainExcellent = 85;
int g_iGainGood = 70;
int g_iGainBad = 60;

public Plugin myinfo = 
{
	name = "better bhop strafe trainer",
	author = "Wessmaker",
	description = "A better bhop strafe trainer",
	version = "0.1",
	url = "https://github.com/wessmaker/better-bhop-trainer"
};



public void OnPluginStart()
{	
	EngineVersion g_Game = GetEngineVersion();
	if(g_Game != Engine_CSGO && g_Game != Engine_CSS)
	{
		SetFailState("Wrong engine found! This plugin is for CSGO/CSS only.");	
	}
	RegConsoleCmd("sm_strafetrainer", Command_StrafeTrainer, "Toggles the strafe trainer.");
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
		g_bClientTrainerEnabled[client] = !g_bClientTrainerEnabled[client];
		SetClientCookieBool(client, g_hStrafeTrainerCookie, g_bClientTrainerEnabled[client]);
		ReplyToCommand(client, "[SM] Strafe Trainer %s!", g_bClientTrainerEnabled[client] ? "enabled" : "disabled");
	}
	else ReplyToCommand(client, "[SM] Invalid client!");
	return Plugin_Handled;
}

float GetNormalizedAngle(float angle)
{
	float newAngle = angle;
	while (newAngle <= -180.0) newAngle += 360.0;
	while (newAngle > 180.0) newAngle -= 360.0;
	return newAngle;
}

float GetVelocity(int client)
{
	float vecVelocity[2];
	vecVelocity[0] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[0]");
	vecVelocity[1] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[1]");
	return SquareRoot(vecVelocity[0] * vecVelocity[0] + vecVelocity[1] * vecVelocity[1]);
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if(!g_bClientTrainerEnabled[client])
	{
		return Plugin_Continue;  // Plugin is disabled for given client 
	}
	if ((GetEntityMoveType(client) == MOVETYPE_NOCLIP) || (GetEntityMoveType(client) == MOVETYPE_LADDER))
	{
		return Plugin_Continue;
	}

	float currentGain = 0.0;

	// Calculating client's horizontal angle difference from last tick DIVIDED by perfect angle for given speed for given tick 
	// Simply: Δangle / perfAngle
	if(GetEntityFlags(client) & FL_ONGROUND) currentGain = FloatAbs(GetNormalizedAngle(g_fClientLastAngle[client] - angles[1])) / PERFECT_PRESTRAFE_ANGLE * 100;
	else currentGain = FloatAbs(GetNormalizedAngle(g_fClientLastAngle[client] - angles[1])) / GetPerfectStrafeAngle(GetVelocity(client)) * 100;
	

	if (g_iClientTicks[client] < GAIN_CALCULATION_INTERVAL)
	{
		g_fClientGainSum[client] += currentGain;
		g_iClientTicks[client]++;		// Increment client's tick count	
		g_fClientLastAngle[client] = angles[1];	// Capture client's last angle
	} 
	else
	{
		DrawStrafeTarget(RoundFloat(g_fClientGainSum / GAIN_CALCULATION_INTERVAL), GetVelocity(client), GetAngleDiff(angles[1], g_fClientLastAngle[client]), client);
		DrawGainSlider(RoundFloat(g_fClientGainSum / GAIN_CALCULATION_INTERVAL), client);  // Render classic gain slider on screen using average gain
		g_fClientGainSum[client] = 0.0;
		g_iClientTicks[client] = 0;	// Reset client's tick count
	}
}	

void DrawStrafeTarget(int gain, float velocity, float angleDiff, int client)
{
	float x;
	float targetPosMultiplier = FloatAbs(angleDiff / GetPerfectStrafeAngle(velocity));
	char sMessage[4];
	
	if(angleDiff > 0) x = 0.25 * targetPosMultiplier + 0.25;	//Left
	else if (angleDiff < 0)	x = 0.75 - (0.25 * targetPosMultiplier);//Right

	Format(sMessage, sizeof(sMessage), "| |");
	Handle hText = CreateHudSynchronizer();
	float perfAngle = GetPerfectStrafeAngle(velocity);
	if(hText != INVALID_HANDLE && x)
	{
		int rgb[3];
		if (g_iGainExcellent <= gain <= 200 - g_iGainExcellent) rgb = {0, 255, 255};	// Cyan
		else if (g_iGainGood <= gain <= 200 - g_iGainGood) rgb = {0, 255, 0}; 		// Green
		else if(g_iGainBad <= gain <= 200 - g_iGainBad) rgb = {255, 0, 0};		// Red
		else rgb = {127, 127, 127};							// Gray	

		SetHudTextParams(x, -1.0, 0.1, 255, 127, 0, 255, 0, 0.0, 0.0, 0.05);
		ShowSyncHudText(client, hText, sMessage);
		CloseHandle(hText);
	}
}

void DrawGainSlider(int gain, int client)
{
	char gainSliderStr[32];
	int maxLength = sizeof(gainSliderStr);
	if (50 <= gain <= 150)
	{
		int spaceCount = RoundFloat((float(gain) - 50) / 5);
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
		// Draw slider at max or min
		Format(gainSliderStr, maxLength, "%s", gain > 150 ? "                   |" : "|                   ");
	}

	char sMessage[256];
	Format(sMessage, sizeof(sMessage), "%i%%%", gain);
	Format(sMessage, sizeof(sMessage), "%s\n  ════^════  ", sMessage);
	Format(sMessage, sizeof(sMessage), "%s\n %s ", sMessage, gainSliderStr);
	Format(sMessage, sizeof(sMessage), "%s\n  ════^════  ", sMessage);
	
	Handle hText = CreateHudSynchronizer();
	if(hText != INVALID_HANDLE)
	{
		int rgb[3];
		if (g_iGainExcellent <= gain <= 200 - g_iGainExcellent) rgb = {0, 255, 255};	// Cyan
		else if (g_iGainGood <= gain <= 200 - g_iGainGood) rgb = {0, 255, 0}; 		// Green
		else if(g_iGainBad <= gain <= 200 - g_iGainBad) rgb = {255, 0, 0};		// Red
		else rgb = {127, 127, 127};							// Gray	

		SetHudTextParams(-1.0, 0.2, 0.08, rgb[0], rgb[1], rgb[2], 255, 0, 0.0, 0.05, 0.05); //This could have customisation for position
		ShowSyncHudText(client, hText, sMessage);
		CloseHandle(hText);
	}
}


//Ty shavit
float GetAngleDiff(float current, float previous)
{
	float diff = current - previous;
	return diff - 360.0 * RoundToFloor((diff + 180.0) / 360.0);
}


float GetPerfectStrafeAngle(float velocity)
{
	//30 is the maximium wish_speed in source engine
	return RadToDeg(ArcTangent(30 / velocity));
}

stock bool GetClientCookieBool(int client)
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
	g_bClientTrainerEnabled[client] = false;
}

public void OnClientCookiesCached(int client)
{
	g_bClientTrainerEnabled[client] = GetClientCookieBool(client);
}