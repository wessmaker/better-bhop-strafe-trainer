#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <clientprefs>

#pragma newdecls required

#define CALCULATION_TICK_INTERVAL 8

//Ty YvngxChrig for supplying this magic number on SJ discord
#define PERFECT_PRESTRAFE_ANGLE 1.18446555905

enum TrainerMode 
{
	CLASSIC,
	SLIDER_UPPER,
	SLIDER_LOWER,
	TARGET_UPPER,
	TARGET_MIDDLE
}

Handle g_hTainerEnabledCookie;
Handle g_hTrainerModeCookie;

bool g_bClientTrainerEnabled[MAXPLAYERS + 1] = {false, ...};
TrainerMode g_bClientTrainerMode[MAXPLAYERS + 1] = {TARGET_UPPER, ...};

float g_fClientLastAngle[MAXPLAYERS + 1];
float g_fClientStrafeSpeedSum[MAXPLAYERS + 1];
int g_iClientTicks[MAXPLAYERS + 1];

const int STRAFE_CUTOFF_SPEED = 50;
const int STRAFE_SPEED_EXCELLENT = 85;
const int STRAFE_SPEED_GOOD = 70;
const int STRAFE_SPEED_BAD = 60;


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
	EngineVersion gameEngine = GetEngineVersion();
	if(!(gameEngine != Engine_CSGO || gameEngine != Engine_CSS))
	{
		SetFailState("Wrong engine found! This plugin is for CSGO/CSS only.");	
	}
	RegConsoleCmd("sm_strafetrainer", Command_StrafeTrainer, "Usage: !strafetrainer [1|2|3|4|5].");
	g_hTainerEnabledCookie = RegClientCookie("trainer_enabled", "trainer_enabled", CookieAccess_Protected);
	g_hTrainerModeCookie = RegClientCookie("strafetrainer_mode", "strafetrainer_mode", CookieAccess_Protected);
}


public void OnClientCookiesCached(int client)
{
	char cookieValue[1];
	int cookieIntValue;
	GetClientCookie(client, g_hTainerEnabledCookie, cookieValue, sizeof(cookieValue));
	g_bClientTrainerEnabled[client] = StringToInt(cookieValue[0]) == 1;

	GetClientCookie(client, g_hTrainerModeCookie, cookieValue, sizeof(cookieValue));
	cookieIntValue = StringToInt(cookieValue[0]);
	g_bClientTrainerMode[client] = 
		cookieIntValue == 1 ? 	CLASSIC 	:
		cookieIntValue == 2 ? 	SLIDER_UPPER 	:
		cookieIntValue == 3 ? 	SLIDER_LOWER 	:
		cookieIntValue == 4 ? 	TARGET_UPPER 	:
		cookieIntValue == 5 ? 	TARGET_MIDDLE 	: 
					CLASSIC;
}


public Action Command_StrafeTrainer(int client, int argCount)
{
	if(argCount > 1)
	{
		ReplyToCommand(client, "[SM] sm_strafetrainer accepts only one argument!");
		return Plugin_Continue;
	}
	if (client == 0) 
	{
		ReplyToCommand(client, "[SM] Strafe trainer not enabled due to invalid client!");
		return Plugin_Handled;
	}

	char valueStr[8];
	GetCmdArgString(valueStr, sizeof(valueStr));
	int valueInt = StringToInt(valueStr);

	if(!g_bClientTrainerEnabled[client] && valueInt == 0)
	{
		ReplyToCommand(client, "To enable strafe trainer add mode as argument to command! \n1 CLASSIC\n2 SLIDER_UPPER\n3 SLIDER_LOWER\n4 TARGET_UPPER\n5 TARGET_MIDDLE");
		return Plugin_Handled;
	}
	else if (valueInt == 0)
	{
		g_bClientTrainerEnabled[client] = false;
		SetClientCookie(client, g_hTainerEnabledCookie, "0");
		ReplyToCommand(client, "[SM] Strafe Trainer disabled! %s", valueStr);
		return Plugin_Handled;
	}
	

	g_bClientTrainerEnabled[client] = true;
	g_bClientTrainerMode[client] = 
		valueInt == 1 ? 	CLASSIC 	:
		valueInt == 2 ? 	SLIDER_UPPER 	:
		valueInt == 3 ? 	SLIDER_LOWER 	:
		valueInt == 4 ? 	TARGET_UPPER 	:
		valueInt == 5 ? 	TARGET_MIDDLE 	: 
					CLASSIC;
	SetClientCookie(client, g_hTrainerModeCookie, valueStr);

	Format(valueStr, sizeof(valueStr), "%c", g_bClientTrainerEnabled[client] ? '1' : '0');
	SetClientCookie(client, g_hTainerEnabledCookie, valueStr);

	ReplyToCommand(client, "[SM] Strafe Trainer enabled! Mode: %s", 
		g_bClientTrainerMode[client] == CLASSIC 	? 	"CLASSIC" 	: 
		g_bClientTrainerMode[client] == SLIDER_UPPER 	? 	"SLIDER_UPPER"	: 
		g_bClientTrainerMode[client] == SLIDER_LOWER 	? 	"SLIDER_LOWER"	: 
		g_bClientTrainerMode[client] == TARGET_UPPER 	? 	"TARGET_UPPER"	: 
		g_bClientTrainerMode[client] == TARGET_MIDDLE 	? 	"TARGET_MIDDLE" : 
							 		"CLASSIC");
	return Plugin_Continue;
}


public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	// Plugin is disabled for given client 
	if(!g_bClientTrainerEnabled[client])
		return Plugin_Continue;  
	if ((GetEntityMoveType(client) == MOVETYPE_NOCLIP) || (GetEntityMoveType(client) == MOVETYPE_LADDER))
		return Plugin_Continue;

	// Calculating client's horizontal angle difference from last tick DIVIDED by perfect angle for given speed for given tick 
	// Simply: Δangle / perfAngle
	float currentStrafeSpeed = 0.0;
	if(GetEntityFlags(client) & FL_ONGROUND) currentStrafeSpeed = FloatAbs(GetNormalizedAngle(g_fClientLastAngle[client] - angles[1])) / PERFECT_PRESTRAFE_ANGLE * 100;
	else currentStrafeSpeed = FloatAbs(GetNormalizedAngle(g_fClientLastAngle[client] - angles[1])) / GetPerfectStrafeAngle(client) * 100;

	if (g_iClientTicks[client] < CALCULATION_TICK_INTERVAL)
	{
		g_fClientStrafeSpeedSum[client] += currentStrafeSpeed;
		g_iClientTicks[client]++;		// Increment client's tick count	
	} 
	else
	{
		DrawTrainerHUD(RoundFloat(g_fClientStrafeSpeedSum[client] / (g_iClientTicks[client])), GetAngleDiff(angles[1], g_fClientLastAngle[client]), client);
		g_fClientStrafeSpeedSum[client] = 0.0;
		g_iClientTicks[client] = 0;	// Reset client's tick count
	}
	g_fClientLastAngle[client] = angles[1];	// Capture client's last angle
}	


void DrawTrainerHUD(int strafeSpeed, float angleDiff, int client)
{	
	char trainerStr[32];
	int maxLength = sizeof(trainerStr);
	int spaceCount = RoundFloat((float(strafeSpeed) - 50) / 5);
	if(g_bClientTrainerMode[client] == CLASSIC) // Slider from left to right
	{
		if (STRAFE_CUTOFF_SPEED <= strafeSpeed <= 100 + STRAFE_CUTOFF_SPEED)
		{
			for (int i = 0; i <= spaceCount + 1; i++)
			{
				FormatEx(trainerStr, maxLength, "%s ", trainerStr);
			}
			FormatEx(trainerStr, maxLength, "%s|", trainerStr);
			for (int i = 0; i <= (22 - spaceCount); i++)
			{
				FormatEx(trainerStr, maxLength, "%s ", trainerStr);
			}
		}
		else FormatEx(trainerStr, maxLength, "%s", strafeSpeed > 150 ? "                   |" : "|                   ");
	}
	else	// Slider or target from the opposite direction of turning
	{
		char targetOrSliderStr[8];
		Format(targetOrSliderStr, sizeof(targetOrSliderStr), "%s ", (g_bClientTrainerMode[client] == SLIDER_UPPER || g_bClientTrainerMode[client] == SLIDER_LOWER) ? "|" : "<>");
		if (STRAFE_CUTOFF_SPEED <= strafeSpeed <= 100 + STRAFE_CUTOFF_SPEED)
		{
			if(angleDiff > 0) 	//Turning left
			{
				for (int i = 0; i <= 20 - spaceCount; i++)
				{
					FormatEx(trainerStr, maxLength, "%s ", trainerStr);
				}
				FormatEx(trainerStr, maxLength, "%s%s", trainerStr, targetOrSliderStr);	// Inserting "|" or "<>"
				for (int i = 0; i <= spaceCount; i++)
				{
					FormatEx(trainerStr, maxLength, "%s ", trainerStr);
				}
			}
			else if (angleDiff < 0)	//Turning right
			{
				for (int i = 0; i <= spaceCount; i++)
				{
					FormatEx(trainerStr, maxLength, "%s ", trainerStr);
				}
				FormatEx(trainerStr, maxLength, "%s%s", trainerStr, targetOrSliderStr);	// Inserting "|" or "<>"
				for (int i = 0; i <= 20 - spaceCount; i++)
				{
					FormatEx(trainerStr, maxLength, "%s ", trainerStr);
				}
			}
		}
		else
		{
			//Turning right with too low strafeSpeed or turning left with too high strafeSpeed -> same slider position
			if((angleDiff < 0 && strafeSpeed < STRAFE_CUTOFF_SPEED) || (angleDiff > 0 && strafeSpeed > 100 + STRAFE_CUTOFF_SPEED)) 	FormatEx(trainerStr, maxLength, "%s",  (g_bClientTrainerMode[client] == SLIDER_UPPER || g_bClientTrainerMode[client] == SLIDER_LOWER) ? "|                   " : "<>                  ");
			//Turning left with too low strafeSpeed or turning right with too high strafeSpeed -> same slider position
			else if ((angleDiff > 0 && strafeSpeed < STRAFE_CUTOFF_SPEED) || (angleDiff < 0 && strafeSpeed > 100 + STRAFE_CUTOFF_SPEED)) FormatEx(trainerStr, maxLength, "%s",  (g_bClientTrainerMode[client] == SLIDER_UPPER || g_bClientTrainerMode[client] == SLIDER_LOWER) ? "                   |" : "                  <>");
		} 
	}

	char sMessage[256];
	FormatEx(sMessage, sizeof(sMessage), "%s\n  ════^════  ", sMessage);
	FormatEx(sMessage, sizeof(sMessage), "%s\n %s", sMessage ,trainerStr);
	FormatEx(sMessage, sizeof(sMessage), "%s\n  ════^════  \n%i%%%%", sMessage, strafeSpeed);
	
	Handle handle = CreateHudSynchronizer();
	if(handle != INVALID_HANDLE)
	{
		int rgb[3];
		if 	(STRAFE_SPEED_EXCELLENT <= strafeSpeed <= 200 - STRAFE_SPEED_EXCELLENT) 	rgb = {0, 255, 255};		// Cyan
		else if (STRAFE_SPEED_GOOD 	 <= strafeSpeed <= 200 - STRAFE_SPEED_GOOD) 		rgb = {0, 255, 0}; 		// Green
		else if	(STRAFE_SPEED_BAD 	 <= strafeSpeed <= 200 - STRAFE_SPEED_BAD) 		rgb = {255, 0, 0};		// Red
		else 											rgb = {127, 127, 127};		// Gray	

		SetHudTextParams(-1.0, 		
			g_bClientTrainerMode[client] == CLASSIC 	|| 
			g_bClientTrainerMode[client] == SLIDER_UPPER 	|| 
			g_bClientTrainerMode[client] == TARGET_UPPER 	? 0.15 : 0.405, 
			0.11, rgb[0], rgb[1], rgb[2], 255, 0, 0.0, 0.0, 0.0);
		ShowSyncHudText(client, handle, sMessage);
		CloseHandle(handle);
	}
}


float GetAngleDiff(float current, float previous) //Stoled from shavit's timer code 
{
	float diff = current - previous;
	return diff - 360.0 * RoundToFloor((diff + 180.0) / 360.0);
}


float GetPerfectStrafeAngle(int client)
{
	float vecVelocity[2];
	vecVelocity[0] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[0]");
	vecVelocity[1] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[1]");

	// Pythagoran to calculate the lenght of velocity vector 
	// Calculate perfect angle with velocity vector lenght and preferred wish_dir vector lenght
	// wish_dir lenght of 30 is hardcoded to source engine
	return RadToDeg(ArcTangent(30 / SquareRoot(vecVelocity[0] * vecVelocity[0] + vecVelocity[1] * vecVelocity[1])));
}


float GetNormalizedAngle(float angle)
{
	float newAngle = angle;
	while (newAngle <= -180.0) 	newAngle += 360.0;
	while (newAngle > 180.0) 	newAngle -= 360.0;
	return newAngle;
}