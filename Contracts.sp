#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "alikoc77"
#define PLUGIN_VERSION "1.00"

#define FIELD_CONTRACT_NAME 			"Contract Name"
#define FIELD_CONTRACT_ACTION			"Contract Type"
#define FIELD_CONTRACT_OBJECTIVE		"Contract Objective"
#define FIELD_CONTRACT_REWARD			"Contract Reward"
#define FIELD_CONTRACT_WEAPON			"Contract Weapon"
#define FIELD_CONTRACT_Info				"Contract Info"
#define ctag "leaderclan"
#define ptag "[Kişisel Görevler]"

#include <sourcemod>
#include <sdktools>
#include <multicolors>
#include <sdkhooks>
#include <store>

#pragma newdecls required

bool client_on_contract[MAXPLAYERS + 1];

int client_contract_obj[MAXPLAYERS + 1] = 0,
	client_contract_progress[MAXPLAYERS + 1] = 0,
	client_contract_reward[MAXPLAYERS + 1] = 0,
	online_players = 0,
	hatirlatma_sayisi = 0;

char client_contract_info[MAXPLAYERS + 1][256],
	client_contract_name[MAXPLAYERS + 1][256],
	client_contract_type[MAXPLAYERS + 1][256],
	client_contract_weapon[MAXPLAYERS + 1][256],
	g_sSQLBuffer[3096];

Handle ARRAY_Contracts;
Handle contract_ex_array;
Handle g_hDB = null;
Handle g_check_walk[MAXPLAYERS + 1] = INVALID_HANDLE;
bool g_bIsMySQl;
float 	newPosition[3],
		lastPosition[MAXPLAYERS + 1][3];

public Plugin myinfo = {
	name = "Kişisel Görevler",
	author = PLUGIN_AUTHOR,
	description = "Kişisel Görevler",
	version = PLUGIN_VERSION,
	url = "https://steamcommunity.com/id/alikoc77"
};

public void OnPluginStart(){
	RegConsoleCmd("sm_gorevler", command_mainmenu);
	LoadTranslations("common.phrases");
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	HookEvent("round_mvp", Event_PlayerMVP, EventHookMode_Pre);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_Pre);
	SQL_TConnect(OnSQLConnect, "contracts");
}
public void OnPluginEnd(){
	for(int client = 1; client <= MaxClients; client++)
	{
		if (valid_client(client) && client_on_contract[client]){
			sql_update_client_contract(client, 0);
		}
	}
}
public void OnMapStart(){
	CreateTimer(1.0, TMR_check_playingT, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}
public void OnClientPutInServer(int client){
	if(valid_client(client)){
		SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
		sql_load_client_contract(client);
	}
}
public void OnClientDisconnect(int client){
	if(!IsFakeClient(client) && client_on_contract[client]){
		sql_update_client_contract(client, 0);
	}
}

public void OnConfigsExecuted(){
	ReadContract();
}
// MENUS
public Action command_mainmenu(int client, int args){
	if(valid_client(client)){
		void_mainmenu(client);
	}
}

void void_mainmenu(int client){
	if (!check_online_p()){
		CPrintToChat(client, "{darkred}%s {green}Oyuncu sayısı kontrat yapmaya uygun değil.En az 4 kişi olmalı.", ptag);
		return;
	}
	if (GetArraySize(contract_ex_array) > 0 && client_in_ex_array(client)){
		CPrintToChat(client, "{darkred}%s {green}Kontrat iptal ettiğinizden dolayı şuanda yeni bir kontrat alamazsınız.", ptag);
		return;
	}
	Menu menu = CreateMenu(menu_mainmenu);
	SetMenuTitle(menu, "%s", ptag);
	AddMenuItem(menu, "", "Aktif Kontrat", client_on_contract[client] ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	AddMenuItem(menu, "", "Yeni bir sözleşme yap", client_on_contract[client] ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	AddMenuItem(menu, "", "İstatistiklerim");
	AddMenuItem(menu, "", "Top 10 - Tamamlanan Kontratlar");
	AddMenuItem(menu, "", "Mevcut Gorevlerin Listesi");
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}
public int menu_mainmenu(Menu menu, MenuAction action, int client, int item){
	switch(action){
		case MenuAction_Select:{
			switch(item){
				case 0 :{
					current_contract(client);
				}
				case 1:{
					a_new_contract(client);
				}
				case 2:{
					my_statics(client);
				}
				case 3:{
					top_statics(client);
				}
				case 4:{
					all_gorevler(client);
				}
			}
		}
		case MenuAction_End:{
			delete menu;
		}
	}
}
void current_contract(int client){
	if(!valid_client(client)){
		return;
	}if(!client_on_contract[client]){
		CPrintToChat(client, "{darkred}%s {orange}Mevcut bir kontratın bulunmamakta.Lütfen yeni bir kontrat imzala.", ptag);
		return;
	}
	Menu menu = CreateMenu(menu_current_contract);
	SetMenuTitle(menu, "%s Mevcut Kontratın:\nKontratın: %s\nİlerlemen: %i / %i", ptag, client_contract_info[client], client_contract_progress[client], client_contract_obj[client]);
	AddMenuItem(menu, "", "----------------");
	AddMenuItem(menu, "", "Kontratı iptal et");
	AddMenuItem(menu, "", "Geri");
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}
public int menu_current_contract(Menu menu, MenuAction action, int client, int item){
	switch(action){
		case MenuAction_Select:{
			switch(item){
				case 1:{
					cancel_client_current_contract(client);
				}
				case 2:{
					void_mainmenu(client);
				}
			}
		}
		case MenuAction_End:{
			delete menu;
		}
	}
}

void a_new_contract(int client){
	if(!valid_client(client)){
		return;
	}if(client_on_contract[client]){
		CPrintToChat(client, "{darkred}%s {orange}Zaten mevcut bir kontratın bulunmakta. Önce onu tamamla veya iptal et.", ptag);
		return;
	}
	Menu menu = CreateMenu(menu_a_new_contract);
	SetMenuTitle(menu, "[Kişisel Görevler]\nKontrat sözleşmesi:\nKontrat kabul etmeniz dahilinde\nRandom bir görev alacaksınız.\nOyundan çıkmadan önce bitirmek zorundasınız.");
	AddMenuItem(menu, "", "Kabul Et");
	AddMenuItem(menu, "", "Reddet");
	AddMenuItem(menu, "", "Geri");
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int menu_a_new_contract(Menu menu, MenuAction action, int client, int item){
	switch(action){
		case MenuAction_Select:{
			switch(item){
				case 0:{
					accept_new_contract(client);
				}
				case 1:{
					CPrintToChat(client, "{darkred}%s {green}Görev kontratını reddettiniz.", ptag);
				}
				case 2:{
					void_mainmenu(client);
				}
			}
		}
		case MenuAction_End:{
			delete menu;
		}
	}
}

void accept_new_contract(int client){
	if(!valid_client(client)){
		return;
	}if(client_on_contract[client]){
		CPrintToChat(client, "{darkred}%s {orange}Zaten mevcut bir kontratın bulunmakta. Önce onu tamamla veya iptal et.", ptag);
		return;
	}
	Handle contractInfos = GetArrayCell(ARRAY_Contracts, GetRandomInt(0, GetArraySize(ARRAY_Contracts) - 1));
	char info[256],
		cWeapon[100],
		cAction[50],
		cNames[100];
		
	int cObjective,
		cReward;
	GetTrieString(contractInfos, FIELD_CONTRACT_NAME, cNames, sizeof(cNames));
	GetTrieString(contractInfos, FIELD_CONTRACT_ACTION, cAction, sizeof(cAction));
	GetTrieValue(contractInfos, FIELD_CONTRACT_OBJECTIVE, cObjective);
	GetTrieValue(contractInfos, FIELD_CONTRACT_REWARD, cReward);
	GetTrieString(contractInfos, FIELD_CONTRACT_WEAPON, cWeapon, sizeof(cWeapon));
	GetTrieString(contractInfos, FIELD_CONTRACT_Info, info, sizeof(info));
	client_contract_weapon[client] = "weapon_";
	StrCat(client_contract_weapon[client], sizeof(client_contract_weapon[]), cWeapon);	
	Format(client_contract_name[client], sizeof(client_contract_name[]), "%s", cNames);
	Format(client_contract_type[client], sizeof(client_contract_type[]), "%s", cAction);
	Format(client_contract_info[client], sizeof(client_contract_info[]), "%s", info);
	client_contract_reward[client] = cReward;
	client_contract_obj[client] = cObjective;
	client_contract_progress[client] = 0;
	if (StrEqual(client_contract_type[client], "WALK")){
		if(!g_check_walk[client])g_check_walk[client] = CreateTimer(0.5, TMR_CheckWalk, client, TIMER_REPEAT);
	}
	if(StrEqual(client_contract_type[client],"Sunucuda_oyna")){
		client_contract_obj[client] = cObjective * 60;
	}
	sql_add_new_client_contract(client);

	CPrintToChat(client, "{darkred}%s {green}Kontrat kabul edildi, kontratı bitirmeden oyundan çıkman durumunda iptal edilecek !", ptag);
	client_on_contract[client] = true;
	current_contract(client);
}
void my_statics(int client){
	if(valid_client(client)){
		char sQuery[128], steamid[64];
		GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
		Format(sQuery, sizeof(sQuery), "SELECT playername, steamid, completed_contracts FROM contracts_top WHERE steamid = '%s'", steamid);
		SQL_TQuery(g_hDB, T_CheckMyStats, sQuery, GetClientUserId(client));
	}
}
public int T_CheckMyStats(Handle owner, Handle results, char [] error, any data){
	int client;
	if((client = GetClientOfUserId(data)) == 0){
		return;
	}
	if(results == null){
		LogError("Query failure: %s", error);
		return;
	}
	if(!SQL_GetRowCount(results) || !SQL_FetchRow(results)) {
		CPrintToChat(client, "{darkred}%s Herhangi bir veri bulunamadı.", ptag);
		return;
	}
	Menu hMenu = new Menu(TopPlayersHandler);
	char sText[256], sName[32], steamid[32];
	SQL_FetchString(results, 0, sName, sizeof(sName));
	SQL_FetchString(results, 1, steamid, sizeof(steamid));
	FormatEx(sText, sizeof(sText), "[Tamamladığın: %d ] - %s [%s]", SQL_FetchInt(results, 2), sName, steamid);
	hMenu.SetTitle("%s | İstatistiklerin\n%s\n ", ptag, sText);
	hMenu.AddItem("1", "Geri");
	hMenu.ExitButton = true;
	hMenu.Display(client, MENU_TIME_FOREVER);	
}
void top_statics(int client){
	if(valid_client(client)){
		char sQuery[128];
		Format(sQuery, sizeof(sQuery), "SELECT playername, steamid, completed_contracts FROM contracts_top ORDER BY completed_contracts DESC LIMIT 10");
		SQL_TQuery(g_hDB, T_CheckTop, sQuery, client);
	}
}
public int T_CheckTop(Handle owner, Handle results, char [] error, any client){
	if(valid_client(client)){
		int i;
		char sText[256], sName[32], sTemp[512], steamid[32];
		if(SQL_HasResultSet(results)){
			while(SQL_FetchRow(results)){
				i++;
				SQL_FetchString(results, 0, sName, sizeof(sName));
				SQL_FetchString(results, 1, steamid, sizeof(steamid));
				FormatEx(sText, sizeof(sText), "%d - [ %d ] - %s [%s]\n", i, SQL_FetchInt(results, 2), sName, steamid);
				if(strlen(sTemp) + strlen(sText) < 512){
					Format(sTemp, sizeof(sTemp), "%s%s", sTemp, sText);
					sText = "\0";
				}
			}
		}
		Menu hMenu = new Menu(TopPlayersHandler);
		hMenu.SetTitle("%s | En Çok Görev Tamamlayanlar\n%s\n ", ptag, sTemp);
		hMenu.AddItem("1", "Geri");
		hMenu.ExitButton = true;
		hMenu.Display(client, MENU_TIME_FOREVER);
	}
}

public int TopPlayersHandler(Menu hMenu, MenuAction mAction, int client, int iSlot)
{
	switch(mAction)
	{
		case MenuAction_End: delete hMenu;
		case MenuAction_Select: void_mainmenu(client);
	}
}
void all_gorevler(int client){
	int size = GetArraySize(ARRAY_Contracts);
	Menu menu = CreateMenu(menu_all_gorevler);
	char contract_name[128];
	SetMenuTitle(menu, "[Kişisel Görevler]\nYapılabilecek Aktif Gorevler\n");
	for (int i = 0; i < size; i++){
		Handle coninf = GetArrayCell(ARRAY_Contracts, i);
		GetTrieString(coninf, FIELD_CONTRACT_NAME, contract_name, sizeof(contract_name));
		AddMenuItem(menu, "", contract_name, ITEMDRAW_DISABLED);
	}
	SetMenuExitButton(menu, true);
	SetMenuExitBackButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}
public int menu_all_gorevler(Menu menu, MenuAction action, int client, int item){
	switch(action){
		case MenuAction_Select:{
			CloseHandle(menu);
		}
		case MenuAction_Cancel:if (item == MenuCancel_ExitBack) { void_mainmenu(client); }
		case MenuAction_End:{
			CloseHandle(menu);
		}
	}
}
void cancel_client_current_contract(int client){
	Menu menu = CreateMenu(menu_contract_ex);
	SetMenuTitle(menu, "[Kişisel Görevler]\nKontratını iptal etme durumunda bir süre yeni bir kontrat imzalayamazsın.\nEmin misin ?");
	AddMenuItem(menu, "", "İptal Et");
	AddMenuItem(menu, "", "Sözümden Dönmeyeceğim");
	AddMenuItem(menu, "", "Geri");
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}
public int menu_contract_ex(Menu menu, MenuAction action, int client, int item){
	switch(action){
		case MenuAction_Select:{
			switch(item){
				case 0:client_contract_iptal(client);
				case 1:CPrintToChat(client, "{darkred}%s {green}Bu sözlerin gözlerimi yaşarttı...", ptag);
				case 2:current_contract(client);
			}
		}
		case MenuAction_End:{
			CloseHandle(menu);
		}
	}
}
// TIMER //
public Action TMR_CheckWalk(Handle Timer, any client){
	if(check_online_p()){
		if(!valid_client(client)){
			return Plugin_Stop;
		}
		if(!g_check_walk[client] && !client_on_contract[client]){
			return Plugin_Stop;
		}
		if (IsClientInGame(client) && IsPlayerAlive(client) && client_on_contract[client]){
			GetClientAbsOrigin(client, newPosition);
			float g_fdistance = GetVectorDistance(lastPosition[client], newPosition);
			lastPosition[client] = newPosition;
			if (g_fdistance / 20 >= 1 && StrEqual(client_contract_type[client], "WALK")){
				client_contract_progress[client] += 1;
				CheckContract(client);
			}
		}
	}
	return Plugin_Continue;
}
public Action TMR_check_playingT(Handle Timer){
	if(check_online_p()){
		for (int i = 1; i <= MaxClients; i++){
			if(!valid_client(i)){
				continue;
			}
			if (StrEqual(client_contract_type[i], "Sunucuda_oyna")){
				client_contract_progress[i] += 1;
				CheckContract(i);
			}
		}
	}
}
// HOOKS //
public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype){
	if(check_online_p()){
		if (StrEqual(client_contract_type[victim], "Olmeden_Hasar_Al") && valid_client(victim) && client_on_contract[victim]){
			client_contract_progress[victim] += RoundToCeil(damage);
			CheckContract(victim);
		}
		if (StrEqual(client_contract_type[attacker], "Hasar_ver") && valid_client(attacker) && client_on_contract[attacker]){
			client_contract_progress[attacker] += RoundToCeil(damage);
			CheckContract(attacker);
		}
	}
	return Plugin_Continue;
}
public void Event_PlayerDeath(Event hEvent, const char[] sEvName, bool bDontBroadcast){
	if(check_online_p()){
		int attacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
		int olen = GetClientOfUserId(GetEventInt(hEvent, "userid"));
		if (!valid_client(olen))return;
		if (!valid_client(attacker))return;
		if(olen == attacker){
			return;
		}
		if (client_on_contract[attacker] && StrEqual(client_contract_type[attacker], "y_Havada_x_Kill")){
			if (!(GetEntityFlags(attacker) & FL_ONGROUND)){
				client_contract_progress[attacker]++;
				CheckContract(attacker);
			}
		}
		if (client_on_contract[attacker] && StrEqual(client_contract_type[attacker], "h_Havada_x_Kill")){
			if (!(GetEntityFlags(olen) & FL_ONGROUND)){
				client_contract_progress[attacker]++;
				CheckContract(attacker);
			}
		}
		if (client_on_contract[attacker] && StrEqual(client_contract_type[attacker], "KILL")){
			if (CheckKillMethod(attacker)){
				client_contract_progress[attacker]++;
				CheckContract(attacker);
			}
		}
		if (client_on_contract[attacker] && StrEqual(client_contract_type[attacker], "HEADSHOT")){
			if (GetEventInt(hEvent, "headshot") == 1){
				client_contract_progress[attacker]++;
				CheckContract(attacker);
			}
		}
		if(client_on_contract[attacker] && StrEqual(client_contract_type[attacker], "NO_SCOPE")){
			char client_weapon[64];
			GetClientWeapon(attacker, client_weapon, sizeof(client_weapon));
			if (!(0 < GetEntProp(attacker, Prop_Data, "m_iFOV") < GetEntProp(attacker, Prop_Data, "m_iDefaultFOV")) && StrEqual(client_weapon, "weapon_awp") || StrEqual(client_weapon, "weapon_ssg08")){
				client_contract_progress[attacker]++;
				CheckContract(attacker);
			}
		}
		if(client_on_contract[attacker] && StrEqual(client_contract_type[attacker], "x_metre_uzaktan")){
			float obs_attacker[3], obs_olen[3], vector_distance;
			GetClientAbsOrigin(attacker, obs_attacker);
			GetClientAbsOrigin(olen, obs_olen);
			vector_distance = GetVectorDistance(obs_attacker, obs_olen);
			CPrintToChat(attacker, "{darkred}%s {green}%f.2 uzaktan vurdun", ptag, vector_distance);
			if(vector_distance >= 1000.0){
				client_contract_progress[attacker]++;
				CheckContract(attacker);
			}
		}
	}
}
public void Event_PlayerMVP(Event hEvent, const char[] sEvName, bool bDontBroadcast){
	if(check_online_p()){
		int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
		if (valid_client(client) && client_on_contract[client] && StrEqual(client_contract_type[client], "MVP")){
			client_contract_progress[client]++;
			CheckContract(client);
		}
	}
}
public void Event_RoundEnd(Event hEvent, const char[] sEvName, bool bDontBroadcast){
	if(check_online_p()){
		for (int i = 1; i <= MaxClients; i++){
			if (valid_client(i) && hatirlatma_sayisi == 5 && !client_on_contract[i]){
				CPrintToChat(i, "{darkred}%s Herhangi bir kontrat imzalamamış gözüküyorsunuz imzalamak isterseniz {orange}!gorevler", ptag);
			}
			if (valid_client(i) && client_on_contract[i] && StrEqual(client_contract_type[i], "x_Round_Hayatta_Kal", false)){
				if (IsPlayerAlive(i)){
					client_contract_progress[i]++;
					CheckContract(i);
				}
			}
			if (valid_client(i) && client_on_contract[i] && StrEqual(client_contract_type[i], "CT_Olarak", false)){
				if (GetClientTeam(i) == 3 && IsPlayerAlive(i)){
					client_contract_progress[i]++;
					CheckContract(i);					
				}     
			}
			if (valid_client(i) && client_on_contract[i] && StrEqual(client_contract_type[i], "T_Olarak", false)){
				if (GetClientTeam(i) == 2 && IsPlayerAlive(i)){
					client_contract_progress[i]++;
					CheckContract(i);
				}
			}
		}
	}
	if (hatirlatma_sayisi < 5)hatirlatma_sayisi++;
	else hatirlatma_sayisi = 0;
}
public void Event_RoundStart(Event hEvent, const char[] sEvName, bool bDontBroadcast){
	if(check_online_p()){
		for (int i = 1; i <= MaxClients; i++){
			if (valid_client(i) && client_on_contract[i]){
				CheckContract(i);
			}
		}
	}
}
// SQL //
public int OnSQLConnect(Handle owner, Handle hndl, char [] error, any data){
	if(hndl == null){
		LogError("Database failure: %s", error);
		SetFailState("Databases dont work");
	}
	else{
		g_hDB = hndl;
		SQL_SetCharset(g_hDB, "utf8mb4");
		SQL_GetDriverIdent(SQL_ReadDriver(g_hDB), g_sSQLBuffer, sizeof(g_sSQLBuffer));
		g_bIsMySQl = StrEqual(g_sSQLBuffer,"mysql", false) ? true : false;
		
		if(g_bIsMySQl)
		{
			Format(g_sSQLBuffer, sizeof(g_sSQLBuffer), "CREATE TABLE IF NOT EXISTS `contracts` (`playername` varchar(128) CHARACTER SET utf8 COLLATE utf8_turkish_ci NOT NULL, `steamid` varchar(32) PRIMARY KEY NOT NULL, `last_accountuse` int(64) NOT NULL, `in_game`INT(16), `contract_name` varchar(128) CHARACTER SET utf8 COLLATE utf8_turkish_ci NOT NULL, `contract_type` varchar(128) CHARACTER SET utf8 COLLATE utf8_turkish_ci NOT NULL, `contract_weapon` varchar(128) CHARACTER SET utf8 COLLATE utf8_turkish_ci NOT NULL, `contract_objective` INT( 16 ), `contract_progress` INT( 16 ), `contract_reward` INT( 16 ), `contract_info` varchar(256) CHARACTER SET utf8 COLLATE utf8_turkish_ci NOT NULL)");
			SQL_TQuery(g_hDB, OnSQLConnectCallback, g_sSQLBuffer, 0);
			Format(g_sSQLBuffer, sizeof(g_sSQLBuffer), "CREATE TABLE IF NOT EXISTS `contracts_top` (`playername` varchar(128) CHARACTER SET utf8 COLLATE utf8_turkish_ci NOT NULL, `steamid` varchar(32) PRIMARY KEY NOT NULL, `completed_contracts`INT(16))");
			SQL_TQuery(g_hDB, OnSQLConnectCallback, g_sSQLBuffer, 1);
		}
		else
		{
			Format(g_sSQLBuffer, sizeof(g_sSQLBuffer), "CREATE TABLE IF NOT EXISTS contracts (playername varchar(128) NOT NULL, steamid varchar(32) PRIMARY KEY NOT NULL, last_accountuse int(64) NOT NULL, in_game INT(16), contract_name varchar(128) NOT NULL, contract_type varchar(128) NOT NULL, contract_weapon varchar(128) NOT NULL, contract_objective INT( 16 ), contract_progress INT( 16 ), contract_reward INT( 16 ), contract_info varchar(256) NOT NULL)");
			SQL_TQuery(g_hDB, OnSQLConnectCallback, g_sSQLBuffer);
		}
	}
}

public int OnSQLConnectCallback(Handle owner, Handle hndl, char [] error, any data){
	if(hndl == null)
	{
		LogError("Query failure: %s", error);
		return;
	}
	if(data == 0){
		delete_contracts_10mn();
		for(int client = 1; client <= MaxClients; client++)
		{
			if(valid_client(client))
			{
				OnClientPutInServer(client);
			}
		}
	}
}

void sql_add_new_client_contract(int client){
	if(!valid_client(client))
		return;
	char query[512], steamid[32], Name[256];
	GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
	int userid = GetClientUserId(client);
	if(!GetClientName(client, Name, sizeof(Name)))
		Format(Name, sizeof(Name), "<noname>");
	else{
		GetClientName(client, Name, sizeof(Name));
	}
	Format(query, sizeof(query), "INSERT INTO contracts(`playername`, `steamid`, `last_accountuse`, `in_game`, `contract_name`, `contract_type`, `contract_weapon`, `contract_objective`, `contract_progress`, `contract_reward`, `contract_info`) VALUES(\"%s\", '%s', '%d', '1', '%s', '%s', '%s', '%i', '0', '%i', '%s');", Name, steamid, GetTime(), client_contract_name[client], client_contract_type[client], client_contract_weapon[client], client_contract_obj[client], client_contract_reward[client], client_contract_info[client]);
	SQL_TQuery(g_hDB, SaveSQLPlayerCallback, query, userid);
}

void sql_load_client_contract(int client){
	if(!valid_client(client))
		return;
	char query[255], steamid[32];
	GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
	Format(query, sizeof(query), "SELECT contract_name, contract_type, contract_weapon, contract_objective, contract_progress, contract_reward, contract_info, last_accountuse FROM contracts WHERE steamid = '%s'", steamid);
	SQL_TQuery(g_hDB, CheckSQLSteamIDCallback, query, GetClientUserId(client));
}
void sql_client_contract_ex(int client, const char[] whatfor){
	if(!valid_client(client))
		return;
	char buffer[255], steamid[32];
	GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
	Format(buffer, sizeof(buffer), "DELETE FROM `contracts` WHERE `steamid`= '%s';", steamid);
	SQL_TQuery(g_hDB, SaveSQLPlayerCallback, buffer);
	int userid = GetClientUserId(client);
	if (StrEqual(whatfor, "check")){
		Format(buffer, sizeof(buffer), "SELECT completed_contracts FROM contracts_top WHERE steamid = '%s'", steamid);
		SQL_TQuery(g_hDB, CheckSQLPlayerTop, buffer, userid);
	}
}
public int CheckSQLPlayerTop(Handle owner, Handle hndl, char [] error, any data){
	int client, comp_contracts = 0;
	char query[256], steamid[64], Name[100];
	if((client = GetClientOfUserId(data)) == 0){
		return;
	}
	if(hndl == null){
		LogError("Query failure: %s", error);
		return;
	}
	GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
	if(!GetClientName(client, Name, sizeof(Name)))
		Format(Name, sizeof(Name), "<noname>");
	else{
		GetClientName(client, Name, sizeof(Name));
	}
	if(!SQL_GetRowCount(hndl) || !SQL_FetchRow(hndl)) {
		Format(query, sizeof(query), "INSERT INTO contracts_top(`playername`, `steamid`, `completed_contracts`) VALUES (\"%s\", '%s', '1')", Name, steamid);
		SQL_TQuery(g_hDB, SaveSQLPlayerCallback, query, client);
		return;
	}
	comp_contracts = SQL_FetchInt(hndl, 0) + 1;
	Format(query, sizeof(query), "UPDATE contracts_top SET playername = \"%s\", completed_contracts = %i WHERE steamid = '%s'", Name, comp_contracts, steamid);
	SQL_TQuery(g_hDB, SaveSQLPlayerCallback, query, client);
}
public int CheckSQLSteamIDCallback(Handle owner, Handle hndl, char [] error, any data){
	int client,
		last_con;
	if((client = GetClientOfUserId(data)) == 0){
		return;
	}
	if(hndl == null){
		LogError("Query failure: %s", error);
		return;
	}
	if(!SQL_GetRowCount(hndl) || !SQL_FetchRow(hndl)) {
		reset_client_bool(client);
		return;
	}
	last_con = SQL_FetchInt(hndl, 7);
	if(GetTime() - last_con > 300){
		reset_client_bool(client);
		sql_client_contract_ex(client, "iptal");
		return;
	}
	SQL_FetchString(hndl, 0, client_contract_name[client], sizeof(client_contract_name[]));
	SQL_FetchString(hndl, 1, client_contract_type[client], sizeof(client_contract_type[]));
	SQL_FetchString(hndl, 2, client_contract_weapon[client], sizeof(client_contract_weapon[]));
	SQL_FetchString(hndl, 6, client_contract_info[client], sizeof(client_contract_info[]));
	client_contract_reward[client] = SQL_FetchInt(hndl, 5);
	client_contract_progress[client] = SQL_FetchInt(hndl, 4);
	client_contract_obj[client] = SQL_FetchInt(hndl, 3);
	client_on_contract[client] = true;
	if (StrEqual(client_contract_type[client], "WALK")){
		if(!g_check_walk[client])g_check_walk[client] = CreateTimer(0.5, TMR_CheckWalk, client, TIMER_REPEAT);
		else{
			g_check_walk[client] = INVALID_HANDLE;
			g_check_walk[client] = CreateTimer(0.5, TMR_CheckWalk, client, TIMER_REPEAT);
		}
	}
	sql_update_client_contract(client, 1);
}

void sql_update_client_contract(int client, int in_game_value){
	char steamid[32], buffer[3096], Name[256];
	GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
	if(!GetClientName(client, Name, sizeof(Name))){
		Format(Name, sizeof(Name), "<noname>");
	}
	else{
		GetClientName(client, Name, sizeof(Name));
	}
	Format(buffer, sizeof(buffer), "UPDATE contracts SET playername = \"%s\", last_accountuse = %d, in_game = %i, contract_progress = '%i' WHERE steamid = '%s'", Name, GetTime(), in_game_value, client_contract_progress[client], steamid);
	SQL_TQuery(g_hDB, SaveSQLPlayerCallback, buffer);
}

public int SaveSQLPlayerCallback(Handle owner, Handle hndl, char [] error, any data){
	if(hndl == null)
	{
		LogError("Query failure: %s", error);
	}
}
// FUNCTİONS
void reset_client_bool(int client){
	if (!valid_client(client))return;
	client_contract_name[client] = "";
	client_contract_type[client] = "";
	client_contract_weapon[client] = "";
	client_contract_info[client] = "";
	client_contract_reward[client] = 0;
	client_contract_progress[client] = 0;
	client_contract_obj[client] = 0;
	client_on_contract[client] = false;
	if(g_check_walk[client]){
		g_check_walk[client] = INVALID_HANDLE;
	}
}
bool valid_client(int client){
	return (IsClientInGame(client) && !IsFakeClient(client));
}
bool check_online_p(){
	online_players = 4;
	for (int i = 1; i <= MaxClients; i++){
		if (IsClientInGame(i) && !IsFakeClient(i)){
			online_players++;
		}
	}
	return (online_players > 3);
}
void CheckContract(int client){
	if(check_online_p()){
		if (valid_client(client)){
			if (!client_on_contract[client])return;	
			if (client_contract_progress[client] < client_contract_obj[client])return;
			Store_SetClientCredits(client, Store_GetClientCredits(client) + client_contract_reward[client]);
			CPrintToChat(client, "{darkred}%s {green}Başarılı bir şekilde sözleşmenizi tamamladınız, ödülünüz verildi. {orange}[%i]", ptag, client_contract_reward[client]);
			reset_client_bool(client);
			sql_client_contract_ex(client, "check");
		}
	}
}
stock bool ReadContract(){
	char cName[100],
		actioN[50],
		reward[10],
		weapon[10],
		objective[10],
		info[256],
		full_info[256];
	
	ARRAY_Contracts = CreateArray();
	contract_ex_array = CreateArray();
	char path[PLATFORM_MAX_PATH];
	Handle kv = CreateKeyValues("Kontrat Ayarlari");
	BuildPath(Path_SM, path, sizeof(path), "configs/gorevler/Kontratlar.ini");
	FileToKeyValues(kv, path);
	if (!KvGotoFirstSubKey(kv))
		return;
	do{
		KvGetString(kv, FIELD_CONTRACT_NAME, cName, sizeof(cName));
		KvGetString(kv, FIELD_CONTRACT_ACTION, actioN, sizeof(actioN));
		KvGetString(kv, FIELD_CONTRACT_OBJECTIVE, objective, sizeof(objective));
		KvGetString(kv, FIELD_CONTRACT_REWARD, reward, sizeof(reward));
		KvGetString(kv, FIELD_CONTRACT_WEAPON, weapon, sizeof(weapon));
		KvGetString(kv, FIELD_CONTRACT_Info, info, sizeof(info));
		if (strlen(weapon) > 0){
			Format(full_info, sizeof(full_info), info, weapon, objective);
		}else{
			Format(full_info, sizeof(full_info), info, objective);
		}
		Handle tmpTrie = CreateTrie();
		SetTrieString(tmpTrie, FIELD_CONTRACT_NAME, cName, false);
		SetTrieString(tmpTrie, FIELD_CONTRACT_ACTION, actioN, false);
		SetTrieValue(tmpTrie, FIELD_CONTRACT_OBJECTIVE, StringToInt(objective), false);
		SetTrieValue(tmpTrie, FIELD_CONTRACT_REWARD, StringToInt(reward), false);
		SetTrieString(tmpTrie, FIELD_CONTRACT_WEAPON, weapon, false);
		SetTrieString(tmpTrie, FIELD_CONTRACT_Info, full_info, false);
		
		PushArrayCell(ARRAY_Contracts, tmpTrie);
		
	} while (KvGotoNextKey(kv));
	
	CloseHandle(kv);
}
void client_contract_iptal(int client){
	if(!valid_client(client)){
		return;
	}if(!client_on_contract[client]){
		return;
	}
	reset_client_bool(client);
	sql_client_contract_ex(client, "iptal");
	char steamid[64];
	GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
	Handle tmpTrie = CreateTrie();
	SetTrieString(tmpTrie, "client_steamid", steamid, false);
	SetTrieValue(tmpTrie, "ex_time", GetTime(), false);
	PushArrayCell(contract_ex_array, tmpTrie);
	CPrintToChat(client, "{darkred}%s {green}Kontratın iptal edildi.", ptag);
}
void delete_contracts_10mn(){
	char buffer[256];
	Format(buffer, sizeof(buffer), "DELETE FROM `contracts` WHERE %d - `last_accountuse` > 599 AND `last_accountuse` > 0 AND `in_game` = '0';", GetTime());
	SQL_TQuery(g_hDB, SaveSQLPlayerCallback, buffer);
}
bool CheckKillMethod(int client){
	char sWeapon[100];
	int aWeapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
	if (IsValidEntity(aWeapon))
		GetEntPropString(aWeapon, Prop_Data, "m_iClassname", sWeapon, sizeof(sWeapon));

	if (StrEqual(client_contract_weapon[client], sWeapon)){
		return true;
	}
	return false;
}
bool client_in_ex_array(int client){
	int size = GetArraySize(contract_ex_array);
	char a_steamid[64], steamid[64];
	int exx_time;
	GetClientAuthId(client, AuthId_Steam2, steamid, 64);
	for (int i = 0; i < size; i++){
		Handle trie = GetArrayCell(contract_ex_array, i);
		GetTrieString(trie, "client_steamid", a_steamid, 64);
		GetTrieValue(trie, "ex_time", exx_time);
		if (StrEqual(steamid, a_steamid)){
			int fark = GetTime() - exx_time;
			if(fark < 300){
				return true;
			}else{
				RemoveFromArray(contract_ex_array, i);
				return false;
			}
		}
	}
	return false;
}