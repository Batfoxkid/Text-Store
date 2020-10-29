enum struct TradeEnum
{
	bool Sent;
	int Tradee;
	int Trader;

	int Items[MAXITEMS+1];
}

static ArrayList TradeList;
static Cookie TradeCookie;

void Trading_PluginStart()
{
	if(TradeList == INVALID_HANDLE)
		TradeList = new ArrayList(sizeof(TradeEnum));

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
		TradeEnum trade;
		TradeList.GetArray(i, trade, sizeof(trade));
		if(trade.Trader!=client && trade.Tradee!=client)
			continue;

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
					int length = TradeList.Length;
					for(int i; i<length; i++)
					{
						TradeEnum trade;
						TradeList.GetArray(i, trade, sizeof(trade));
						if(trade.Trader!=client || trade.Tradee!=Client[client].Target)
							continue;

						if(trade.Sent)
							break;

						trade.Items[0] = StringToInt(buffer);
						if(trade.Items[0] > 0)
						{
							if(Client[Client[client].Target].Cash < trade.Items[0])
								trade.Items[0] = Client[Client[client].Target].Cash;
						}
						else if(trade.Items[0] < 0)
						{
							if(Client[client].Cash < -trade.Items[0])
								trade.Items[0] = Client[client].Cash;
						}
						TradeList.SetArray(i, trade);
						Trading(client);
						return Plugin_Handled;
					}
				}
			}
			case Type_TradeItem:
			{
				if(IsCharNumeric(buffer[0]) || buffer[0]=='-')
				{
					int length = TradeList.Length;
					for(int i; i<length; i++)
					{
						TradeEnum trade;
						TradeList.GetArray(i, trade, sizeof(trade));
						if(trade.Trader!=client || trade.Tradee!=Client[client].Target)
							continue;

						if(!trade.Sent)
						{
							int item = Client[client].GetPos();
							if(item && !Item[item].Items[0])
							{
								trade.Items[item] = StringToInt(buffer);
								if(trade.Items[item] > 0)
								{
									if(Inv[Client[client].Target][item].Count < trade.Items[item])
										trade.Items[item] = Inv[Client[client].Target][item].Count;
								}
								else if(trade.Items[item] < 0)
								{
									if(Inv[client][item].Count < -trade.Items[item])
										trade.Items[item] = Inv[client][item].Count;
								}
								TradeList.SetArray(i, trade);
								Trading(client);
								return Plugin_Handled;
							}
						}
						break;
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
	if(IsVoteInProgress())
	{
		PrintToChat(client, "[SM] %t", "Vote in Progress");
		return;
	}

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
			TradeEnum trade;
			TradeList.GetArray(i, trade, sizeof(trade));

			if(trade.Sent && trade.Tradee==client)
			{
				if(!IsValidClient(trade.Trader))
				{
					TradeList.Erase(i);
					i--;
					length--;
					continue;
				}

				IntToString(trade.Trader, buffer2, sizeof(buffer2));
				FormatEx(buffer, sizeof(buffer), "[<-] %N", trade.Trader);
				menu.AddItem(buffer2, buffer, choosen[trade.Trader] ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
				choosen[trade.Trader] = true;
			}
			else if(trade.Trader == client)
			{
				if(!IsValidClient(trade.Tradee))
				{
					TradeList.Erase(i);
					i--;
					length--;
					continue;
				}

				IntToString(trade.Tradee, buffer2, sizeof(buffer2));
				FormatEx(buffer, sizeof(buffer), "[%s] %N", trade.Sent ? "->" : "--", trade.Tradee);
				menu.AddItem(buffer2, buffer, choosen[trade.Tradee] ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
				choosen[trade.Tradee] = true;
			}
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

	int length = TradeList.Length;
	for(int i; i<length; i++)
	{
		TradeEnum trade;
		TradeList.GetArray(i, trade, sizeof(trade));
		if(trade.Trader == client)
		{
			if(trade.Tradee != Client[client].Target)
				continue;

			if(trade.Sent)
			{
				Menu menu = new Menu(TradingExtraH);
				menu.SetTitle("Trading: %s\n \nAre you sure you want to cancel this trade?", trade.Tradee);
				menu.AddItem("-2", "Yes");
				menu.AddItem("-1", "No");
				menu.Display(client, MENU_TIME_FOREVER);
				return;
			}

			Menu menu = new Menu(TradingH);

			FormatEx(buffer, sizeof(buffer), "[%s] Credits x%d%s", trade.Items[0] ? trade.Items[0]>0 ? "+" : "-" : " ", abs(trade.Items[0]), trade.Items[0] ? "" : " (Type number in chat to change)");
			menu.AddItem("0", buffer);

			int worth = trade.Items[0];
			bool unsellable;
			for(int item=1; item<=MaxItems; item++)
			{
				if(!trade.Items[item])
					continue;

				bool pos = trade.Items[item]>0;
				if(trade.Items[item]>1 || trade.Items[item]<-1)
				{
					FormatEx(buffer, sizeof(buffer), "[%s] %s x%d", pos ? "+" : "-", Item[item].Name, pos ? trade.Items[item] : -trade.Items[item]);
				}
				else
				{
					FormatEx(buffer, sizeof(buffer), "[%s] %s", pos ? "+" : "-", Item[item].Name);
				}

				if(Item[item].Sell > 0)
				{
					worth += Item[item].Sell*trade.Items[item];
				}
				else
				{
					unsellable = true;
				}

				IntToString(item, buffer2, sizeof(buffer2));
				menu.AddItem(buffer2, buffer);
			}

			menu.SetTitle("Trading: %N\nNetworth: %d%s\n ", Client[client].Target, worth, unsellable ? "*" : "");
			menu.AddItem("-1", "Add Your Item");
			FormatEx(buffer, sizeof(buffer), "Add %N's Item", Client[client].Target);
			menu.AddItem("-2", buffer);
			menu.AddItem("-3", "Confirm Trade");
			menu.ExitBackButton = true;
			menu.ExitButton = true;
			menu.Display(client, MENU_TIME_FOREVER);
			return;
		}
		else if(trade.Sent && trade.Tradee==client)
		{
			if(trade.Trader != Client[client].Target)
				continue;

			Client[client].ChatType = Type_TradeCash;

			Menu menu = new Menu(TradingH);

			bool missing;
			int worth;
			if(trade.Items[0])
			{
				if(trade.Items[0] > 0)
				{
					if(Client[client].Cash < trade.Items[0])
						missing = true;

					FormatEx(buffer, sizeof(buffer), "[-] Credits x%d", trade.Items[0]);
				}
				else
				{
					if(Client[trade.Trader].Cash < -trade.Items[0])
						missing = true;

					FormatEx(buffer, sizeof(buffer), "[+] Credits x%d", -trade.Items[0]);
				}

				menu.AddItem("-4", buffer, ITEMDRAW_DISABLED);
				worth = -trade.Items[0];
			}

			bool unsellable;
			for(int item=1; item<=MaxItems; item++)
			{
				if(!trade.Items[item])
					continue;

				if(trade.Items[item] > 0)
				{
					if(Inv[client][item].Count < trade.Items[item])
					{
						missing = true;
					}
					else if(trade.Items[item] > 1)
					{
						FormatEx(buffer, sizeof(buffer), "[-] %s x%d", Item[item].Name, trade.Items[item]);
					}
					else
					{
						FormatEx(buffer, sizeof(buffer), "[-] %s", Item[item].Name);
					}
				}
				else if(Inv[trade.Trader][item].Count < -trade.Items[item])
				{
					missing = true;
				}
				else if(trade.Items[item] < -1)
				{
					FormatEx(buffer, sizeof(buffer), "[+] %s x%d", Item[item].Name, -trade.Items[item]);
				}
				else
				{
					FormatEx(buffer, sizeof(buffer), "[+] %s", Item[item].Name);
				}

				if(missing)
				{
					delete menu;
					SPrintToChat(client, "Items are no longer available");
					Trading(client);
					return;
				}

				if(Item[item].Sell > 0)
				{
					worth -= Item[item].Sell*trade.Items[item];
				}
				else
				{
					unsellable = true;
				}

				IntToString(item, buffer2, sizeof(buffer2));
				menu.AddItem(buffer2, buffer, ITEMDRAW_DISABLED);
			}

			menu.SetTitle("Trading: %N\nNetworth: %d%s\n ", trade.Trader, worth, unsellable ? "*" : "");
			menu.AddItem("-5", "Accept Trade");
			menu.AddItem("-4", "Decline Trade");
			menu.ExitBackButton = true;
			menu.ExitButton = false;
			menu.Display(client, MENU_TIME_FOREVER);
			return;
		}
	}

	Client[client].ChatType = Type_TradeCash;
	Menu menu = new Menu(TradingH);
	menu.SetTitle("Trading: %N\n ", Client[client].Target);
	menu.AddItem("-1", "Click to add an item");
	menu.AddItem("-1", "Click an item to adjust the amount or remove");
	menu.AddItem("-1", "[+] means your receiving this item");
	menu.AddItem("-1", "[-] means your giving this item");
	menu.AddItem("-1", "Click on Confirm Trade once finished");
	menu.AddItem("-1", "Click on Exit to cancel the trade");
	menu.AddItem("-1", "This trade will save until the player leaves");
	menu.ExitBackButton = true;
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

static void TradingInv(int client)
{
	if(IsVoteInProgress())
	{
		PrintToChat(client, "[SM] %t", "Vote in Progress");
		return;
	}

	if(!IsValidClient(Client[client].Target))
	{
		Trading(client);
		return;
	}

	int item = Client[client].GetPos();
	if(!item || Item[item].Items[0]>0)
	{
		int target = Client[client].StoreType==Type_Inven ? client : Client[client].Target;

		Menu menu = new Menu(TradingInvH);
		if(item)
		{
			menu.SetTitle("Trading: %s\n%N's Inventory\n ", Item[item].Name, target);
		}
		else
		{
			menu.SetTitle("Trading: %N\nCredits: %d\n%N's Inventory\n ", Client[client].Target, Client[target].Cash, target);
		}

		bool items;
		for(int i; i<MAXONCE; i++)
		{
			if(ITEM < 1)
				break;

			if(Item[ITEM].Items[0]<1 && (!Item[ITEM].Trade || Inv[target][ITEM].Count<1))
				continue;

			items = true;
			static char buffer[MAX_NUM_LENGTH];
			IntToString(ITEM, buffer, MAX_NUM_LENGTH);
			menu.AddItem(buffer, Item[ITEM].Name);
		}

		if(!items)
			menu.AddItem("0", "No Items", ITEMDRAW_DISABLED);

		menu.ExitBackButton = true;
		menu.ExitButton = true;
		menu.Display(client, MENU_TIME_FOREVER);
		return;
	}

	Client[client].ChatType = Type_TradeItem;

	Panel panel = new Panel();
	char buffer[MAX_TITLE_LENGTH];
	FormatEx(buffer, sizeof(buffer), "%s\n ", Item[item].Name);
	panel.SetTitle(buffer);
	panel.DrawText(Item[item].Desc);

	bool targetHas = Inv[Client[client].Target][item].Count>1;
	bool clientHas = Inv[client][item].Count>1;
	if(Item[item].Stack || targetHas || clientHas)
	{
		FormatEx(buffer, sizeof(buffer), " \n%N owns %d\nYou own %d\n ", Client[client].Target, Inv[Client[client].Target][item].Count, Inv[client][item].Count);
	}
	else
	{
		FormatEx(buffer, sizeof(buffer), " \n%N %s this item\nYou %sown this item\n ", Client[client].Target, Inv[Client[client].Target][item].Count ? "owns" : "doesn't own", Inv[client][item].Count ? "" : "don't ");
	}
	panel.DrawText(buffer);

	if(!targetHas)
		targetHas = Inv[Client[client].Target][item].Count>0;

	if(!clientHas)
		clientHas = Inv[client][item].Count>0;

	if(Item[item].Cost>0 && !Item[item].Hidden)
	{
		FormatEx(buffer, sizeof(buffer), "Buy Price: %d Credits", Item[item].Cost);
		panel.DrawText(buffer);
	}
	else
	{
		panel.DrawText("Buy Price: N/A");
	}

	if(Item[item].Sell > 0)
	{
		FormatEx(buffer, sizeof(buffer), "Sell Price: %d Credits\n ", Item[item].Sell);
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
		int rand = GetRandomInt(1, Inv[client][item].Count);
		FormatEx(buffer, sizeof(buffer), "Example: '-%d' adds %d of your items", rand, rand);
		panel.DrawText(buffer);
	}

	if(targetHas)
	{
		int rand = GetRandomInt(1, Inv[Client[client].Target][item].Count);
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
			int item = StringToInt(buffer);
			switch(item)
			{
				case -5:
				{
					int length = TradeList.Length-1;
					for(int i=length; i>=0; i--)
					{
						TradeEnum trade;
						TradeList.GetArray(i, trade, sizeof(trade));
						if(trade.Tradee==client && trade.Trader==Client[client].Target)
						{
							if(IsValidClient(Client[client].Target))
							{
								bool missing;
								if(trade.Items[0])
								{
									if(trade.Items[0] > 0)
									{
										if(Client[client].Cash < trade.Items[0])
											missing = true;
									}
									else if(Client[trade.Trader].Cash < -trade.Items[0])
									{
										missing = true;
									}
								}

								for(item=1; item<=MaxItems; item++)
								{
									if(!trade.Items[item])
										continue;

									if(trade.Items[item] > 0)
									{
										if(Inv[client][item].Count < trade.Items[item])
										{
											missing = true;
											break;
										}
									}
									else if(Inv[trade.Trader][item].Count < -trade.Items[item])
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
									Client[client].Cash -= trade.Items[0];
									Client[trade.Trader].Cash += trade.Items[0];
									for(item=1; item<=MaxItems; item++)
									{
										if(!trade.Items[item])
											continue;

										Inv[client][item].Count -= trade.Items[item];
										Inv[trade.Trader][item].Count += trade.Items[item];
									}
									SPrintToChat(Client[client].Target, "%s%N %saccepted your trade offer", STORE_COLOR2, client, STORE_COLOR);
								}
							}

							TradeList.Erase(i);
							break;
						}
					}
					Client[client].Target = 0;
				}
				case -4:
				{
					int length = TradeList.Length-1;
					for(int i=length; i>=0; i--)
					{
						TradeEnum trade;
						TradeList.GetArray(i, trade, sizeof(trade));
						if(trade.Tradee==client && trade.Trader==Client[client].Target)
						{
							if(IsValidClient(Client[client].Target))
								SPrintToChat(Client[client].Target, "%s%N %sdeclined your trade offer", STORE_COLOR2, client, STORE_COLOR);

							TradeList.Erase(i);
							break;
						}
					}
					Client[client].Target = 0;
				}
				case -3:
				{
					int length = TradeList.Length-1;
					for(int i=length; i>=0; i--)
					{
						TradeEnum trade;
						TradeList.GetArray(i, trade, sizeof(trade));
						if(trade.Trader==client && trade.Tradee==Client[client].Target)
						{
							trade.Sent = true;
							TradeList.SetArray(i, trade);
							if(IsValidClient(Client[client].Target))
								SPrintToChat(Client[client].Target, "%s%N %ssent you a trade offer", STORE_COLOR2, client, STORE_COLOR);

							Client[client].Target = 0;
							break;
						}
					}
				}
				case -2:
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
				case -1:
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
				default:
				{
					int length = TradeList.Length-1;
					for(int i=length; i>=0; i--)
					{
						TradeEnum trade;
						TradeList.GetArray(i, trade, sizeof(trade));
						if(trade.Trader==client && trade.Tradee==Client[client].Target)
						{
							trade.Items[item] = 0;
							TradeList.SetArray(i, trade);
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
					if(Client[client].RemovePos())
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
			int item = StringToInt(buffer);
			if(item)
				Client[client].AddPos(item);

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
		int item = Client[client].GetPos();
		switch(choice)
		{
			case 1:
			{
				if(Inv[client][item].Count > 0)
				{
					int i;
					int length = TradeList.Length;
					for(; i<length; i++)
					{
						TradeEnum trade;
						TradeList.GetArray(i, trade, sizeof(trade));
						if(trade.Trader!=client || trade.Tradee!=Client[client].Target)
							continue;

						trade.Items[item]--;
						TradeList.SetArray(i, trade);
						break;
					}

					if(i == length)
					{
						TradeEnum trade;
						trade.Trader = client;
						trade.Tradee = Client[client].Target;
						trade.Items[item] = -1;
						TradeList.PushArray(trade);
					}
				}
				Client[client].RemovePos();
			}
			case 2:
			{
				if(Inv[Client[client].Target][item].Count > 0)
				{
					int i;
					int length = TradeList.Length;
					for(; i<length; i++)
					{
						TradeEnum trade;
						TradeList.GetArray(i, trade, sizeof(trade));
						if(trade.Trader!=client || trade.Tradee!=Client[client].Target)
							continue;

						trade.Items[item]++;
						TradeList.SetArray(i, trade);
						break;
					}

					if(i == length)
					{
						TradeEnum trade;
						trade.Trader = client;
						trade.Tradee = Client[client].Target;
						trade.Items[item] = 1;
						TradeList.PushArray(trade);
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
			int item = StringToInt(buffer);
			switch(item)
			{
				case -2:
				{
					int length = TradeList.Length-1;
					for(int i=length; i>=0; i--)
					{
						TradeEnum trade;
						TradeList.GetArray(i, trade, sizeof(trade));
						if(trade.Trader==client && trade.Tradee==Client[client].Target)
						{
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
					if(IsValidClient(item))
					{
						Client[client].Target = item;
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