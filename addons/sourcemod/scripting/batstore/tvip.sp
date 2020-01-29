#undef REQUIRE_PLUGIN
#tryinclude <tVip>
#define REQUIRE_PLUGIN

#if defined _tVip_included
#define ITEM_TVIP	"tvip"

public ItemResult tVip_Use(int client, bool equipped, KeyValues item, const char[] name, int &count)
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
