#define ITEM_COMMAND	"command"

public ItemResult Command_Use(int client, bool equipped, KeyValues item, int index, const char[] name, int &count)
{
	static char buffer[512], buffer2[128];
	item.GetString("command", buffer, sizeof(buffer));

	if(StrContains(buffer, "{clientid}") >= 0)
	{
		IntToString(client, buffer2, sizeof(buffer2));
		ReplaceString(buffer, sizeof(buffer), "{clientid}", buffer2);
	}

	if(StrContains(buffer, "{userid}") >= 0)
	{
		IntToString(GetClientUserId(client), buffer2, sizeof(buffer2));
		ReplaceString(buffer, sizeof(buffer), "{userid}", buffer2);
	}

	if(StrContains(buffer, "{steamid}") >= 0)
	{
		if(GetClientAuthId(client, AuthId_Steam2, buffer2, sizeof(buffer2)))
			ReplaceString(buffer, sizeof(buffer), "{steamid}", buffer2);
	}

	if(StrContains(buffer, "{name}") >= 0)
	{
		if(GetClientName(client, buffer2, sizeof(buffer2)))
			ReplaceString(buffer, sizeof(buffer), "{name}", buffer2);
	}

	item.GetString("fail", buffer2, sizeof(buffer2));
	if(!buffer2[0])
	{
		item.GetString("success", buffer2, sizeof(buffer2));
		if(!buffer2[0])
		{
			ServerCommand(buffer);
			return Item_Used;
		}
	}

	ServerCommandEx(buffer2, sizeof(buffer2), buffer);

	item.GetString("fail", buffer, sizeof(buffer));
	if(buffer[0] && StrContains(buffer2, buffer)>=0)
		return Item_None;

	item.GetString("success", buffer, sizeof(buffer));
	if(buffer[0] && StrContains(buffer2, buffer)<0)
		return Item_None;

	return Item_Used;
}