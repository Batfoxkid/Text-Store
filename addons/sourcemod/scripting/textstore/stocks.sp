stock void GenerateClientList(Menu menu, int client=0)
{
	for(int target=1; target<=MaxClients; target++)
	{
		if(!IsValidClient(target))
			continue;

		static char name[64];
		GetClientName(target, name, sizeof(name));
		if(client && !CanUserTarget(client, target))
		{
			menu.AddItem("0", name, ITEMDRAW_DISABLED);
			continue;
		}

		static char userid[32];
		IntToString(GetClientUserId(target), userid, sizeof(userid));
		menu.AddItem(userid, name);
	}
}

stock bool IsValidClient(int client)
{
	if(client<1 || client>MaxClients)
		return false;

	if(!IsClientInGame(client))
		return false;

	if(IsFakeClient(client) || IsClientSourceTV(client) || IsClientReplay(client))
		return false;

	return true;
}