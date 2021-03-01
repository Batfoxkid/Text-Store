#define IsValidClient(%1)	(%1>0 && %1<=MaxClients && IsClientInGame(%1) && !IsFakeClient(%1) && !IsClientSourceTV(%1) && !IsClientReplay(%1))

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
			menu.AddItem("", name, ITEMDRAW_DISABLED);
			continue;
		}

		static char userid[16];
		IntToString(GetClientUserId(target), userid, sizeof(userid));
		menu.AddItem(userid, name);
	}
}

stock any abs(any i)
{
	return i<0 ? -i : i;
}