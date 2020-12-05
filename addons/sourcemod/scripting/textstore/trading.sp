static ArrayList TradeList;
static Cookie TradeCookie;

void Trading_PluginStart()
{
	if(TradeList == INVALID_HANDLE)
		TradeList = new ArrayList();

	TradeCookie = new Cookie("textstore_trading", "If to enable receiving trade offers", CookieAccess_Public);

	RegConsoleCmd("sm_trade", Trading_Command, "Open trade list or start a trade");
	RegConsoleCmd("sm_trading", Trading_Command, "Open trade list or start a trade");
}

void Trading_CookiesCached(int client)
{
	char byte[2];
	TradeCookie.Get(client, byte, sizeof(byte));
	Client[client].CanTrade = byte[0]!='1';
}

void Trading_Disconnect(int client)
{
	Client[client].CanTrade = false;

	int length = TradeList.Length;
	for(int i; i<length; i++)
	{
		StringMap map = TradeList.Get(i);

		int value;
		if(map.GetValue("trader", value) && value!=client && map.GetValue("tradee", value) && value!=client)
			continue;

		delete map;
		TradeList.Erase(i);
		i--;
		length--;
	}
}

Action Trading_SayCommand(int client, const char[] buffer)
{
	if(Client[client].Target)
	{
		switch(Client[client].ChatType)
		{
			case Type_TradeCash:
			{
				if(IsCharNumeric(buffer[0]) || buffer[0]=='-')
				{
					int amount = StringToInt(buffer);
					if(amount > 0)
					{
						if(Client[Client[client].Target].Cash < amount)
							amount = Client[Client[client].Target].Cash;
					}
					else if(amount < 0)
					{
						if(Client[client].Cash < -amount)
							amount = -Client[client].Cash;
					}

					int i, value;
					int length = TradeList.Length;
					for(; i<length; i++)
					{
						StringMap map = TradeList.Get(i);
						if(!map.GetValue("trader", value) || value!=client || !map.GetValue("tradee", value) || value!=Client[client].Target)
							continue;

						if(!map.GetValue("sent", value) || !value)
							map.SetValue("cash", amount);

						break;
					}

					if(i == length)
					{
						StringMap map = new StringMap();
						map.SetValue("trader", client);
						map.SetValue("tradee", Client[client].Target);
						map.SetValue("cash", amount);
						TradeList.Push(map);
					}

					Trading(client);
					return Plugin_Handled;
				}
			}
			case Type_TradeItem:
			{
				if(IsCharNumeric(buffer[0]) || buffer[0]=='-')
				{
					int value = Client[client].GetPos();
					if(value != -1)
					{
						ItemEnum item;
						Items.GetArray(value, item);

						static char num[MAX_NUM_LENGTH];
						IntToString(value, num, sizeof(num));

						int amount = StringToInt(buffer);
						if(amount > 0)
						{
							if(item.Count[Client[client].Target] < amount)
								amount = item.Count[Client[client].Target];
						}
						else if(amount < 0)
						{
							if(item.Count[client] < -amount)
								amount = -item.Count[client];
						}

						int i;
						int length = TradeList.Length;
						for(; i<length; i++)
						{
							StringMap map = TradeList.Get(i);
							if(!map.GetValue("trader", value) || value!=client || !map.GetValue("tradee", value) || value!=Client[client].Target)
								continue;

							if(!map.GetValue("sent", value) || !value)
								map.SetValue(num, amount);

							break;
						}

						if(i == length)
						{
							StringMap map = new StringMap();
							map.SetValue("trader", client);
							map.SetValue("tradee", Client[client].Target);
							map.SetValue(num, amount);
							TradeList.Push(map);
						}

						Trading(client);
						return Plugin_Handled;
					}
				}
			}
		}
	}
	return Plugin_Continue;
}

public Action Trading_Command(int client, int args)
{
	if(!client)
	{
		ReplyToCommand(client, "[SM] %t", "Command is in-game only");
		return Plugin_Handled;
	}

	Client[client].BackOutAdmin = (args==-1);
	Trading(client);
	return Plugin_Handled;
}

static void Trading(int client)
{
	int value;
	char buffer[MAX_TITLE_LENGTH];
	static char buffer2[MAX_NUM_LENGTH];
	if(!IsValidClient(Client[client].Target) || !CanTradeTo(client, Client[client].Target))
	{
		Menu menu = new Menu(TradingExtraH);
		menu.SetTitle("Trading\n \nCredits: %d\n ", Client[client].Cash);

		menu.AddItem("0", Client[client].CanTrade ? "Disable Trade Requests" : "Enable Trade Requests");

		bool choosen[MAXPLAYERS+1];
		int length = TradeList.Length;
		for(int i; i<length; i++)
		{
			StringMap map = TradeList.Get(i);
			bool sent = map.GetValue("sent", value);
			if(sent && map.GetValue("tradee", value) && value==client)
			{
				if(map.GetValue("trader", value) && IsValidClient(value))
				{
					IntToString(value, buffer2, sizeof(buffer2));
					FormatEx(buffer, sizeof(buffer), "[<-] %N", value);
					menu.AddItem(buffer2, buffer, choosen[value] ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
					choosen[value] = true;
					continue;
				}
			}
			else if(map.GetValue("trader", value) && value==client)
			{
				if(map.GetValue("tradee", value) && IsValidClient(value))
				{
					IntToString(value, buffer2, sizeof(buffer2));
					FormatEx(buffer, sizeof(buffer), "[%s] %N", sent ? "->" : "--", value);
					menu.AddItem(buffer2, buffer, choosen[value] ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
					choosen[value] = true;
					continue;
				}
			}
			else
			{
				continue;
			}

			delete map;
			TradeList.Erase(i);
			i--;
			length--;
		}

		for(int target=1; target<=MaxClients; target++)
		{
			if(client==target || choosen[target] || !IsValidClient(target) || !CanTradeTo(client, target))
				continue;

			IntToString(target, buffer2, sizeof(buffer2));
			GetClientName(target, buffer, sizeof(buffer));
			menu.AddItem(buffer2, buffer);
		}

		menu.ExitBackButton = true;
		menu.ExitButton = true;
		menu.Display(client, MENU_TIME_FOREVER);
		return;
	}

	int trader;
	int length = TradeList.Length;
	for(int i; i<length; i++)
	{
		StringMap map = TradeList.Get(i);
		if(map.GetValue("trader", trader) && trader==client)
		{
			int worth;
			if(!map.GetValue("tradee", worth) || worth!=Client[client].Target)
				continue;

			if(map.GetValue("sent", value))
			{
				Menu menu = new Menu(TradingExtraH);
				menu.SetTitle("Trading: %N\n \nAre you sure you want to cancel this trade?", worth);
				menu.AddItem("-3", "Yes");
				menu.AddItem("-2", "No");
				menu.Display(client, MENU_TIME_FOREVER);
				return;
			}

			Client[client].ChatType = Type_TradeCash;

			Menu menu = new Menu(TradingH);

			bool found;
			if(map.GetValue("cash", worth) && worth)
			{
				found = true;
				FormatEx(buffer, sizeof(buffer), "[%s] Credits x%d", worth ? worth>0 ? "+" : "-" : " ", abs(worth));
			}
			else
			{
				worth = 0;
				FormatEx(buffer, sizeof(buffer), "[ ] Credits x0 (Type number in chat to change)");
			}
			menu.AddItem("-1", buffer);

			ItemEnum item;
			bool unsellable;
			length = Items.Length;
			for(i=0; i<length; i++)
			{
				Items.GetArray(i, item);
				IntToString(i, buffer2, sizeof(buffer2));
				if(!map.GetValue(buffer2, value) || !value)
					continue;

				bool pos = value>0;
				if(value>1 || value<-1)
				{
					FormatEx(buffer, sizeof(buffer), "[%s] %s x%d", pos ? "+" : "-", item.Name, pos ? value : -value);
				}
				else
				{
					FormatEx(buffer, sizeof(buffer), "[%s] %s", pos ? "+" : "-", item.Name);
				}

				item.Kv.Rewind();
				int sell = item.Kv.GetNum("sell", RoundFloat(item.Kv.GetNum("cost")*SELLRATIO));
				if(sell > 0)
				{
					worth += sell*value;
				}
				else
				{
					unsellable = true;
				}

				found = true;
				menu.AddItem(buffer2, buffer);
			}

			menu.SetTitle("Trading: %N\nNetworth: %d%s\n ", Client[client].Target, worth, unsellable ? "*" : "");
			menu.AddItem("-2", "Add Your Item");
			FormatEx(buffer, sizeof(buffer), "Add %N's Item", Client[client].Target);
			menu.AddItem("-3", buffer);
			menu.AddItem(found ? "-4" : "-2", "Confirm Trade", found ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
			menu.ExitBackButton = true;
			menu.ExitButton = true;
			menu.Display(client, MENU_TIME_FOREVER);
			return;
		}
		else if(map.GetValue("sent", value) && value && map.GetValue("tradee", value) && value==client)
		{
			if(trader != Client[client].Target)
				continue;

			Menu menu = new Menu(TradingH);

			int worth;
			bool missing;
			if(map.GetValue("cash", worth) && worth)
			{
				if(worth > 0)
				{
					if(Client[client].Cash < worth)
						missing = true;

					FormatEx(buffer, sizeof(buffer), "[-] Credits x%d", worth);
				}
				else
				{
					if(Client[trader].Cash < -worth)
						missing = true;

					FormatEx(buffer, sizeof(buffer), "[+] Credits x%d", -worth);
				}

				menu.AddItem("-5", buffer, ITEMDRAW_DISABLED);
				worth = -worth;
			}

			ItemEnum item;
			bool unsellable;
			length = Items.Length;
			for(int a; a<length; a++)
			{
				Items.GetArray(a, item);
				IntToString(a, buffer2, sizeof(buffer2));
				if(!map.GetValue(buffer2, value) || !value)
					continue;

				if(value > 0)
				{
					if(item.Count[client] < value)
					{
						missing = true;
					}
					else if(value > 1)
					{
						FormatEx(buffer, sizeof(buffer), "[-] %s x%d", item.Name, value);
					}
					else
					{
						FormatEx(buffer, sizeof(buffer), "[-] %s", item.Name);
					}
				}
				else if(item.Count[trader] < -value)
				{
					missing = true;
				}
				else if(value < -1)
				{
					FormatEx(buffer, sizeof(buffer), "[+] %s x%d", item.Name, -value);
				}
				else
				{
					FormatEx(buffer, sizeof(buffer), "[+] %s", item.Name);
				}

				if(missing)
				{
					delete map;
					delete menu;
					TradeList.Erase(i);
					SPrintToChat(client, "Items are no longer available");
					Trading(client);
					return;
				}

				item.Kv.Rewind();
				int sell = item.Kv.GetNum("sell", RoundFloat(item.Kv.GetNum("cost")*SELLRATIO));
				if(sell > 0)
				{
					worth -= sell*value;
				}
				else
				{
					unsellable = true;
				}

				menu.AddItem(buffer2, buffer, ITEMDRAW_DISABLED);
			}

			menu.SetTitle("Trading: %N\nNetworth: %d%s\n ", trader, worth, unsellable ? "*" : "");
			menu.AddItem("-6", "Accept Trade");
			menu.AddItem("-5", "Decline Trade");
			menu.ExitBackButton = true;
			menu.ExitButton = false;
			menu.Display(client, MENU_TIME_FOREVER);
			return;
		}
	}

	Client[client].ChatType = Type_TradeCash;
	Menu menu = new Menu(TradingH);
	menu.SetTitle("Trading: %N\n ", Client[client].Target);
	menu.AddItem("-2", "Click to add an item");
	menu.AddItem("-2", "Click an item to adjust the amount or remove");
	menu.AddItem("-2", "[+] means your receiving this item");
	menu.AddItem("-2", "[-] means your giving this item");
	menu.AddItem("-2", "Click on Confirm Trade once finished");
	menu.AddItem("-2", "Click on Exit to cancel the trade");
	menu.AddItem("-2", "This trade will save until the player leaves");
	menu.ExitBackButton = true;
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

static void TradingInv(int client)
{
	if(!IsValidClient(Client[client].Target))
	{
		Trading(client);
		return;
	}

	ItemEnum item;
	int primary = Client[client].GetPos();
	if(primary != -1)
		Items.GetArray(primary, item);

	if(!item.Kv)
	{
		int target = Client[client].StoreType==Type_Inven ? client : Client[client].Target;

		Menu menu = new Menu(TradingInvH);
		if(primary == -1)
		{
			menu.SetTitle("Trading: %N\n%N's Inventory\nCredits: %d\n ", Client[client].Target, target, Client[target].Cash);
		}
		else
		{
			menu.SetTitle("Trading: %s\n%N's Inventory\n ", item.Name, target);
		}

		bool found;
		int length = Items.Length;
		for(int i; i<length; i++)
		{
			Items.GetArray(i, item);
			if(item.Parent != primary)
				continue;

			if(item.Kv)
			{
				if(item.Count[target] < 1)
					continue;

				item.Kv.Rewind();
				if(!item.Kv.GetNum("trade", 1))
					continue;
			}

			static char buffer[MAX_NUM_LENGTH];
			IntToString(i, buffer, sizeof(buffer));
			menu.AddItem(buffer, item.Name);
			found = true;
		}

		if(!found)
			menu.AddItem("-1", "No Items", ITEMDRAW_DISABLED);

		menu.ExitBackButton = true;
		menu.ExitButton = true;
		menu.Display(client, MENU_TIME_FOREVER);
		return;
	}

	Client[client].ChatType = Type_TradeItem;

	Panel panel = new Panel();
	char buffer[MAX_DESC_LENGTH];
	FormatEx(buffer, sizeof(buffer), "%s\n ", item.Name);
	panel.SetTitle(buffer);

	item.Kv.Rewind();
	item.Kv.GetString("desc", buffer, sizeof(buffer), "No Description");
	ReplaceString(buffer, sizeof(buffer), "\\n", "\n");
	panel.DrawText(buffer);

	bool targetHas = item.Count[Client[client].Target]>1;
	bool clientHas = item.Count[client]>1;
	if(item.Kv.GetNum("stack", 1) || targetHas || clientHas)
	{
		FormatEx(buffer, sizeof(buffer), " \n%N owns %d\nYou own %d\n ", Client[client].Target, item.Count[Client[client].Target], item.Count[client]);
	}
	else
	{
		FormatEx(buffer, sizeof(buffer), " \n%N %s this item\nYou %sown this item\n ", Client[client].Target, item.Count[Client[client].Target] ? "owns" : "doesn't own", item.Count[client] ? "" : "don't ");
	}
	panel.DrawText(buffer);

	if(!targetHas)
		targetHas = item.Count[Client[client].Target]>0;

	if(!clientHas)
		clientHas = item.Count[client]>0;

	int cost = item.Kv.GetNum("cost");
	if(cost>0 && !item.Hidden)
	{
		FormatEx(buffer, sizeof(buffer), "Buy Price: %d Credits", cost);
		panel.DrawText(buffer);
	}
	else
	{
		panel.DrawText("Buy Price: N/A");
	}

	int sell = item.Kv.GetNum("sell", RoundFloat(cost*SELLRATIO));
	if(sell > 0)
	{
		FormatEx(buffer, sizeof(buffer), "Sell Price: %d Credits\n ", sell);
		panel.DrawText(buffer);
	}
	else
	{
		panel.DrawText("Sell Price: N/A\n ");
	}

	if(targetHas && clientHas)
	{
		panel.DrawItem("Add Your Item");
		FormatEx(buffer, sizeof(buffer), "Add %N's Item", Client[client].Target);
		panel.DrawItem(buffer);
	}
	else if(targetHas)
	{
		panel.CurrentKey = 2;
		panel.DrawItem("Add Item");
	}
	else
	{
		panel.DrawItem("Add Item");
	}

	panel.DrawText("Type number in chat for custom amount");

	if(clientHas)
	{
		int rand = GetRandomInt(1, item.Count[client]);
		FormatEx(buffer, sizeof(buffer), "Example: '-%d' adds %d of your items", rand, rand);
		panel.DrawText(buffer);
	}

	if(targetHas)
	{
		int rand = GetRandomInt(1, item.Count[Client[client].Target]);
		FormatEx(buffer, sizeof(buffer), "Example: '%d' adds %d of %N's items", rand, rand, Client[client].Target);
		panel.DrawText(buffer);
	}

	panel.DrawText(" ");
	panel.CurrentKey = 8;
	panel.DrawItem("Back");
	panel.DrawText(" ");
	panel.CurrentKey = 10;
	panel.DrawItem("Exit");
	panel.Send(client, TradingItemH, MENU_TIME_FOREVER);
	delete panel;
}

public int TradingH(Menu menu, MenuAction action, int client, int choice)
{
	switch(action)
	{
		case MenuAction_End:
		{
			delete menu;
		}
		case MenuAction_Cancel:
		{
			Client[client].ChatType = Type_None;

			switch(choice)
			{
				case MenuCancel_Exit:
				{
					if(IsValidClient(Client[client].Target))
					{
						Menu menu2 = new Menu(TradingExtraH);
						menu2.SetTitle("Trading: %s\n \nAre you sure you want to cancel this trade?", Client[client].Target);
						menu2.AddItem("-2", "Yes");
						menu2.AddItem("-1", "No");
						menu2.Display(client, MENU_TIME_FOREVER);
						return;
					}
				}
				case MenuCancel_ExitBack:
				{
				}
				default:
				{
					return;
				}
			}

			Client[client].Target = 0;
			Trading(client);
		}
		case MenuAction_Select:
		{
			static char buffer[MAX_NUM_LENGTH];
			menu.GetItem(choice, buffer, sizeof(buffer));
			int value = StringToInt(buffer);
			switch(value)
			{
				case -6:
				{
					int length = TradeList.Length;
					for(int i; i<length; i++)
					{
						StringMap map = TradeList.Get(i);
						if(map.GetValue("tradee", value) && value==client && map.GetValue("trader", value) && value==Client[client].Target)
						{
							if(IsValidClient(Client[client].Target))
							{
								bool missing;
								if(map.GetValue("cash", value))
								{
									if(value)
									{
										if(value > 0)
										{
											if(Client[client].Cash < value)
												missing = true;
										}
										else if(Client[Client[client].Target].Cash < -value)
										{
											missing = true;
										}
									}
								}
								else
								{
									value = 0;
								}

								ItemEnum item;
								length = Items.Length;
								int[] items = new int[length];
								for(int a; a<length; a++)
								{
									Items.GetArray(a, item);
									IntToString(a, buffer, sizeof(buffer));
									if(!map.GetValue(buffer, items[a]) || !items[a])
										continue;

									if(items[a] > 0)
									{
										if(item.Count[client] < items[a])
										{
											missing = true;
											break;
										}
									}
									else if(item.Count[Client[client].Target] < -items[a])
									{
										missing = true;
										break;
									}
								}

								if(missing)
								{
									SPrintToChat(client, "Items are no longer available");
								}
								else
								{
									Client[client].Cash -= value;
									Client[Client[client].Target].Cash += value;
									for(int a; a<length; a++)
									{
										if(!items[a])
											continue;

										Items.GetArray(a, item);
										item.Count[client] -= items[a];
										item.Count[Client[client].Target] += items[a];
										Items.SetArray(a, item);
									}
									SPrintToChat(Client[client].Target, "%s%N %saccepted your trade offer", STORE_COLOR2, client, STORE_COLOR);
								}
							}

							delete map;
							TradeList.Erase(i);
							break;
						}
					}
					Client[client].Target = 0;
				}
				case -5:
				{
					int length = TradeList.Length;
					for(int i; i<length; i++)
					{
						StringMap map = TradeList.Get(i);
						if(map.GetValue("tradee", value) && value==client && map.GetValue("trader", value) && value==Client[client].Target)
						{
							if(IsValidClient(Client[client].Target))
								SPrintToChat(Client[client].Target, "%s%N %sdeclined your trade offer", STORE_COLOR2, client, STORE_COLOR);

							delete map;
							TradeList.Erase(i);
							break;
						}
					}
					Client[client].Target = 0;
				}
				case -4:
				{
					int length = TradeList.Length;
					for(int i; i<length; i++)
					{
						StringMap map = TradeList.Get(i);
						if(map.GetValue("trader", value) && value==client && map.GetValue("tradee", value) && value==Client[client].Target)
						{
							map.SetValue("sent", 1);
							if(IsValidClient(Client[client].Target))
								SPrintToChat(Client[client].Target, "%s%N %ssent you a trade offer", STORE_COLOR2, client, STORE_COLOR);

							Client[client].Target = 0;
							break;
						}
					}
				}
				case -3:
				{
					if(Client[client].StoreType == Type_Trade)
					{
						Client[client].RemovePos();
					}
					else
					{
						Client[client].ClearPos();
						Client[client].StoreType = Type_Trade;
					}

					TradingInv(client);
					return;
				}
				case -2:
				{
					if(Client[client].StoreType == Type_Inven)
					{
						Client[client].RemovePos();
					}
					else
					{
						Client[client].ClearPos();
						Client[client].StoreType = Type_Inven;
					}

					TradingInv(client);
					return;
				}
				case -1:
				{
				}
				default:
				{
					int length = TradeList.Length;
					for(int i; i<length; i++)
					{
						StringMap map = TradeList.Get(i);
						if(map.GetValue("trader", value) && value==client && map.GetValue("tradee", value) && value==Client[client].Target)
						{
							map.SetValue(buffer, 0);
							break;
						}
					}
				}
			}
			Trading(client);
		}
	}
}

public int TradingInvH(Menu menu, MenuAction action, int client, int choice)
{
	switch(action)
	{
		case MenuAction_End:
		{
			delete menu;
		}
		case MenuAction_Cancel:
		{
			Client[client].ChatType = Type_None;

			switch(choice)
			{
				case MenuCancel_Exit:
				{
					Client[client].ClearPos();
					Trading(client);
				}
				case MenuCancel_ExitBack:
				{
					if(Client[client].RemovePos() != -1)
					{
						TradingInv(client);
					}
					else
					{
						Trading(client);
					}
				}
			}
		}
		case MenuAction_Select:
		{
			static char buffer[MAX_NUM_LENGTH];
			menu.GetItem(choice, buffer, MAX_NUM_LENGTH);
			if(buffer[0])
				Client[client].AddPos(StringToInt(buffer));

			TradingInv(client);
		}
	}
}

public int TradingItemH(Menu panel, MenuAction action, int client, int choice)
{
	if(action != MenuAction_Select)
		return;

	if(IsValidClient(Client[client].Target))
	{
		switch(choice)
		{
			case 1:
			{
				int target = choice==2 ? Client[client].Target : client;

				int index = Client[client].GetPos();
				ItemEnum item;
				Items.GetArray(index, item);
				if(item.Count[target] > 0)
				{
					static char buffer[MAX_NUM_LENGTH];
					IntToString(index, buffer, sizeof(buffer));

					int i, value;
					int length = TradeList.Length;
					for(; i<length; i++)
					{
						StringMap map = TradeList.Get(i);
						if(map.GetValue("trader", value) && value==client && map.GetValue("tradee", value) && value==Client[client].Target)
						{
							if(!map.GetValue(buffer, value))
								value = 0;

							map.SetValue(buffer, choice==2 ? value+1 : value-1);
							break;
						}
					}

					if(i == length)
					{
						StringMap map = new StringMap();
						map.SetValue("trader", client);
						map.SetValue("tradee", Client[client].Target);
						map.SetValue(buffer, choice==2 ? 1 : -1);
						TradeList.Push(map);
					}
				}
				Client[client].RemovePos();
			}
			case 10:
			{
				Client[client].ClearPos();
			}
			default:
			{
				Client[client].RemovePos();
				TradingInv(client);
				return;
			}
		}
	}
	Trading(client);
}

public int TradingExtraH(Menu menu, MenuAction action, int client, int choice)
{
	switch(action)
	{
		case MenuAction_End:
		{
			delete menu;
		}
		case MenuAction_Cancel:
		{
			if(choice != MenuCancel_ExitBack)
				return;

			if(!Client[client].BackOutAdmin || !AdminMenu_Return(client))
				Main(client);
		}
		case MenuAction_Select:
		{
			static char buffer[MAX_NUM_LENGTH];
			menu.GetItem(choice, buffer, sizeof(buffer));
			int value = StringToInt(buffer);
			switch(value)
			{
				case -2:
				{
					int length = TradeList.Length;
					for(int i; i<length; i++)
					{
						StringMap map = TradeList.Get(i);
						if(map.GetValue("trader", value) && value==client && map.GetValue("tradee", value) && value==Client[client].Target)
						{
							delete map;
							TradeList.Erase(i);
							break;
						}
					}
					Client[client].Target = 0;
				}
				case -1:
				{
					Client[client].Target = 0;
				}
				case 0:
				{
					Client[client].CanTrade = !Client[client].CanTrade;
					if(AreClientCookiesCached(client))
						TradeCookie.Set(client, Client[client].CanTrade ? "0" : "1");
				}
				default:
				{
					if(IsValidClient(value) && CanTradeTo(client, value))
					{
						Client[client].Target = value;
					}
					else
					{
						PrintToChat(client, "[SM] %t", "Player no longer available");
					}
				}
			}
			Trading(client);
		}
	}
}

static bool CanTradeTo(int client, int target)
{
	return (Client[target].Ready && Client[target].CanTrade && !IsClientMuted(target, client));
}