#pragma semicolon 1

#include <sourcemod>
#include <morecolors>
#include <batstore>

#pragma newdecls required

#define MAJOR_REVISION	"0"
#define MINOR_REVISION	"1"
#define STABLE_REVISION	"0"
#define PLUGIN_VERSION MAJOR_REVISION..."."...MINOR_REVISION..."."...STABLE_REVISION

#define FAR_FUTURE		100000000.0
#define MAX_SOUND_LENGTH	80
#define MAX_MODEL_LENGTH	128
#define MAX_MATERIAL_LENGTH	128
#define MAX_ENTITY_LENGTH	48
#define MAX_EFFECT_LENGTH	48
#define MAX_ATTACHMENT_LENGTH	48
#define MAX_ICON_LENGTH		48
#define MAX_INFO_LENGTH		128
#define HEX_OR_DEC_LENGTH	12
#define MAX_ATTRIBUTE_LENGTH	256
#define MAX_CONDITION_LENGTH	256
#define MAX_CLASSNAME_LENGTH	64
#define MAX_COOKIE_BYTE		6
#define MAX_COOKIE_BYTES	42
#define MAX_COOKIE_LENGTH	((MAX_COOKIE_BYTE+1)*MAX_COOKIE_BYTES)
#define MAX_ITEM_LENGTH		48
#define MAX_DESC_LENGTH		256
#define MAX_TITLE_LENGTH	192
#define MAX_NUM_LENGTH		5
#define VOID_ARG		-1

ConVar CashKill;
ConVar CashWin;
ConVar CashTeamScore;
ConVar CashScore;
ConVar CashEntity;

public Plugin myinfo =
{
	name		=	"The Bat Store: Generic Events",
	author		=	"Batfoxkid",
	description	=	"Generic game events for gaining credits",
	version		=	PLUGIN_VERSION
};

public void OnPluginStart()
{
	HookEventEx("player_death", OnDeath);
	CashKill = CreateConVar("batstore_cash_kill", "0", "Amount gained on a player kill.");

	HookEventEx("round_end", OnRoundEnd);
	CashWin = CreateConVar("batstore_cash_win", "0", "Amount gained on a player/team win.");

	HookEventEx("team_score", OnTeamScore);
	CashTeamScore = CreateConVar("batstore_cash_team_score", "0.0", "Ratio of team score gained to cash.");

	HookEventEx("player_score", OnScore);
	CashScore = CreateConVar("batstore_cash_score", "0.0", "Ratio of score gained to cash.");

	HookEventEx("entity_killed", OnKill);
	CashEntity = CreateConVar("batstore_cash_entity_kill", "0", "Amount gained on an entity kill.");

	AutoExecConfig(true, "BatStore_Generic");
}

/*
	Player Kill
*/
public void OnDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client) || IsFakeClient(client))
		return;

	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if(client!=attacker && IsValidClient(attacker))
		AddCash(attacker, CashKill.IntValue);
}

/*
	Win
*/
public void OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	int winner = event.GetInt("winner");
	int client = GetClientOfUserId(winner);
	if(IsValidClient(client))
	{
		AddCash(client, CashWin.IntValue);
		return;
	}

	for(client=1; client<=MaxClients; client++)
	{
		if(IsValidClient(client) && GetClientTeam(client)==winner)
			AddCash(client, CashWin.IntValue);
	}
}

/*
	Team Score
*/
public void OnTeamScore(Event event, const char[] name, bool dontBroadcast)
{
	float ratio = CashTeamScore.FloatValue;
	if(!ratio)
		return;

	int team = event.GetInt("teamid");
	if(team<0 || team>MAXPLAYERS)
		return;

	int score = event.GetInt("score");
	static int lastScore[MAXPLAYERS+1];
	if(score <= lastScore[team])
		return;

	int changedScore = RoundFloat((score-lastScore[team])*ratio);
	for(int client=1; client<=MaxClients; client++)
	{
		if(IsValidClient(client) && GetClientTeam(client)==team)
			AddCash(client, changedScore);
	}
	lastScore[team] = score;
}

/*
	Player Score
*/
public void OnScore(Event event, const char[] name, bool dontBroadcast)
{
	float ratio = CashScore.FloatValue;
	if(!ratio)
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client))
		return;

	int score = event.GetInt("score");
	static int lastScore[MAXPLAYERS+1];
	if(score <= lastScore[client])
		return;

	AddCash(client, RoundFloat((score-lastScore[client])*ratio));
	lastScore[client] = score;
}

/*
	Entity Kill
*/
public void OnKill(Event event, const char[] name, bool dontBroadcast)
{
	int client = event.GetInt("entindex_attacker");
	if(IsValidClient(client))
		AddCash(client, CashEntity.IntValue);
}

stock bool IsValidClient(int client, bool replaycheck=true)
{
	if(client<=0 || client>MaxClients)
		return false;

	if(!IsClientInGame(client))
		return false;

	if(replaycheck && (IsClientSourceTV(client) || IsClientReplay(client)))
		return false;

	return true;
}


stock void AddCash(int client, int amount)
{
	if(amount)
		BatStore_Cash(client, amount);
}

#file "Bat Store: Generic Events"
