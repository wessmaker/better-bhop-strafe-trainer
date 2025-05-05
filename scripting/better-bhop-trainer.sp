#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <clientprefs>

#pragma newdecls required

#define GAIN_CALCULATION_INTERVAL 9

//Ty YvngxChrig for supplying this magic number on SJ discord
#define PERFECT_PRESTRAFE_ANGLE 1.18446555905

enum TrainerMode 
{
	CLASSIC = 1,
	SLIDER_UPPER = 2,
	SLIDER_LOWER = 3,
	TARGET_UPPER = 4,
	TARGET_MIDDLE = 5
}

Handle g_hTainerEnabledCookie;
Handle g_hTrainerModeCookie;

bool g_bClientTrainerEnabled[MAXPLAYERS + 1] = {false, ...};
bool g_bClientTrainerMode[MAXPLAYERS + 1] = {CLASSIC, ...};

float g_fClientLastAngle[MAXPLAYERS + 1];
int g_iClientTicks[MAXPLAYERS + 1];
float g_fClientGainSum[MAXPLAYERS + 1];

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
	g_hTainerEnabledCookie = RegClientCookie("trainer_enabled", "trainer_enabled", CookieAccess_Protected);
	g_hTrainerModeCookie = RegClientCookie("strafetrainer_mode", "strafetrainer_mode", CookieAccess_Protected);
}

public void OnClientCookiesCached(int client)
{
	char sValue[8];
	GetClientCookie(client, g_hTainerEnabledCookie, sValue, sizeof(sValue));
	if(StringToInt(sValue)) g_bClientTrainerEnabled = StringToInt(sValue);

	GetClientCookie(client, g_hTrainerModeCookie, sValue, sizeof(sValue));
	if(StringToInt(sValue)) g_hTrainerModeCookie = StringToInt(sValue);

}

public Action Command_StrafeTrainer(int client, int args)
{
	if (client != 0)
	{
		g_bClientTrainerEnabled[client] = !g_bClientTrainerEnabled[client];
		SetClientCookie(client, g_hTainerEnabledCookie, g_bClientTrainerEnabled[client]);
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
		DrawTrainerHUD(RoundFloat(g_fClientGainSum[client] / (g_iClientTicks[client] + 1)), GetAngleDiff(angles[1], g_fClientLastAngle[client]), client);  // Render classic gain slider on screen using average gain
		g_fClientGainSum[client] = 0.0;
		g_iClientTicks[client] = 0;	// Reset client's tick count
	}
}	




void DrawTrainerHUD(int gain, float angleDiff, int client)
{
	char trainerStr[32];
	int maxLength = sizeof(trainerStr);
	int spaceCount = RoundFloat((float(gain) - 50) / 5);
	if(g_bClientTrainerMode == CLASSIC) // Slider from left to right
	{
		if (50 <= gain <= 150)
		{
			for (int i = 0; i <= spaceCount + 1; i++)
			{
				FormatEx(trainerStr, maxLength, "%s ", trainerStr);
			}
			FormatEx(trainerStr, maxLength, "%s<>", trainerStr);
			for (int i = 0; i <= (21 - spaceCount); i++)
			{
				FormatEx(trainerStr, maxLength, "%s ", trainerStr);
			}
		}
		else FormatEx(trainerStr, maxLength, "%s", gain > 150 ? "                   |" : "|                   ");
	}
	else	// Slider or target from the opposite direction of turning
	{
		char targetOrSliderStr[2] = (g_bClientTrainerMode == SLIDER_UPPER || g_bClientTrainerMode == SLIDER_LOWER) ? "|" : "<>";
		if (50 <= gain <= 150)
		{
			if(angleDiff > 0) 	//Turning left
			{
				for (int i = 0; i <= (targetOrSliderStr == "|" ? 21 : 20) - spaceCount; i++)
				{
					FormatEx(trainerStr, maxLength, "%s ", trainerStr);
				}
				FormatEx(trainerStr, maxLength, "%s%s", trainerStr, targetOrSliderStr);	// Insert "|" or <>
				for (int i = 0; i <= spaceCount + (targetOrSliderStr == "|" ? 1 : 0); i++)
				{
					FormatEx(trainerStr, maxLength, "%s ", trainerStr);
				}
			}
			else if (angleDiff < 0)	//Turning right
			{
				for (int i = 0; i <= spaceCount + (targetOrSliderStr == "|" ? 1 : 0); i++)
				{
					FormatEx(trainerStr, maxLength, "%s ", trainerStr);
				}
				FormatEx(trainerStr, maxLength, "%s%s", trainerStr, targetOrSliderStr);	// Insert "|" or "<>"
				for (int i = 0; i <= (targetOrSliderStr == "|" ? 21 : 20); i++)
				{
					FormatEx(trainerStr, maxLength, "%s ", trainerStr);
				}
			}
		}
		else
		{	//Turning right with too low gain or turning left with too high gain
			if((angleDiff < 0 && gain < 50) || (angleDiff > 0 && gain > 150)) 	FormatEx(trainerStr, maxLength, "%s",  (g_bClientTrainerMode == SLIDER_UPPER || g_bClientTrainerMode == SLIDER_LOWER) ? "|                   " : "<>                  ");
			//Turning left with too low gain or turning right with too high gain
			else if ((angleDiff > 0 && gain < 50) || (angleDiff < 0 && gain > 150)) FormatEx(trainerStr, maxLength, "%s",  (g_bClientTrainerMode == SLIDER_UPPER || g_bClientTrainerMode == SLIDER_LOWER) ? "                   |" : "                  <>");
		} 
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

		SetHudTextParams(-1.0, 0.2, 0.09, rgb[0], rgb[1], rgb[2], 255, 0, 0.0, 0.0, 0.09);
		ShowSyncHudText(client, hText, sMessage);
		CloseHandle(hText);
	}
}


//Stoled from shavit's timer code 
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



stock void SetClientCookieBool(int client, Handle cookie, bool value)
{
	char sValue[8];
	IntToString(value, sValue, sizeof(sValue));
}

public void OnClientDisconnect(int client)
{
	g_bClientTrainerEnabled[client] = false;
}

