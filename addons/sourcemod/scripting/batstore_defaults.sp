#pragma semicolon 1

#include <sourcemod>
#include <morecolors>
#include <batstore>

#undef REQUIRE_PLUGIN
#tryinclude <tVip>
#define REQUIRE_PLUGIN

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

#define ITEM_TRAIL	"trail"
enum struct TrailEnum
{
	char Path[MAX_MATERIAL_LENGTH];
	int Color[4];
	float Width;
	int Precache;
	int Entity;

	int Setup(const char[] material, float width, int color[4])
	{
		this.Width = width;
		this.Color[0] = color[0];
		this.Color[1] = color[1];
		this.Color[2] = color[2];
		this.Color[3] = color[3];
		strcopy(this.Path, MAX_MATERIAL_LENGTH, material);
		this.Precache = PrecacheModel(material);
		if(!this.Precache)
			this.Path[0] = 0;

		return this.Precache;
	}

	void Clear()
	{
		this.Path[0] = 0;
	}
}
TrailEnum Trail[MAXPLAYERS+1];
int TrailOwner[2048];

#if defined _tVip_included
#define ITEM_TVIP	"tvip"
#endif

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
	#if defined ITEM_TRAIL
	item.GetString(ITEM_TRAIL, buffer, MAX_MATERIAL_PATH);
	if(buffer[0])
	{
		if(equipped)
		{
			Trail[client].Clear();
			return Item_Off;
		}

		if(!IsPlayerAlive(client))
		{
			SPrintToChat("You must be alive to equip this!");
			return Item_None;
		}

		static int color[4];
		item.GetColor4("color", color);
		Trail[client].Setup(buffer, item.GetFloat("width", 10.0), color);
		RequestFrame(Trail_Create, GetClientUserId(client));
		return Item_On;
	}
	#endif

	#if defined ITEM_TVIP
	item.GetString(ITEM_TVIP, buffer, MAX_MATERIAL_PATH)
	if(buffer[0])
	{
		if(CheckCommandAccess(client, "batstore_donator", ADMFLAG_RESERVATION, true))
		{
			SPrintToClient(client, "You already have donator status!");
			return Item_None;
		}

		if(GetFeatureStatus(FeatureType_Native, "tVip_GrantVip") != FeatureStatus_Available)
		{
			if(CheckCommandAccess(client, "batstore_dev", ADMFLAG_RCON))
			{
				item.GetString("plugin", buffer, MAX_MATERIAL_PATH);
				SPrintToClient(client, "%s can't find tVip natives!", buffer);
			}
			else
			{
				SPrintToClient(client, "This can't be used right now!");
			}
			return Item_None;
		}

		tVip_GrantVip(client, 0, item.GetFloat("duration", 60.0), 1);
		return Item_Used;
	}
	#endif

	SPrintToClient(client, "This item has no effect!", name);
	return Item_None;
}

// Trail Events

public void Trail_Create(int userid)
{
	int client = GetClientOfUserId(userid);
	if(!IsValidClient(client))
		return;

	if(!Trail[client].Path[0])
		return;

	if(GameType == Engine_CSGO)
	{
		if(!Trail[client].Entity || !IsValidEdict(Trail[client].Entity))
		{
			Trail[client].Entity = CreateEntityByName("env_sprite");
			DispatchKeyValue(Trail[client].Entity, "classname", "env_sprite");
			DispatchKeyValue(Trail[client].Entity, "spawnflags", "1");
			DispatchKeyValue(Trail[client].Entity, "scale", "0.0");
			DispatchKeyValue(Trail[client].Entity, "rendermode", "10");
			DispatchKeyValue(Trail[client].Entity, "rendercolor", "255 255 255 0");
			DispatchKeyValue(Trail[client].Entity, "model", Trail[client].Precache);
			DispatchSpawn(Trail[client].Entity);
			Trail_Attach(Trail[client].Entity, client);
			SDKHook(entity, SDKHook_SetTransmit, Trail_Transmit);
		}

		int color[4];
		color[0] = Trail[client].Color[0];
		color[1] = Trail[client].Color[1];
		color[2] = Trail[client].Color[2];
		color[3] = Trail[client].Color[3];
		TE_SetupBeamFollow(Trail[client].Entity, Trail[client].Precache, 0, 0.8, Trail[client].Width, Trail[client].Width, 10, color);
		TE_SendToAll();
		return;
	}

	Trail[client].Entity  = CreateEntityByName("env_spritetrail");
	SetEntPropFloat(Trail[client].Entity, Prop_Send, "m_flTextureRes", 0.05);

	char temp[17];
	FormatEx(temp, sizeof(temp), "%i %i %i %i", Trail[client].Color[0], Trail[client].Color[1], Trail[client].Color[2], Trail[client].Color[3]);
	DispatchKeyValue(Trail[client].Entity, "renderamt", "255");
	DispatchKeyValue(Trail[client].Entity, "rendercolor", temp);
	DispatchKeyValue(Trail[client].Entity, "lifetime", "0.8");
	DispatchKeyValue(Trail[client].Entity, "rendermode", "5");
	DispatchKeyValue(Trail[client].Entity, "spritename", Trail[client].Path);

	FloatToString(Trail[client].Width, temp, sizeof(temp));
	DispatchKeyValue(Trail[client].Entity, "startwidth", temp);
	DispatchKeyValue(Trail[client].Entity, "endwidth", temp);

	DispatchSpawn(Trail[client].Entity);
	Trail_Attach(Trail[client].Entity, client);

	SDKHook(entity, SDKHook_SetTransmit, Trail_Transmit);
	TrailOwner[entity] = client;
}

public void Trail_Remove(int client)
{
	if(Trail[client].Entity && IsValidEdict(Trail[client].Entity))
	{
		TrailOwner[Trail[client].Entity] = 0;
		static char classname[64];
		GetEdictClassname(Trail[client].Entity, classname);
		if(StrEqual("env_spritetrail", classname))
		{
			SDKUnhook(Trail[client].Entity, SDKHook_SetTransmit, Trail_Transmit);
			AcceptEntityInput(Trail[client].Entity, "Kill");
		}
	}
	Trail[client].Entity = 0;
}

public void Trail_Attach(int entity, int client)
{
	static float org[3], ang[3];
	static float temp[3] = {0.0, 90.0, 0.0};
	static float pos[3] = {0.0, 0.0, 5.0};
	GetEntPropVector(client, Prop_Data, "m_angAbsRotation", ang);
	SetEntPropVector(client, Prop_Data, "m_angAbsRotation", tmp);
	GetClientAbsOrigin(client, org);
	AddVectors(org, pos, org);
	TeleportEntity(entity, org, temp, NULL_VECTOR);
	SetVariantString("!activator");
	AcceptEntityInput(entity, "SetParent", client, entity);
	SetEntPropVector(client, Prop_Data, "m_angAbsRotation", ang);
}

public Action Trail_Transmit(int entity, int client)
{
	if(!IsValidClient(TrailOwner[entity]))
		return Plugin_Handled;

	if(!IsPlayerAlive(TrailOwner[entity]))
		return Plugin_Handled;

	if(GameType != Engine_TF2)
		return Plugin_Continue;

	return (TF2_GetClientTeam(TrailOwner[entity])!=TF2_GetClientTeam(client) && (TF2_IsPlayerInCondition(TrailOwner[entity], TFCond_Cloaked) || TF2_IsPlayerInCondition(TrailOwner[entity], TFCond_Stealthed))) ? Plugin_Handled : Plugin_Continue;
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

#file "Bat Store: Defaults"
