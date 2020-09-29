#if !defined _tf2items_included
	#endinput
#endif

#define ITEM_TF2_ITEMS	"tf2items"

static const char DefaultClasses[] = "soldier pyro heavy";
static const char DefaultClassname[] = "tf_weapon_shotgun";
static const int DefaultIndex = 199;
static const int DefaultSlot = TFWeaponSlot_Secondary;
static ArrayList Loadout[36];

stock ItemResult TF2Items_Use(int client, bool equipped, KeyValues item, int index, const char[] name, int &count)
{
	if(GameType != Engine_TF2)
	{
		if(CheckCommandAccess(client, "textstore_dev", ADMFLAG_RCON))
		{
			SPrintToChat(client, "Incorrect game type for %s", name);
		}
		else
		{
			SPrintToChat(client, "This can't be used right now!");
		}
		return Item_None;
	}

	static char buffer[128];
	item.GetString("class", buffer, sizeof(buffer), DefaultClasses);

	static bool classes[view_as<int>(TFClassType)];
	GetClassesFromString(buffer, classes);

	int slot = item.GetNum("weapon", DefaultSlot);

	if(Loadout[client] == INVALID_HANDLE)
		Loadout[client] = new ArrayList();

	static char buffer2[128];
	int length = Loadout[client].Length;
	for(int i; i<length; i++)
	{
		int id = Loadout[client].Get(i);
		KeyValues kv = TextStore_GetItemKv(id);
		if(slot != kv.GetNum("weapon", DefaultSlot))
			continue;

		static bool classes2[view_as<int>(TFClassType)];
		kv.GetString("class", buffer2, sizeof(buffer2), DefaultClasses);
		GetClassesFromString(buffer2, classes);
		for(int c; c<view_as<int>(TFClassType); c++)
		{
			if(!classes[c] || !classes2[c])
				continue;

			TextStore_SetInv(client, id, _, 0);
			Loadout[client].Erase(i);
			i--;
			length--;
			break;
		}
	}

	if(equipped)
		return Item_Off;

	FF2Changes[client].Push(index);
	return Item_On;
}

void TF2Items_OnPostInventoryApplication(Event event)
{
	if(GetFeatureStatus(FeatureType_Native, "TF2Items_GiveNamedItem") == FeatureStatus_Available)
	{
		int client = GetClientOfUserId(FF2_GetBossUserId(boss));
		if(FF2Changes[client] != INVALID_HANDLE)
		{
			TFClassType class = TF2_GetPlayerClass(client);
			int length = FF2Changes[client].Length;
			for(int i; i<length; i++)
			{
				int index = FF2Changes[client].Get(i);
				int level;
				if(!TextStore_GetInv(client, index, level) || level<1)
				{
					delete pack;
					FF2Changes[client].Erase(i);
					i--;
					length--;
					continue;
				}

				KeyValues kv = TextStore_GetItemKv(index);
				static char buffer[256];
				kv.GetString("class", buffer, sizeof(buffer), DefaultClasses);
	
				static bool classes[view_as<int>(TFClassType)];
				GetClassesFromString(buffer, classes);
				if(!classes[class])
					continue;

				kv.GetString("attributes", buffer, sizeof(buffer));
				index = kv.GetNum("index", DefaultIndex);
				level = kv.GetNum("weapon", DefaultSlot);
				if(level>=0 && level<6)
					TF2_RemoveWeaponSlot(client, level);

				level = kv.GetNum("level", 5);
				static char name[36];
				kv.GetString("classname", name, sizeof(name), DefaultClassname);
				GiveWeapon(client, name, index, level, buffer, class);
			}
		}
	}
}

static void GiveWeapon(int client, char[] name, int index, int level, const char[] attributes, TFClassType class)
{
	if(StrEqual(name, "saxxy", false))
	{ 
		switch(class)
		{
			case TFClass_Scout:	strcopy(name, 36, "tf_weapon_bat");
			case TFClass_Pyro:	strcopy(name, 36, "tf_weapon_fireaxe");
			case TFClass_DemoMan:	strcopy(name, 36, "tf_weapon_bottle");
			case TFClass_Heavy:	strcopy(name, 36, "tf_weapon_fists");
			case TFClass_Engineer:	strcopy(name, 36, "tf_weapon_wrench");
			case TFClass_Medic:	strcopy(name, 36, "tf_weapon_bonesaw");
			case TFClass_Sniper:	strcopy(name, 36, "tf_weapon_club");
			case TFClass_Spy:	strcopy(name, 36, "tf_weapon_knife");
			default:		strcopy(name, 36, "tf_weapon_shovel");
		}
	}
	else if(StrEqual(name, "tf_weapon_shotgun", false))
	{
		switch(class)
		{
			case TFClass_Pyro:	strcopy(name, 36, "tf_weapon_shotgun_pyro");
			case TFClass_Heavy:	strcopy(name, 36, "tf_weapon_shotgun_hwg");
			case TFClass_Engineer:	strcopy(name, 36, "tf_weapon_shotgun_primary");
			default:		strcopy(name, 36, "tf_weapon_shotgun_soldier");
		}
	}

	char atts[40][40];
	int count = ExplodeString(att, ";", atts, sizeof(atts), sizeof(atts[]));

	if(count % 2)
		count--;

	int entity = OVERRIDE_ALL|FORCE_GENERATION;
	if(!count)
		entity |= PRESERVE_ATTRIBUTES;

	Handle weapon = TF2Items_CreateItem(entity);
	if(weapon == INVALID_HANDLE)
		return -1;

	TF2Items_SetClassname(weapon, name);
	TF2Items_SetItemIndex(weapon, index);
	TF2Items_SetLevel(weapon, level);
	TF2Items_SetQuality(weapon, qual);

	TF2Items_SetNumAttributes(weapon, count/2);
	entity = 0;
	for(int i; i<count; i+=2)
	{
		int attrib = StringToInt(atts[i]);
		if(attrib)
			TF2Items_SetAttribute(weapon, entity++, attrib, StringToFloat(atts[i+1]));
	}
	else
	{
		TF2Items_SetNumAttributes(weapon, 0);
	}

	entity = TF2Items_GiveNamedItem(client, weapon);
	delete weapon;
	if(entity < MaxClients)
		return;

	EquipPlayerWeapon(client, entity);
	SetEntProp(entity, Prop_Send, "m_bValidatedAttachedEntity", 1);
	SetEntProp(entity, Prop_Send, "m_iAccountID", GetSteamAccountID(client));

	if(StrEqual(classname, "tf_weapon_builder", false) && index!=735)
	{
		SetEntProp(entity, Prop_Send, "m_aBuildableObjectTypes", 1, _, 0);
		SetEntProp(entity, Prop_Send, "m_aBuildableObjectTypes", 1, _, 1);
		SetEntProp(entity, Prop_Send, "m_aBuildableObjectTypes", 1, _, 2);
		SetEntProp(entity, Prop_Send, "m_aBuildableObjectTypes", 0, _, 3);
	}
	else if(StrEqual(classname, "tf_weapon_sapper", false) || index==735)
	{
		SetEntProp(entity, Prop_Send, "m_iObjectType", 3);
		SetEntProp(entity, Prop_Data, "m_iSubType", 3);
		SetEntProp(entity, Prop_Send, "m_aBuildableObjectTypes", 0, _, 0);
		SetEntProp(entity, Prop_Send, "m_aBuildableObjectTypes", 0, _, 1);
		SetEntProp(entity, Prop_Send, "m_aBuildableObjectTypes", 0, _, 2);
		SetEntProp(entity, Prop_Send, "m_aBuildableObjectTypes", 1, _, 3);
	}
}