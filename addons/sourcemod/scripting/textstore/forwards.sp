static GlobalForward OnSellItem;

void Forward_PluginLoad()
{
	OnSellItem = new GlobalForward("TextStore_OnSellItem", ET_Hook, Param_Cell, Param_Cell, Param_Cell, Param_CellByRef, Param_CellByRef);
}

Action Forward_OnSellItem(int client, int item, int cash, int &count, int &sell)
{
	Action action = Plugin_Continue;
	Call_StartForward(OnSellItem);
	Call_PushCell(client);
	Call_PushCell(item);
	Call_PushCell(cash);
	Call_PushCellRef(count);
	Call_PushCellRef(sell);
	Call_Finish(action);
	return action;
}