/*****************************************************************
*                            MADE BY
*
*   K   K   RRRRR    U     U     CCCCC    3333333      1   3333333
*   K  K    R    R   U     U    C     C         3     11         3
*   K K     R    R   U     U    C               3    1 1         3
*   KK      RRRRR    U     U    C           33333   1  1     33333
*   K K     R        U     U    C               3      1         3
*   K  K    R        U     U    C     C         3      1         3
*   K   K   R         UUUUU U    CCCCC    3333333      1   3333333
*
******************************************************************
*                       AMX MOD X Script                         *
*     You can modify the code, but DO NOT modify the author!     *
******************************************************************
*
* Description:
* ============
* This is a plugin for Counte-Strike 1.6's Zombie Plague Mod which allows admins and players to give/transfer ammo packs to each other.
*
******************************************************************
*
* Cvars:
* ======
* zp_gap_admins_mode & zp_gap_players_mode:
* 1 - No one views
* 2 - Show only to Giver
* 3 - Show only to Receiver with Giver name
* 4 - Show only to Receiver without Giver name
* 5 - Show to Giver and Receiver with Giver name
* 6 - Show to Giver and Receiver without Giver name
* 7 - Show to All with Giver name
*
*****************************************************************/

#include <amxmodx>
#include <amxmisc>
#include <zombieplague>

#define TAG "GAP"
#define is_user_valid(%1) (1 <= %1 <= g_MaxPlayers)

// Vars
new tempid

// Cvars
new pcv_gap, pcv_gapadmins, pcv_gapadminsmode, pcv_gapplayers, pcv_gapplayersmode, pcv_gapsounds

// Messages
new g_MaxPlayers, g_SayText

public plugin_init() {
	register_plugin("[ZP] Addon: Give Ammo Packs", "1.0", "kpuc313")
	
	register_clcmd("givea", "cmdAdminGive", ADMIN_BAN)
	register_concmd("Admin Ammo Packs", "cmdAdminAmmoPacks", ADMIN_BAN)
	
	register_clcmd("give", "cmdUserGive", ADMIN_ALL)
	register_concmd("Ammo Packs", "cmdUserAmmoPacks", ADMIN_ALL)
	
	pcv_gap = register_cvar("zp_gap", "1")
	pcv_gapadmins = register_cvar("zp_gap_admins", "1")
	pcv_gapadminsmode = register_cvar("zp_gap_admins_mode", "1")
	pcv_gapplayers = register_cvar("zp_gap_players", "1")
	pcv_gapplayersmode = register_cvar("zp_gap_players_mode", "5")
	pcv_gapsounds = register_cvar("zp_gap_sounds", "1")
	
	g_MaxPlayers = get_maxplayers()
	g_SayText = get_user_msgid("SayText")
}

public cmdAdminGive(id,level,cid) {
	if(!get_pcvar_num(pcv_gap) || !get_pcvar_num(pcv_gapadmins)) return PLUGIN_HANDLED
	if(!cmd_access(id,level,cid,1)) return PLUGIN_HANDLED
	
	cmdAdminGiveMenu(id)
	
	return PLUGIN_HANDLED
}

public cmdAdminGiveMenu(id) {
	new menu = menu_create("Admin Give Ammo Packs\r", "cmdAdminGiveMenu2")

	new players[32], pnum, tempid
	new szName[32], szName2[100], szTempid[10]
	get_players(players, pnum)
	
	for(new i; i < pnum; i++ )
	{
		tempid = players[i]

		get_user_name(tempid, szName, charsmax(szName))
		formatex(szName2, charsmax(szName2), "%s \r[AP: %d]", szName, zp_get_user_ammo_packs(tempid))
		num_to_str(tempid, szTempid, charsmax(szTempid))
		menu_additem(menu, szName2, szTempid, 0);
	}

	menu_display(id, menu, 0);
}

public cmdAdminGiveMenu2(id, menu, item) {
	if(item == MENU_EXIT)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	new data[6], szName[64], user[32];
	new access, callback;
	menu_item_getinfo(menu, item, access, data,charsmax(data), szName,charsmax(szName), callback);

	tempid = str_to_num(data)
	get_user_name(tempid, user, charsmax(user))
	
	client_cmd(id, "messagemode ^"Admin Ammo Packs^"")
	colormsg(id, "\g[%s] \nWrite in chat how much ammo packs to give to \t%s", TAG, user)

	menu_destroy(menu);
	return PLUGIN_HANDLED;
}

public cmdAdminAmmoPacks(id,level,cid) {
	if(!get_pcvar_num(pcv_gap) || !get_pcvar_num(pcv_gapadmins)) return PLUGIN_HANDLED
	if(!cmd_access(id,level,cid,1)) return PLUGIN_HANDLED
	
	new amount_ap[32], num_ap, user1[32], user2[32]
	read_argv(3, amount_ap, charsmax(amount_ap));
	
	num_ap = str_to_num(amount_ap)
	
	get_user_name(id, user1, charsmax(user1))
	get_user_name(tempid, user2, charsmax(user2))
	
	if(!is_user_valid(tempid)) {
		if(get_pcvar_num(pcv_gapsounds)) client_cmd(id, "spk buttons/button2")
		client_cmd(id, "messagemode ^"Ammo Packs^"")
		colormsg(id, "\g[%s] \nYou can give ammo packs only to players", TAG)
		return PLUGIN_HANDLED
	}
	
	if(num_ap <= 0) {
		if(get_pcvar_num(pcv_gapsounds)) client_cmd(id, "spk buttons/button2")
		client_cmd(id, "messagemode ^"Admin Ammo Packs^"")
		colormsg(id, "\g[%s] \nYou can give only positive ammo packs", TAG)
		return PLUGIN_HANDLED
	}
	
	switch(get_pcvar_num(pcv_gapadminsmode)) {
		// No one views
		case 1:
		{
			// Nothing
		}
		// Show only to Giver
		case 2:
		{
			if(get_pcvar_num(pcv_gapsounds)) client_cmd(id, "spk buttons/bell1")
			colormsg(id, "\g[%s] \nYou give \t%d \nAmmo Packs to \t%s", TAG, num_ap, user2)
		}
		// Show only to Receiver with Giver name
		case 3:
		{
			if(get_pcvar_num(pcv_gapsounds)) client_cmd(tempid, "spk buttons/bell1")
			colormsg(tempid, "\g[%s] \nYou receive \t%d \nAmmo Packs from \t%s", TAG, num_ap, user1)
		}
		// Show only to Receiver without Giver name
		case 4:
		{
			if(get_pcvar_num(pcv_gapsounds)) client_cmd(tempid, "spk buttons/bell1")
			colormsg(tempid, "\g[%s] \nYou receive \t%d \nAmmo Packs from \tAdmin", TAG, num_ap)
		}
		// Show to Giver and Receiver with Giver name
		case 5:
		{
			if(get_pcvar_num(pcv_gapsounds)) client_cmd(id, "spk buttons/bell1")
			if(get_pcvar_num(pcv_gapsounds)) client_cmd(tempid, "spk buttons/bell1")
			colormsg(id, "\g[%s] \nYou give \t%d \nAmmo Packs to \t%s", TAG, num_ap, user2)
			colormsg(tempid, "\g[%s] \nYou receive \t%d \nAmmo Packs from \t%s", TAG, num_ap, user1)
		}
		// Show to Giver and Receiver without Giver name
		case 6:
		{
			if(get_pcvar_num(pcv_gapsounds)) client_cmd(id, "spk buttons/bell1")
			if(get_pcvar_num(pcv_gapsounds)) client_cmd(tempid, "spk buttons/bell1")
			colormsg(id, "\g[%s] \nYou give \t%d \nAmmo Packs to \t%s", TAG, num_ap, user2)
			colormsg(tempid, "\g[%s] \nYou receive \t%d \nAmmo Packs from \tAdmin", TAG, num_ap)
		}
		// Show to All with Giver name
		case 7:
		{
			if(get_pcvar_num(pcv_gapsounds)) client_cmd(id, "spk buttons/bell1")
			if(get_pcvar_num(pcv_gapsounds)) client_cmd(tempid, "spk buttons/bell1")
			colormsg(0, "\g[%s] \t%s \ngive \t%d \nAmmo Packs to \t%s", TAG, user1, num_ap, user2)
			colormsg(tempid, "\g[%s] \nYou receive \t%d \nAmmo Packs from \t%s", TAG, num_ap, user1)
		}
	}
	
	zp_set_user_ammo_packs(tempid, zp_get_user_ammo_packs(tempid) + num_ap)
	
	return PLUGIN_HANDLED;
}

public cmdUserGive(id,level,cid) {
	if(!get_pcvar_num(pcv_gap) || !get_pcvar_num(pcv_gapplayers)) return PLUGIN_HANDLED
	if(!cmd_access(id,level,cid,1)) return PLUGIN_HANDLED
	
	cmdUserGiveMenu(id)
	
	return PLUGIN_HANDLED
}

public cmdUserGiveMenu(id) {
	new menu = menu_create("Give Ammo Packs\r", "cmdUserGiveMenu2")

	new players[32], pnum, tempid
	new szName[32], szName2[100], szTempid[10]
	get_players(players, pnum)
	
	for(new i; i < pnum; i++ )
	{
		tempid = players[i]

		get_user_name(tempid, szName, charsmax(szName))
		formatex(szName2, charsmax(szName2), "%s \r[AP: %d]", szName, zp_get_user_ammo_packs(tempid))
		num_to_str(tempid, szTempid, charsmax(szTempid))

		if(id != tempid)
		menu_additem(menu, szName2, szTempid, 0);
	}

	menu_display(id, menu, 0);
}

public cmdUserGiveMenu2(id, menu, item) {
	if(item == MENU_EXIT)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	new data[6], szName[64], user[32];
	new access, callback;
	menu_item_getinfo(menu, item, access, data,charsmax(data), szName,charsmax(szName), callback);

	tempid = str_to_num(data)
	get_user_name(tempid, user, charsmax(user))
	
	client_cmd(id, "messagemode ^"Ammo Packs^"")
	colormsg(id, "\g[%s] \nWrite in chat how much ammo packs to give to \t%s", TAG, user)

	menu_destroy(menu);
	return PLUGIN_HANDLED;
}

public cmdUserAmmoPacks(id,level,cid) {
	if(!get_pcvar_num(pcv_gap) || !get_pcvar_num(pcv_gapplayers)) return PLUGIN_HANDLED
	if(!cmd_access(id,level,cid,1)) return PLUGIN_HANDLED
	
	new amount_ap[32], num_ap, user1[32], user2[32]
	read_argv(2, amount_ap, charsmax(amount_ap));
	
	num_ap = str_to_num(amount_ap)
	
	get_user_name(id, user1, charsmax(user1))
	get_user_name(tempid, user2, charsmax(user2))
	
	if(!is_user_valid(tempid)) {
		if(get_pcvar_num(pcv_gapsounds)) client_cmd(id, "spk buttons/button2")
		client_cmd(id, "messagemode ^"Ammo Packs^"")
		colormsg(id, "\g[%s] \nYou can give ammo packs only to players", TAG)
		return PLUGIN_HANDLED
	}
	
	if(zp_get_user_ammo_packs(id) < num_ap) {
		if(get_pcvar_num(pcv_gapsounds)) client_cmd(id, "spk buttons/button2")
		client_cmd(id, "messagemode ^"Ammo Packs^"")
		colormsg(id, "\g[%s] \nYou don't have enough ammo packs", TAG)
		return PLUGIN_HANDLED
	}
	
	if(num_ap <= 0) {
		if(get_pcvar_num(pcv_gapsounds)) client_cmd(id, "spk buttons/button2")
		client_cmd(id, "messagemode ^"Ammo Packs^"")
		colormsg(id, "\g[%s] \nYou can give only positive ammo packs", TAG)
		return PLUGIN_HANDLED
	}
	
	switch(get_pcvar_num(pcv_gapplayersmode)) {
		// No one views
		case 1:
		{
			// Nothing
		}
		// Show only to Giver
		case 2:
		{
			if(get_pcvar_num(pcv_gapsounds)) client_cmd(id, "spk buttons/bell1")
			colormsg(id, "\g[%s] \nYou give \t%d \nAmmo Packs to \t%s", TAG, num_ap, user2)
		}
		// Show only to Receiver with Giver name
		case 3:
		{
			if(get_pcvar_num(pcv_gapsounds)) client_cmd(tempid, "spk buttons/bell1")
			colormsg(tempid, "\g[%s] \nYou receive \t%d \nAmmo Packs from \t%s", TAG, num_ap, user1)
		}
		// Show only to Receiver without Giver name
		case 4:
		{
			if(get_pcvar_num(pcv_gapsounds)) client_cmd(tempid, "spk buttons/bell1")
			colormsg(tempid, "\g[%s] \nYou receive \t%d \nAmmo Packs from \tPlayer", TAG, num_ap)
		}
		// Show to Giver and Receiver with Giver name
		case 5:
		{
			if(get_pcvar_num(pcv_gapsounds)) client_cmd(id, "spk buttons/bell1")
			if(get_pcvar_num(pcv_gapsounds)) client_cmd(tempid, "spk buttons/bell1")
			colormsg(id, "\g[%s] \nYou give \t%d \nAmmo Packs to \t%s", TAG, num_ap, user2)
			colormsg(tempid, "\g[%s] \nYou receive \t%d \nAmmo Packs from \t%s", TAG, num_ap, user1)
		}
		// Show to Giver and Receiver without Giver name
		case 6:
		{
			if(get_pcvar_num(pcv_gapsounds)) client_cmd(id, "spk buttons/bell1")
			if(get_pcvar_num(pcv_gapsounds)) client_cmd(tempid, "spk buttons/bell1")
			colormsg(id, "\g[%s] \nYou give \t%d \nAmmo Packs to \t%s", TAG, num_ap, user2)
			colormsg(tempid, "\g[%s] \nYou receive \t%d \nAmmo Packs from \tPlayer", TAG, num_ap)
		}
		// Show to All with Giver name
		case 7:
		{
			if(get_pcvar_num(pcv_gapsounds)) client_cmd(id, "spk buttons/bell1")
			if(get_pcvar_num(pcv_gapsounds)) client_cmd(tempid, "spk buttons/bell1")
			colormsg(0, "\g[%s] \t%s \ngive \t%d \nAmmo Packs to \t%s", TAG, user1, num_ap, user2)
			colormsg(tempid, "\g[%s] \nYou receive \t%d \nAmmo Packs from \t%s", TAG, num_ap, user1)
		}
	}
	
	zp_set_user_ammo_packs(id, zp_get_user_ammo_packs(id) - num_ap)
	zp_set_user_ammo_packs(tempid, zp_get_user_ammo_packs(tempid) + num_ap)
	
	return PLUGIN_HANDLED;
}

stock colormsg(const id, const string[], {Float, Sql, Resul,_}:...) {
	new msg[191], players[32], count = 1;
	vformat(msg, sizeof msg - 1, string, 3);
	
	replace_all(msg,190,"\g","^4");
	replace_all(msg,190,"\n","^1");
	replace_all(msg,190,"\t","^3");
	
	if(id)
		players[0] = id;
	else
		get_players(players,count,"ch");
	
	for (new i = 0 ; i < count ; i++)
	{
		if (is_user_connected(players[i]))
		{
			message_begin(MSG_ONE_UNRELIABLE, g_SayText,_, players[i]);
			write_byte(players[i]);
			write_string(msg);
			message_end();
		}		
	}
}
