#include < amxmodx >

#include < zombieplague >
#include < hamsandwich >
#include < cstrike >
 
#define PLUGIN  "[ZP]: Custom respawn"
#define VERSION "1.0"
#define AUTHOR  "Weltgericht"

enum (+= 100)
{
	TASK_SPAWN
}

enum cvar
{
	spawndelay,
	amount,
	nemesis,
	survivor,
	plague,
	swarm
}

new pcvar[cvar]
new current[33] = 0 
new bool: ended = false

#define ID_SPAWN (taskid - TASK_SPAWN)

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	events()
	cvars()
}

public events()
{
	RegisterHam(Ham_Spawn, "player", "fw_PlayerSpawn_Post", 1)
	RegisterHam(Ham_Killed, "player", "fw_PlayerKilled")
}

public cvars()
{
	pcvar[spawndelay] = register_cvar("zp_spawn_delay", "10.0")
	pcvar[amount] = register_cvar("zp_spawn_amount", "3")
	
	pcvar[nemesis] = register_cvar("zp_respawn_in_nemesis", "0")
	pcvar[survivor] = register_cvar("zp_respawn_in_survivor", "0")
	pcvar[plague] = register_cvar("zp_respawn_in_plague", "0")
	pcvar[swarm] = register_cvar("zp_respawn_in_swarm", "0")
}

public fw_PlayerSpawn_Post(id)
{
	if(!is_user_alive(id))
		return
		
	remove_task(id+TASK_SPAWN)
	return
}

public fw_PlayerKilled(victim, attacker, shouldgib)
{
	if(zp_is_nemesis_round() && !get_pcvar_num(pcvar[nemesis]))
		return
		
	if(zp_is_survivor_round() && !get_pcvar_num(pcvar[survivor]))
		return
	
	if(zp_is_plague_round() && !get_pcvar_num(pcvar[plague]))
		return

	if(zp_is_swarm_round() && !get_pcvar_num(pcvar[swarm]))
		return

	set_task(get_pcvar_float(pcvar[spawndelay]), "respawn_player_task", victim+TASK_SPAWN)
	return
}

public respawn_player_task(taskid)
{
	if(!is_user_connected(ID_SPAWN))
	{
		remove_task(ID_SPAWN+TASK_SPAWN)
		return
	}

	if(current[ID_SPAWN] >= get_pcvar_num(pcvar[amount]))
	{
		remove_task(ID_SPAWN+TASK_SPAWN)
		return
	}
		
	if(ended)
	{
		remove_task(ID_SPAWN+TASK_SPAWN)
		return
	}

	
	if(cs_get_user_team(ID_SPAWN) != CS_TEAM_SPECTATOR && cs_get_user_team(ID_SPAWN) != CS_TEAM_UNASSIGNED)
	{
		if(zp_is_nemesis_round())
		{
			zp_respawn_user(ID_SPAWN, ZP_TEAM_HUMAN)
			current[ID_SPAWN]++
			return
		}
		else if(zp_is_plague_round())
		{
			random_spawn(ID_SPAWN)
			return
		}
		else if(zp_is_swarm_round())
		{
			random_spawn(ID_SPAWN)
			return
		}
		
		zp_respawn_user(ID_SPAWN, ZP_TEAM_ZOMBIE)
		current[ID_SPAWN]++
	}
	return
}

public zp_round_ended(winter)
{
	ended = true
}

public zp_round_started()
{
	ended = false

	new MaxPlayers = get_maxplayers()
	
	for (new player = 1; player <= MaxPlayers; player++)   
	{
		current[player] = 0
	}
}

stock random_spawn(id)
{
	switch(random_num(0,1))
	{
		case 0:
		{
			zp_respawn_user(id, ZP_TEAM_ZOMBIE)
			current[id]++
		}
		case 1:
		{
			zp_respawn_user(id, ZP_TEAM_HUMAN)
			current[id]++
		}
	}
}