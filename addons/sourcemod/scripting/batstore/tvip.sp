#if defined _tVip_included
#define ITEM_TVIP	"tvip"

public ItemResult tVip_Use(int client, bool equipped, KeyValues item, int index, const char[] name, int &count)
{
	if(CheckCommandAccess(client, "batstore_donator", ADMFLAG_RESERVATION, true))
	{
		SPrintToChat(client, "You already have donator status!");
		return Item_None;
	}

	if(GetFeatureStatus(FeatureType_Native, "tVip_GrantVip") != FeatureStatus_Available)
	{
		if(CheckCommandAccess(client, "batstore_dev", ADMFLAG_RCON))
		{
			char buffer[64];
			item.GetString("plugin", buffer, sizeof(buffer));
			SPrintToChat(client, "%s can't find tVip natives!", buffer);
		}
		else
		{
			SPrintToChat(client, "This can't be used right now!");
		}
		return Item_None;
	}

	tVip_GrantVip(client, 0, item.GetNum("duration", 60), 1);
	return Item_Used;
}
#endif
