/*
  [ZP] Bot Zombies - Force Attack Near Humans, Mines & Sandbags (with Cooldown + Auto-Aim)
  - Works without pev_numentities, find_first/find_next, or break.
  - Added: bots automatically aim at mines and sandbags before attacking
*/

#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <zombieplague>
#include <xs>                  // REQUIRED for vector math

#define PLUGIN    "[ZP]-Bot Detect Mines & Sandbags"
#define VERSION   "1.7"
#define AUTHOR    "LyesMC"

#define THINK_INTERVAL 0.25
#define PULSE_LENGTH   0.10
#define COOLDOWN_MIN   0.5
#define COOLDOWN_MAX   1.0
#define OFFSET_ACTIVE_ITEM 373
#define OFFSET_LINUX 5
#define ATTACK_RANGE 220.0
#define MINE_ATTACK_RANGE 65.0
#define MAX_ENTITIES 2048

new Float:g_nextAttackTime[33]; // next time bot can attack
new g_debug_cvar;

// Sandbag classname
new const SB_CLASSNAME[] = "amxx_pallets";

// Scarecrow classname
new const SCARECROW_CLASSNAME[] = "placed_scarecrow";

// -----------------------------------------
public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR);
    g_debug_cvar = register_cvar("zp_bot_force_attack_debug", "0");
    set_task(THINK_INTERVAL, "BotForceAttackThink", _, _, _, "b");
}

// -----------------------------------------
public BotForceAttackThink()
{
    new Float:gameTime = get_gametime();
    new players[32], count;
    get_players(players, count, "a");

    for (new i = 0; i < count; i++)
    {
        new id = players[i];

        if (!is_user_connected(id) || !is_user_alive(id)) continue;
        if (!is_user_bot(id) || !zp_get_user_zombie(id)) continue;
        if (gameTime < g_nextAttackTime[id]) continue; // cooldown

        new target = 0;
        new bool:isMine = false;
        new Float:bestDist = 99999.0;
        new Float:botOrigin[3];
        pev(id, pev_origin, botOrigin);

        // ----------------------
        // Detect nearest mine, sandbag or scarecrow
        new Float:entPos[3];
        new szClass[32];

        for (new ent = 0; ent < MAX_ENTITIES; ent++)
        {
            if (!pev_valid(ent)) continue;
            pev(ent, pev_classname, szClass, charsmax(szClass));

            // Detect lasermine, tripmine, sandbag, scarecrow
            if (!equali(szClass, "lasermine")
                && !equali(szClass, "zp_sentry")
                && !equali(szClass, SB_CLASSNAME)
                && !equali(szClass, SCARECROW_CLASSNAME))
                continue;

            pev(ent, pev_origin, entPos);
            new Float:dist = get_distance_f(botOrigin, entPos);

            if (dist <= MINE_ATTACK_RANGE && dist < bestDist)
            {
                bestDist = dist;
                target = ent;
                isMine = true;
            }
        }

        // ----------------------
        // If nothing in range → skip
        if (bestDist > ATTACK_RANGE && !isMine) continue;

        // ----------------------
        // Auto-Aim at target
        if (target)
        {
            AimAtEntity(id, target);
        }

        // ----------------------
        // Attack logic
        engclient_cmd(id, "weapon_knife");
        engclient_cmd(id, "+attack");
        set_task(PULSE_LENGTH, "BotStopAttack", id);

        new weapon_ent = get_pdata_cbase(id, OFFSET_ACTIVE_ITEM, OFFSET_LINUX);
        if (weapon_ent) ExecuteHam(Ham_Weapon_PrimaryAttack, weapon_ent);

        // ----------------------
        // cooldown
        new Float:cooldown = random_float(COOLDOWN_MIN, COOLDOWN_MAX);
        g_nextAttackTime[id] = gameTime + cooldown;

        // ----------------------
        // debug logs
        if (get_pcvar_num(g_debug_cvar) && isMine)
        {
            if (equali(szClass, SB_CLASSNAME))
                log_amx("Bot %d attacked a sandbag (distance %.2f, next in %.2f sec)", id, bestDist, cooldown);
            else if (equali(szClass, SCARECROW_CLASSNAME))
                log_amx("Bot %d attacked a scarecrow (distance %.2f, next in %.2f sec)", id, bestDist, cooldown);
            else
                log_amx("Bot %d attacked a mine (distance %.2f, next in %.2f sec)", id, bestDist, cooldown);
        }
    }
}


// -----------------------------------------
public BotStopAttack(id)
{
    if (!is_user_connected(id) || !is_user_alive(id)) return;
    engclient_cmd(id, "-attack");
}

// -----------------------------------------
stock AimAtEntity(id, ent)
{
    if (!pev_valid(id) || !pev_valid(ent)) return;

    static Float:src[3], Float:dst[3], Float:dir[3], Float:angles[3];

    pev(id, pev_origin, src);
    pev(ent, pev_origin, dst);

    xs_vec_sub(dst, src, dir);
    vector_to_angle(dir, angles);

    angles[0] = -angles[0];

    set_pev(id, pev_v_angle, angles);
    set_pev(id, pev_angles, angles);
}
