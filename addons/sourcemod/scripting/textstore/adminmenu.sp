#define ADMINMENU_TEXTSTORE	"TextStoreCommands"

static TopMenu StoreTop;

void AdminMenu_PluginStart()
{
	TopMenu topmenu;
	if(LibraryExists("adminmenu") && ((topmenu=GetAdminTopMenu())!=null))
		OnAdminMenuReady(topmenu);
}

bool AdminMenu_Return(int client)
{
	if(!StoreTop)
		return false;

	StoreTop.Display(client, TopMenuPosition_LastCategory);
	return true;
}

public void OnAdminMenuCreated(Handle topmenu)
{
	TopMenu menu = TopMenu.FromHandle(topmenu);
	if(menu.FindCategory(ADMINMENU_TEXTSTORE) == INVALID_TOPMENUOBJECT)
		menu.AddCategory(ADMINMENU_TEXTSTORE, TopMenuCategory);
}

public void OnAdminMenuReady(Handle topmenu)
{
	TopMenu menu = TopMenu.FromHandle(topmenu);
	if(menu == StoreTop)
		return;

	StoreTop = menu;
	TopMenuObject topobject = StoreTop.FindCategory(ADMINMENU_TEXTSTORE);
	if(topobject == INVALID_TOPMENUOBJECT)
	{
		topobject = StoreTop.AddCategory(ADMINMENU_TEXTSTORE, TopMenuCategory);
		if(topobject == INVALID_TOPMENUOBJECT)
			return;
	}

	StoreTop.AddItem("sm_buy", StoreT, topobject, "sm_buy", 0);
	StoreTop.AddItem("sm_sell", InventoryT, topobject, "sm_sell", 0);
	StoreTop.AddItem("sm_store_admin", AdminMenuT, topobject, "sm_store_admin", ADMFLAG_ROOT);
}

public void OnLibraryRemoved(const char[] name)
{
	if(StrEqual(name, "adminmenu"))
		StoreTop = null;
}

public void TopMenuCategory(TopMenu topmenu, TopMenuAction action, TopMenuObject topobject, int client, char[] buffer, int maxlength)
{
	switch(action)
	{
		case TopMenuAction_DisplayTitle:
			strcopy(buffer, maxlength, "Text Store:");

		case TopMenuAction_DisplayOption:
			strcopy(buffer, maxlength, "Text Store");
	}
}

public void StoreT(TopMenu topmenu, TopMenuAction action, TopMenuObject topobject, int client, char[] buffer, int maxlength)
{
	switch(action)
	{
		case TopMenuAction_DisplayOption:
			strcopy(buffer, maxlength, "Store Menu");

		case TopMenuAction_SelectOption:
			CommandStore(client, -1);
	}
}

public void InventoryT(TopMenu topmenu, TopMenuAction action, TopMenuObject topobject, int client, char[] buffer, int maxlength)
{
	switch(action)
	{
		case TopMenuAction_DisplayOption:
			strcopy(buffer, maxlength, "Inventory Menu");

		case TopMenuAction_SelectOption:
			CommandInven(client, -1);
	}
}

public void AdminMenuT(TopMenu topmenu, TopMenuAction action, TopMenuObject topobject, int client, char[] buffer, int maxlength)
{
	switch(action)
	{
		case TopMenuAction_DisplayOption:
			strcopy(buffer, maxlength, "Admin Menu");

		case TopMenuAction_SelectOption:
			CommandAdmin(client, -1);
	}
}