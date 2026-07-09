#include <amxmodx>
#include <amxmisc>
#include <zombieplague>

#define PLUGIN "ZP_Damage_Instead_of_Infection"
#define VERSION "1.0"
#define AUTHOR "Your Name"

public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR);
    zp_register_extra_item("Disable Infection", 0, ZP_TEAM_ZOMBIE);
}

public zp_user_infected_pre(id, infector) {
    return PLUGIN_HANDLED;
}

public zp_user_humanized_pre(id) {
    return PLUGIN_HANDLED;
}

public client_damage(attacker, victim, damage, wpnindex, hitplace, TA) {
    if (!is_user_alive(attacker) || !is_user_alive(victim))
        return PLUGIN_CONTINUE;

    if (zp_get_user_zombie(attacker) && !zp_get_user_zombie(victim)) {
        new health = get_user_health(victim);

        if (health - damage <= 0) {
            user_kill(victim);
            set_task(0.1, "respawn_as_zombie", victim);
            zp_set_user_ammo_packs(attacker, zp_get_user_ammo_packs(attacker) + 1);
            return PLUGIN_HANDLED;
        }
    }
    return PLUGIN_CONTINUE;
}

public respawn_as_zombie(id) {
    if (!is_user_connected(id))
        return;

    if (is_user_alive(id))
        return;

    // CRITICAL VERSION FIX: Changed from zp_make_user_zombie to zp_infect_user
    zp_infect_user(id, 0, 0, 1); 
    user_silentkill(id);
    zp_respawn_user(id, ZP_TEAM_ZOMBIE);
}

public zp_round_started(gamemode_id) {
    return PLUGIN_CONTINUE;
}
