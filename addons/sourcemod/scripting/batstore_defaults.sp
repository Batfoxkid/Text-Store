#pragma semicolon 1

#include <sourcemod>
#include <morecolors>
#include <batstore>

#undef REQUIRE_EXTENSIONS
#include <tf2_stocks>
#define REQUIRE_EXTENSIONS

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

EngineVersion GameType;
float Delay[MAXPLAYERS+1];

// SourceMod Events

public Plugin myinfo =
{
	name		=	"The Text Store: Defaults",
	author		=	"Batfoxkid",
	description	=	"Default store items",
	version		=	PLUGIN_VERSION
};

/*public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
}*/

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
	}
}

// Stocks

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

// Modules

#include "batstore/trails.sp"
#include "batstore/tvip.sp"
#include "batstore/tf2/ff2.sp"

// Store Events

public ItemResult BatStore_Item(int client, bool equipped, KeyValues item, const char[] name, int &count)
{
	float engineTime = GetEngineTime();
	if(Delay[client] > engineTime)
	{
		SPrintToChat("Please wait...");
		return Item_None;
	}
	Delay[client] = engineTime+2.5;

	static char buffer[MAX_MATERIAL_PATH];
	item.GetString("type", buffer, MAX_MATERIAL_PATH);

	#if defined ITEM_TRAIL
	if(StrEqual(buffer, ITEM_TRAIL))
		return Trail_Use(client, equipped, item, name, count);
	#endif

	#if defined ITEM_TVIP
	if(StrEqual(buffer, ITEM_TVIP))
		return tVip_Use(client, equipped, item, name, count);
	#endif

	#if defined ITEM_TF2_FF2
	if(StrEqual(buffer, ITEM_TF2_FF2))
		return FF2_Use(client, equipped, item, name, count);
	#endif

	SPrintToClient(client, "This item has no effect!", name);
	return Item_None;
}

#file "Bat Store: Defaults"
