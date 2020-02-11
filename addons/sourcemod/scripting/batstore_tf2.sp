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

ConVar CashOnKill;
ConVar CashOnFlag;
ConVar CashOnTeamFlag;
ConVar CashOnPoint;
ConVar CashOnTeamPoint;
ConVar CashOnTeam;
ConVar CashOnDefend;
ConVar CashOnBalance;

public void OnPluginStart()
{
	/// ....
}
