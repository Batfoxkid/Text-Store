#pragma semicolon 1

#include <sourcemod>
#include <morecolors>
#include <batstore>
#include <tf2_stocks>

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
ConVar CashAssist;
ConVar CashFlag;
ConVar CashTeamFlag;
ConVar CashTeamPoint;
ConVar CashTeam;
ConVar CashDefend;
ConVar CashBalance;
ConVar CashDestory;
ConVar CashDestory2;
ConVar CashExtinguish;
ConVar CashTeleport;
ConVar CashDamage;
ConVar CashHeal;
ConVar CashMvp1;
ConVar CashMvp2;
ConVar CashMvp3;
ConVar CashStun;
ConVar CashJarate;
ConVar CashMedic;
ConVar CashAirblast;
ConVar CashBoss;
ConVar CashMvM;
ConVar CashScore;

public void OnPluginStart()
{
	HookEvent("player_death", OnDeath);
	CashKill = CreateConVar("batstore_cash_kill", "0", "Amount gained on a player kill.");
	CashAssist = CreateConVar("batstore_cash_assist", "0", "Amount gained on a player assist.");

	HookEvent("teamplay_flag_event", OnFlagCapture);
	CashFlag = CreateConVar("batstore_cash_flag", "0", "Amount gained on a briefcase capture.");

	HookEvent("ctf_flag_captured", OnFlagTeamCapture);
	CashTeamFlag = CreateConVar("batstore_cash_team_flag", "0", "Amount gained to the team upon capturing the briefcase.");

	HookEvent("teamplay_point_captured", OnPointTeamCapture);
	CashTeamPoint = CreateConVar("batstore_cash_team_point", "0", "Amount gained to the team upon capturing the control point.");

	HookEvent("teamplay_round_win", OnRoundEnd);
	CashTeam = CreateConVar("batstore_cash_team", "0", "Amount gained to the team upon winning the match.");

	HookEvent("teamplay_capture_blocked", OnPointBlock);
	CashDefense = CreateConVar("batstore_cash_block", "0", "Amount gained to a defending player.");

	HookEvent("teamplay_teambalanced_player", OnBalance);
	CashBalance = CreateConVar("batstore_cash_balance", "0", "Amount gained to an autobalanced player.");

	HookEvent("object_destoryed", OnDestory);
	CashDestory = CreateConVar("batstore_cash_destory", "0", "Amount gained on a building kill.");
	CashDestory2 = CreateConVar("batstore_cash_destory2", "0", "Amount gained on a building assist.");

	HookEvent("player_extinguished", OnExtinguish);
	CashExtinguish = CreateConVar("batstore_cash_extinguish", "0", "Amount gained on an extinguish.");

	HookEvent("player_teleported", OnTeleport);
	CashTeleport = CreateConVar("batstore_cash_teleport", "0", "Amount gained on a teleport.");

	HookEvent("player_hurt", OnHurt);
	CashHurt = CreateConVar("batstore_cash_damage", "0", "Amount of damage dealt per cash.");

	HookEvent("player_healed", OnHeal);
	HookEvent("building_healed", OnHeal);
	CashHeal = CreateConVar("batstore_cash_heal", "0", "Amount of damage healed per cash.");

	HookEvent("teamplay_win_panel", OnRoundPanel);
	HookEvent("arena_win_panel", OnRoundPanel);
	CashMvp1 = CreateConVar("batstore_cash_mvp1", "0", "Amount gained to the 1st place MVP.");
	CashMvp2 = CreateConVar("batstore_cash_mvp2", "0", "Amount gained to the 2nd place MVP.");
	CashMvp3 = CreateConVar("batstore_cash_mvp3", "0", "Amount gained to the 3rd place MVP.");

	HookEvent("player_stunned", OnStun);
	HookEvent("eyeball_boss_stunned", OnEyeball);
	CashStun = CreateConVar("batstore_cash_stun", "0", "Amount gained on a stun.");

	HookEvent("player_jarated", OnJarate);
	CashJarate = CreateConVar("batstore_cash_jarate", "0", "Amount gained on a jarate hit.");

	HookEvent("medic_death", OnMedic);
	CashMedic = CreateConVar("batstore_cash_medic", "0", "Amount gained on a fully charged Medic kill.");

	HookEvent("object_deflected", OnDeflect);
	CashAirblast = CreateConVar("batstore_cash_airblast", "0", "Amount gained on an airblast.");

	HookEvent("pumpkin_lord_killed", OnBoss);
	HookEvent("merasmus_killed", OnBoss);
	HookEvent("eyeball_boss_killed", OnBoss);
	CashBoss = CreateConVar("batstore_cash_halloween", "0", "Amount gained to everyone on a boss killed.");

	HookEvent("mvm_mission_complete", OnMvM);
	CashMvM = CreateConVar("batstore_cash_mvm", "0.0", "Ratio of leftover cash kept.");

	HookEvent("player_score_changed", OnScore);
	CashScore = CreateConVar("batstore_cash_score", "0.0", "Ratio of score gained to cash.");
}

/*
	Player Kill
	Player Kill Assist
*/
public void OnDeath(Event event, const char[] name, bool dontBroadcast)
{
	int flags = event.GetInt("death_flags");
	if(flags & TF_DEATHFLAG_DEADRINGER)
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client) || IsFakeClient(client))
		return;

	client = GetClientOfUserId(event.GetInt("attacker"));
	if(!IsValidClient(client) || IsFakeClient(client))
		return;

	AddCash(client, CashKill.IntValue);
	client = GetClientOfUserId(event.GetInt("assister"));
	if(IsValidClient(client) && !IsFakeClient(client))
		AddCash(client, CashAssist.IntValue);
}

/*
	Flag Capture
	Objective Defend
*/
public void OnFlagCapture(Event event, const char[] name, bool dontBroadcast)
{
	int client = event.GetInt("player");
	if(!IsValidClient(client))
		return;

	switch(event.GetInt("eventtype"))
	{
		case 4:
		{
			AddCash(client, CashFlag.IntValue);
		}
		case 2:
		{
			int victim = event.GetInt("carrier");
			if(IsValidClient(victim) && !IsFakeClient(victim))
				AddCash(client, CashDefend.IntValue);
		}
	}
}

/*
	Flag Capture
	Objective Defend
*/
public void OnFlagTeamCapture(Event event, const char[] name, bool dontBroadcast)
{
	int team = event.GetInt("capping_team");
	if(team!=2 && team!=3)
		return;

	for(int client=1; client<=MaxClients; client++)
	{
		if(IsValidClient(client) && GetClientTeam(client)==team)
			AddCash(client, CashTeamFlag.IntValue);
	}
}

stock AddCash(int client, int amount)
{
	if(amount)
		BatStore_Cash(client, amount);
}
