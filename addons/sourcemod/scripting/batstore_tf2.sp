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
ConVar CashDestroy;
ConVar CashDestroy2;
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

public Plugin myinfo =
{
	name		=	"The Text Store: TF2 Events",
	author		=	"Batfoxkid",
	description	=	"Generic game events for gaining credits",
	version		=	PLUGIN_VERSION
};

public void OnPluginStart()
{
	HookEvent("player_death", OnDeath);
	CashKill = CreateConVar("batstore_cash_kill", "0", "Amount gained on a player kill.");
	CashAssist = CreateConVar("batstore_cash_assist", "0", "Amount gained on a player assist.");

	HookEvent("teamplay_flag_event", OnFlagCapture);
	CashFlag = CreateConVar("batstore_cash_flag", "0", "Amount gained on a briefcase capture.");

	HookEventEx("ctf_flag_captured", OnFlagTeamCapture);
	CashTeamFlag = CreateConVar("batstore_cash_team_flag", "0", "Amount gained to the team upon capturing the briefcase.");

	HookEvent("teamplay_point_captured", OnPointTeamCapture);
	CashTeamPoint = CreateConVar("batstore_cash_team_point", "0", "Amount gained to the team upon capturing the control point.");

	HookEvent("teamplay_round_win", OnRoundEnd);
	CashTeam = CreateConVar("batstore_cash_team", "0", "Amount gained to the team upon winning the match.");

	HookEvent("teamplay_capture_blocked", OnPointBlock);
	CashDefend = CreateConVar("batstore_cash_block", "0", "Amount gained to a defending player.");

	HookEvent("teamplay_teambalanced_player", OnBalance);
	CashBalance = CreateConVar("batstore_cash_balance", "0", "Amount gained to an autobalanced player.");

	HookEvent("object_destroyed", OnDestroy);
	CashDestroy = CreateConVar("batstore_cash_destroy", "0", "Amount gained on a building kill.");
	CashDestroy2 = CreateConVar("batstore_cash_destroy2", "0", "Amount gained on a building assist.");

	HookEvent("player_extinguished", OnExtinguish);
	CashExtinguish = CreateConVar("batstore_cash_extinguish", "0", "Amount gained on an extinguish.");

	HookEvent("player_teleported", OnTeleport);
	CashTeleport = CreateConVar("batstore_cash_teleport", "0", "Amount gained on a teleport.");

	HookEvent("player_hurt", OnHurt);
	CashDamage = CreateConVar("batstore_cash_damage", "0", "Amount of damage dealt per cash.");

	HookEvent("player_healed", OnHeal);
	HookEvent("building_healed", OnBuildingHeal);
	CashHeal = CreateConVar("batstore_cash_heal", "0", "Amount of damage healed per cash.");

	HookEvent("teamplay_win_panel", OnRoundPanel);
	HookEventEx("arena_win_panel", OnRoundPanel);
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

	HookEvent("pumpkin_lord_killed", OnBoss, EventHookMode_PostNoCopy);
	HookEvent("merasmus_killed", OnBoss, EventHookMode_PostNoCopy);
	HookEvent("eyeball_boss_killed", OnBoss, EventHookMode_PostNoCopy);
	CashBoss = CreateConVar("batstore_cash_halloween", "0", "Amount gained to everyone on a boss killed.");

	HookEventEx("mvm_mission_complete", OnMvM, EventHookMode_PostNoCopy);
	CashMvM = CreateConVar("batstore_cash_mvm", "0.0", "Ratio of leftover cash kept.");

	HookEvent("player_score_changed", OnScore);
	CashScore = CreateConVar("batstore_cash_score", "0.0", "Ratio of score gained to cash.");

	AutoExecConfig(true, "BatStore_TF2");
}

/*
	Kill
	Kill Assist
*/
public void OnDeath(Event event, const char[] name, bool dontBroadcast)
{
	int flags = event.GetInt("death_flags");
	if(flags & TF_DEATHFLAG_DEADRINGER)
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client) || IsFakeClient(client))
		return;

	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if(client==attacker || !IsValidClient(attacker) || IsFakeClient(attacker))
		return;

	AddCash(attacker, CashKill.IntValue);
	client = GetClientOfUserId(event.GetInt("assister"));
	if(IsValidClient(client))
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
		case TF_FLAGEVENT_CAPTURED:
		{
			AddCash(client, CashFlag.IntValue);
		}
		case TF_FLAGEVENT_DEFENDED:
		{
			int victim = event.GetInt("carrier");
			if(IsValidClient(victim) && !IsFakeClient(victim))
				AddCash(client, CashDefend.IntValue);
		}
	}
}

/*
	Team Flag Capture
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

/*
	Point Capture
*/
public void OnPointTeamCapture(Event event, const char[] name, bool dontBroadcast)
{
	int team = event.GetInt("team");
	if(team!=2 && team!=3)
		return;

	for(int client=1; client<=MaxClients; client++)
	{
		if(IsValidClient(client) && GetClientTeam(client)==team)
			AddCash(client, CashTeamPoint.IntValue);
	}
}

/*
	Round Win
*/
public void OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	int team = event.GetInt("team");
	if(team!=2 && team!=3)
		return;

	for(int client=1; client<=MaxClients; client++)
	{
		if(IsValidClient(client) && GetClientTeam(client)==team)
			AddCash(client, CashTeam.IntValue);
	}
}

/*
	Objective Defend
*/
public void OnPointBlock(Event event, const char[] name, bool dontBroadcast)
{
	int client = event.GetInt("victim");
	if(!IsValidClient(client) || IsFakeClient(client))
		return;

	client = event.GetInt("blocker");
	if(IsValidClient(client))
		AddCash(client, CashDefend.IntValue);
}

/*
	Autobalance
*/
public void OnBalance(Event event, const char[] name, bool dontBroadcast)
{
	int client = event.GetInt("player");
	if(IsValidClient(client))
		AddCash(client, CashBalance.IntValue);
}

/*
	Building Destroyed
*/
public void OnDestroy(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client) || IsFakeClient(client))
		return;

	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if(client==attacker || !IsValidClient(attacker) || IsFakeClient(attacker))
		return;

	AddCash(attacker, CashDestroy.IntValue);
	client = GetClientOfUserId(event.GetInt("assister"));
	if(IsValidClient(client))
		AddCash(client, CashDestroy2.IntValue);
}

/*
	Extinguish
*/
public void OnExtinguish(Event event, const char[] name, bool dontBroadcast)
{
	int client = event.GetInt("victim");
	if(!IsValidClient(client) || IsFakeClient(client))
		return;

	client = event.GetInt("healer");
	if(IsValidClient(client))
		AddCash(client, CashExtinguish.IntValue);
}

/*
	Teleport
*/
public void OnTeleport(Event event, const char[] name, bool dontBroadcast)
{
	if(event.GetFloat("dist") < 400)
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client) || IsFakeClient(client))
		return;

	client = GetClientOfUserId(event.GetInt("builderid"));
	if(IsValidClient(client))
		AddCash(client, CashTeleport.IntValue);
}

/*
	Damage
*/
public void OnHurt(Event event, const char[] name, bool dontBroadcast)
{
	int value = CashDamage.IntValue;
	if(value < 1)
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client) || IsFakeClient(client))
		return;

	client = GetClientOfUserId(event.GetInt("attacker"));
	if(!IsValidClient(client))
		return;

	static int damage[MAXPLAYERS+1];
	damage[client] += event.GetInt("damageamount");
	int cash;
	while(damage[client] >= value)
	{
		cash++;
		damage[client] -= value;
	}
	AddCash(client, cash);
}

/*
	Healing
*/
public void OnHeal(Event event, const char[] name, bool dontBroadcast)
{
	int value = CashHeal.IntValue;
	if(value < 1)
		return;

	int client = GetClientOfUserId(event.GetInt("patient"));
	if(!IsValidClient(client) || IsFakeClient(client))
		return;

	client = GetClientOfUserId(event.GetInt("healer"));
	if(!IsValidClient(client))
		return;

	static int healing[MAXPLAYERS+1];
	healing[client] += event.GetInt("amount");
	int cash;
	while(healing[client] >= value)
	{
		cash++;
		healing[client] -= value;
	}
	AddCash(client, cash);
}

/*
	Healing
*/
public void OnBuildingHeal(Event event, const char[] name, bool dontBroadcast)
{
	int value = CashHeal.IntValue;
	if(value < 1)
		return;

	int client = GetClientOfUserId(event.GetInt("healer"));
	if(!IsValidClient(client))
		return;

	static int healing[MAXPLAYERS+1];
	healing[client] += event.GetInt("amount");
	int cash;
	while(healing[client] >= value)
	{
		cash++;
		healing[client] -= value;
	}
	AddCash(client, cash);
}

/*
	MVPs
*/
public void OnRoundPanel(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("player_1"));
	if(IsValidClient(client))
		AddCash(client, CashMvp1.IntValue);

	client = GetClientOfUserId(event.GetInt("player_2"));
	if(IsValidClient(client))
		AddCash(client, CashMvp2.IntValue);

	client = GetClientOfUserId(event.GetInt("player_3"));
	if(IsValidClient(client))
		AddCash(client, CashMvp3.IntValue);
}

/*
	Stun
*/
public void OnStun(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));
	if(!IsValidClient(client) || IsFakeClient(client))
		return;

	client = GetClientOfUserId(event.GetInt("stunner"));
	if(IsValidClient(client))
		AddCash(client, CashStun.IntValue);
}

/*
	Stun
*/
public void OnEyeball(Event event, const char[] name, bool dontBroadcast)
{
	int client = event.GetInt("player_entindex");
	if(IsValidClient(client))
		AddCash(client, CashStun.IntValue);
}

/*
	Jarate
*/
public void OnJarate(Event event, const char[] name, bool dontBroadcast)
{
	int client = event.GetInt("victim_entindex");
	if(!IsValidClient(client) || IsFakeClient(client))
		return;

	client = event.GetInt("thrower_entindex");
	if(IsValidClient(client))
		AddCash(client, CashJarate.IntValue);
}

/*
	Full Charged Kill
*/
public void OnMedic(Event event, const char[] name, bool dontBroadcast)
{
	if(!event.GetBool("charged"))
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client) || IsFakeClient(client))
		return;

	client = GetClientOfUserId(event.GetInt("attacker"));
	if(IsValidClient(client))
		AddCash(client, CashMedic.IntValue);
}

/*
	Deflect
*/
public void OnDeflect(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("ownerid"));
	if(!IsValidClient(client) || IsFakeClient(client))
		return;

	client = GetClientOfUserId(event.GetInt("userid"));
	if(IsValidClient(client))
		AddCash(client, CashAirblast.IntValue);
}

/*
	Boss Death
*/
public void OnBoss(Event event, const char[] name, bool dontBroadcast)
{
	for(int client=1; client<=MaxClients; client++)
	{
		if(IsValidClient(client))
			AddCash(client, CashBoss.IntValue);
	}
}

/*
	MvM Gameover
*/
public void OnMvM(Event event, const char[] name, bool dontBroadcast)
{
	for(int client=1; client<=MaxClients; client++)
	{
		if(IsValidClient(client) && !IsFakeClient(client))
			AddCash(client, RoundFloat(GetEntProp(client, Prop_Send, "m_nCurrency")*CashMvM.FloatValue));
	}
}

/*
	Score
*/
public void OnScore(Event event, const char[] name, bool dontBroadcast)
{
	int client = event.GetInt("player");
	if(IsValidClient(client))
		AddCash(client, RoundFloat(event.GetInt("delta")*CashScore.FloatValue));
}

stock bool IsValidClient(int client, bool replaycheck=true)
{
	if(client<=0 || client>MaxClients)
		return false;

	if(!IsClientInGame(client))
		return false;

	if(GetEntProp(client, Prop_Send, "m_bIsCoaching"))
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

#file "Text Store: TF2 Events"
