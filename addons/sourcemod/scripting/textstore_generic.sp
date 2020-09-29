#pragma semicolon 1

#include <sourcemod>
#include <morecolors>
#include <textstore>

#pragma newdecls required

#define PLUGIN_VERSION	"0.1.0"

ConVar CashKill;
ConVar CashWin;
ConVar CashTeamScore;
ConVar CashScore;
ConVar CashEntity;

public Plugin myinfo =
{
	name		=	"The Text Store: Generic Events",
	author		=	"Batfoxkid",
	description	=	"Generic game events for gaining credits",
	version		=	PLUGIN_VERSION
};

public void OnPluginStart()
{
	HookEventEx("player_death", OnDeath);
	CashKill = CreateConVar("textstore_cash_kill", "0", "Amount gained on a player kill.");

	HookEventEx("round_end", OnRoundEnd);
	CashWin = CreateConVar("textstore_cash_win", "0", "Amount gained on a player/team win.");

	HookEventEx("team_score", OnTeamScore);
	CashTeamScore = CreateConVar("textstore_cash_team_score", "0.0", "Ratio of team score gained to cash.");

	HookEventEx("player_score", OnScore);
	CashScore = CreateConVar("textstore_cash_score", "0.0", "Ratio of score gained to cash.");

	HookEventEx("entity_killed", OnKill);
	CashEntity = CreateConVar("textstore_cash_entity_kill", "0", "Amount gained on an entity kill.");

	AutoExecConfig(true, "TextStore_Generic");
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
		TextStore_Cash(client, amount);
}

#file "Text Store: Generic Events"
