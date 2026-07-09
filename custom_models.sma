#include <amxmodx>
#include <reapi>

enum _:MDL 
{ 
	ACCESS[32], 
	MDL_T[64], 
	MDL_CT[64] 
}	// ip, steam, flag, #, *. # - steam; * - РІСЃРµРј 

new g_szPlayerModel[33][TeamName][64];
new Array:g_aModels, g_MdlInfo[MDL];

public plugin_precache()
{
	new szPath[64]; 
	get_localinfo("amxx_configsdir", szPath, charsmax(szPath));
	add(szPath, charsmax(szPath), "/custom_models.ini");
	
	new fp = fopen(szPath, "rt");
	if(!fp)
	{
	#if AMXX_VERSION_NUM < 183
		new szError[96];
		formatex(szError, charsmax(szError), "File '%s' not found!", szPath);
		set_fail_state(szError);
	#else
		set_fail_state("File '%s' not found!", szPath);
	#endif
	}
	g_aModels = ArrayCreate(MDL);
	
	new buff[190], t, ct, str[64];
	while(!feof(fp))
	{
		fgets(fp, buff, charsmax(buff)); trim(buff);
		if(!buff[0] || buff[0] == ';')
			continue;
		if(parse(buff, 
			g_MdlInfo[ACCESS], charsmax(g_MdlInfo[ACCESS]), 
			g_MdlInfo[MDL_T], charsmax(g_MdlInfo[MDL_T]), 
			g_MdlInfo[MDL_CT], charsmax(g_MdlInfo[MDL_CT])) == 3
		)
		{
			formatex(str, charsmax(str), "models/player/%s/%s.mdl", g_MdlInfo[MDL_T], g_MdlInfo[MDL_T]);
			t = file_exists(str);
			if(t) 	precache_model(str);
			else	log_amx("[WARNING] Model '%s' not found.", str);
			
			formatex(str, charsmax(str), "models/player/%s/%s.mdl", g_MdlInfo[MDL_CT], g_MdlInfo[MDL_CT]);
			ct = file_exists(str);
			if(ct) 	precache_model(str);
			else	log_amx("[WARNING] Model '%s' not found.", str);
			
			if(t || ct) ArrayPushArray(g_aModels, g_MdlInfo);
		}
	}
	fclose(fp);
	if(!ArraySize(g_aModels))
	{
	#if AMXX_VERSION_NUM < 183
		new szError[96];
		formatex(szError, charsmax(szError), "File '%s' incorrect!", szPath);
		set_fail_state(szError);
	#else
		set_fail_state("File '%s' incorrect!", szPath);
	#endif
	}
}

public plugin_init()
{
	register_plugin("[ReAPI] Custom Models", "1.6.1", "neugomon");
	RegisterHookChain(RG_CBasePlayer_Spawn, "fwdPlayerSpawn_Post", true);
	RegisterHookChain(RG_CBasePlayer_SetClientUserInfoModel, "fwdSetClientUserInfoModel_Pre", false);
}

public client_putinserver(id)
{
	new szIP[16]; 	 get_user_ip(id, szIP, charsmax(szIP), 1);
	new szAuthid[25];get_user_authid(id, szAuthid, charsmax(szAuthid));

	g_szPlayerModel[id][TEAM_TERRORIST][0] = EOS;
	g_szPlayerModel[id][TEAM_CT][0] = EOS;
	
	for(new i, flags = get_user_flags(id), aSize = ArraySize(g_aModels); i < aSize; i++)
	{
		ArrayGetArray(g_aModels, i, g_MdlInfo);
		
		switch(g_MdlInfo[ACCESS][0])
		{
			case '#':
			{
				if(REU_GetAuthtype(id) == CA_TYPE_STEAM)
				{
					CopyModel(id, g_MdlInfo[MDL_T], g_MdlInfo[MDL_CT]);
					break;
				}	
			}
			case '*':
			{
				CopyModel(id, g_MdlInfo[MDL_T], g_MdlInfo[MDL_CT]);
				break;
			}
			case 'S', 'V':
			{
				if(strcmp(g_MdlInfo[ACCESS], szAuthid) == 0)
				{
					CopyModel(id, g_MdlInfo[MDL_T], g_MdlInfo[MDL_CT]);
					break;
				}
			}
			default:
			{
				if(isdigit(g_MdlInfo[ACCESS][0]))
				{
					if(strcmp(g_MdlInfo[ACCESS], szIP) == 0)
					{
						CopyModel(id, g_MdlInfo[MDL_T], g_MdlInfo[MDL_CT]);
						break;
					}
				}
				else if(flags & read_flags(g_MdlInfo[ACCESS]))
				{
					CopyModel(id, g_MdlInfo[MDL_T], g_MdlInfo[MDL_CT]);
					break;
				}
			}
		}
	}
}

public fwdPlayerSpawn_Post(id)
{
	if(!is_user_alive(id))
		return;
		
	switch(TeamName:get_member(id, m_iTeam))
	{
		case TEAM_TERRORIST: 
			if(g_szPlayerModel[id][TEAM_TERRORIST][0]) rg_set_user_model(id, g_szPlayerModel[id][TEAM_TERRORIST]);
		case TEAM_CT: 
			if(g_szPlayerModel[id][TEAM_CT][0]) rg_set_user_model(id, g_szPlayerModel[id][TEAM_CT]);
	}
}

public fwdSetClientUserInfoModel_Pre(const id, infobuffer[], szNewModel[])
{
	new TeamName:iTeam = get_member(id, m_iTeam);
	if(iTeam == TEAM_TERRORIST || iTeam == TEAM_CT)
	{
		if(g_szPlayerModel[id][iTeam][0] && strcmp(szNewModel, g_szPlayerModel[id][iTeam]) != 0)
			SetHookChainArg(3, ATYPE_STRING, g_szPlayerModel[id][iTeam]);
	}		
	return HC_CONTINUE;
}

stock CopyModel(index, modelT[], modelCT[])
{
	copy(g_szPlayerModel[index][TEAM_TERRORIST], charsmax(g_szPlayerModel[][]), modelT);
	copy(g_szPlayerModel[index][TEAM_CT], charsmax(g_szPlayerModel[][]), modelCT);
}