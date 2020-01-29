#undef REQUIRE_PLUGIN
#tryinclude <freak_fortress_2>
#define REQUIRE_PLUGIN

#if defined _FF2_included
#define ITEM_TF2_FF2	"freak_fortress_2"

public ItemResult FF2_Use(int client, bool equipped, KeyValues item, const char[] name, int &count)
{
	if(GetFeatureStatus(FeatureType_Native, "FF2_GetQueuePoints") != FeatureStatus_Available)
	{
		if(CheckCommandAccess(client, "batstore_dev", ADMFLAG_RCON))
		{
			item.GetString("plugin", buffer, MAX_MATERIAL_PATH);
			SPrintToClient(client, "%s can't find Freak Fortress 2 natives!", buffer);
		}
		else
		{
			SPrintToClient(client, "This can't be used right now!");
		}
		return Item_None;
	}

	bool used;
	{
		int points = item.GetNum("points");
		if(points)
		{
			FF2_SetQueuePoints(client, FF2_GetQueuePoints(client)+points);
			used = true;
		}
	}

	{
		static char buffer[64];
		item.GetNum("unlock", buffer, sizeof(buffer));
		for(int i; ; i++)
		{
			KeyValues kv = FF2_GetSpecialKV(boss, i);
			if(kv == INVALID_HANDLE)
				break;

			if(!StrEqual
		}
	}

	if(used)
		return Item_Used;
	return Item_On;
}

public Action FF2_OnSpecialSelected(int boss, int &character, char[] characterName, bool preset)
{
	
}
#endif
