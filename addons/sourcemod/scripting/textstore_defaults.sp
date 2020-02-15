#pragma semicolon 1

#include <sourcemod>
#include <morecolors>
#include <textstore>
#include <sdkhooks>

#undef REQUIRE_EXTENSIONS
#include <tf2_stocks>
#define REQUIRE_EXTENSIONS

#undef REQUIRE_PLUGIN
#tryinclude <tVip>
#tryinclude <freak_fortress_2>
#define REQUIRE_PLUGIN

#pragma newdecls required

#define PLUGIN_VERSION "0.1.1"

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

EngineVersion GameType = Engine_Unknown;
float Delay[MAXPLAYERS+1];

// SourceMod Events

public Plugin myinfo =
{
	name		=	"The Text Store: Defaults",
	author		=	"Batfoxkid",
	description	=	"Default store items",
	version		=	PLUGIN_VERSION
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	#if defined _tVip_included
	MarkNativeAsOptional("tVip_GrantVip");
	#endif

	#if defined _FF2_included
	MarkNativeAsOptional("FF2_GetBossIndex");
	MarkNativeAsOptional("FF2_GetBossName");
	MarkNativeAsOptional("FF2_GetBossSpecial");
	MarkNativeAsOptional("FF2_GetQueuePoints");
	MarkNativeAsOptional("FF2_GetSpecialKV");
	MarkNativeAsOptional("FF2_SelectBoss");
	#endif
}

public void OnPluginStart()
{
	char buffer[8];
	GetGameFolderName(buffer, sizeof(buffer));
	if(StrEqual(buffer, "csgo"))
	{
		GameType = Engine_CSGO;
	}
	else if(StrEqual(buffer, "tf"))
	{
		GameType = Engine_TF2;
		HookEventEx("arena_round_start", OnArenaRoundStart, EventHookMode_PostNoCopy);
	}

	LoadTranslations("common.phrases");
}

// Stocks

stock bool IsValidClient(int client, bool replaycheck=true)
{
	if(client<=0 || client>MaxClients)
		return false;

	if(!IsClientInGame(client))
		return false;

	if(GameType==Engine_TF2 && GetEntProp(client, Prop_Send, "m_bIsCoaching"))
		return false;

	if(replaycheck && (IsClientSourceTV(client) || IsClientReplay(client)))
		return false;

	return true;
}

// Modules

#tryinclude "textstore/command.sp"
#tryinclude "textstore/trails.sp"
#tryinclude "textstore/tvip.sp"
#tryinclude "textstore/voting.sp"
#tryinclude "textstore/tf2/ff2.sp"

// Store Events

public ItemResult TextStore_Item(int client, bool equipped, KeyValues item, int index, const char[] name, int &count)
{
	float engineTime = GetEngineTime();
	if(Delay[client] > engineTime)
	{
		SPrintToChat(client, "Please wait...");
		return Item_None;
	}
	Delay[client] = engineTime+2.5;

	static char buffer[MAX_MATERIAL_LENGTH];
	item.GetString("type", buffer, MAX_MATERIAL_LENGTH);

	#if defined ITEM_COMMAND
	if(StrEqual(buffer, ITEM_COMMAND))
		return Command_Use(client, equipped, item, index, name, count);
	#endif

	#if defined ITEM_TRAIL
	if(StrEqual(buffer, ITEM_TRAIL))
		return Trail_Use(client, equipped, item, index, name, count);
	#endif

	#if defined ITEM_TVIP
	if(StrEqual(buffer, ITEM_TVIP))
		return tVip_Use(client, equipped, item, index, name, count);
	#endif

	#if defined ITEM_VOTE
	if(StrEqual(buffer, ITEM_VOTE))
		return Vote_Use(client, equipped, item, index, name, count);
	#endif

	#if defined ITEM_TF2_FF2
	if(StrEqual(buffer, ITEM_TF2_FF2))
		return FF2_Use(client, equipped, item, index, name, count);
	#endif

	SPrintToChat(client, "This item has no effect!");
	return Item_None;
}

public void OnArenaRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	#if defined ITEM_TF2_FF2
	FF2_OnArenaRoundStart();
	#endif
}

#file "Text Store: Defaults"
