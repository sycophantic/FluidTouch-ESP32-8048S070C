#include "ui/wcs_config.h"
#include "ui/machine_config.h"
#include "network/fluidnc_client.h"
#include <Preferences.h>

void WCSConfig::loadWCSConfig(int machine_index, char names[6][32], bool locks[6]) {
    Preferences prefs;
    char namespace_name[32];
    snprintf(namespace_name, sizeof(namespace_name), "machine_%d", machine_index);
    
    prefs.begin(namespace_name, true);  // Read-only
    
    for (int i = 0; i < 6; i++) {
        // Initialize to empty string first to prevent garbage data
        names[i][0] = '\0';
        
        char key_name[16], key_lock[16];
        snprintf(key_name, sizeof(key_name), "wcs_g5%d_name", 4 + i);
        snprintf(key_lock, sizeof(key_lock), "wcs_g5%d_lock", 4 + i);
        
        // Load string (returns empty string if key doesn't exist)
        String name_str = prefs.getString(key_name, "");
        if (name_str.length() > 0) {
            strncpy(names[i], name_str.c_str(), 31);
            names[i][31] = '\0';  // Ensure null termination
        }
        
        locks[i] = prefs.getBool(key_lock, false);
    }
    
    prefs.end();
}

void WCSConfig::saveWCSConfig(int machine_index, const char names[6][32], const bool locks[6]) {
    Preferences prefs;
    char namespace_name[32];
    snprintf(namespace_name, sizeof(namespace_name), "machine_%d", machine_index);
    
    prefs.begin(namespace_name, false);  // Read-write
    
    for (int i = 0; i < 6; i++) {
        char key_name[16], key_lock[16];
        snprintf(key_name, sizeof(key_name), "wcs_g5%d_name", 4 + i);
        snprintf(key_lock, sizeof(key_lock), "wcs_g5%d_lock", 4 + i);
        
        prefs.putString(key_name, names[i]);
        prefs.putBool(key_lock, locks[i]);
    }
    
    prefs.end();
}

void WCSConfig::saveWCSName(int machine_index, int wcs_index, const char* name) {
    if (wcs_index < 0 || wcs_index >= 6) return;
    
    Preferences prefs;
    char namespace_name[32];
    snprintf(namespace_name, sizeof(namespace_name), "machine_%d", machine_index);
    
    prefs.begin(namespace_name, false);  // Read-write
    
    char key_name[16];
    snprintf(key_name, sizeof(key_name), "wcs_g5%d_name", 4 + wcs_index);
    prefs.putString(key_name, name);
    
    prefs.end();
}

void WCSConfig::saveWCSLock(int machine_index, int wcs_index, bool locked) {
    if (wcs_index < 0 || wcs_index >= 6) return;
    
    Preferences prefs;
    char namespace_name[32];
    snprintf(namespace_name, sizeof(namespace_name), "machine_%d", machine_index);
    
    prefs.begin(namespace_name, false);  // Read-write
    
    char key_lock[16];
    snprintf(key_lock, sizeof(key_lock), "wcs_g5%d_lock", 4 + wcs_index);
    prefs.putBool(key_lock, locked);
    
    prefs.end();
}

bool WCSConfig::isCurrentWCSLocked() {
    // Get current WCS from FluidNC status
    const FluidNCStatus& status = FluidNCClient::getStatus();
    int wcs_index = getWCSIndex(status.modal_wcs);
    
    if (wcs_index < 0) return false;  // Invalid WCS
    
    // Load WCS configuration for current machine
    int machine_index = MachineConfigManager::getSelectedMachineIndex();
    char names[6][32];
    bool locks[6];
    loadWCSConfig(machine_index, names, locks);
    
    return locks[wcs_index];
}

void WCSConfig::getCurrentWCSName(char* name_out, size_t max_len) {
    // Get current WCS from FluidNC status
    const FluidNCStatus& status = FluidNCClient::getStatus();
    int wcs_index = getWCSIndex(status.modal_wcs);
    
    if (wcs_index < 0) {
        name_out[0] = '\0';
        return;
    }
    
    // Load WCS configuration for current machine
    int machine_index = MachineConfigManager::getSelectedMachineIndex();
    char names[6][32];
    bool locks[6];
    loadWCSConfig(machine_index, names, locks);
    
    strncpy(name_out, names[wcs_index], max_len - 1);
    name_out[max_len - 1] = '\0';
}

int WCSConfig::getWCSIndex(const char* wcs_code) {
    if (!wcs_code) return -1;
    
    if (strcmp(wcs_code, "G54") == 0) return 0;
    if (strcmp(wcs_code, "G55") == 0) return 1;
    if (strcmp(wcs_code, "G56") == 0) return 2;
    if (strcmp(wcs_code, "G57") == 0) return 3;
    if (strcmp(wcs_code, "G58") == 0) return 4;
    if (strcmp(wcs_code, "G59") == 0) return 5;
    
    return -1;
}

const char* WCSConfig::getWCSCode(int index) {
    static const char* codes[] = {"G54", "G55", "G56", "G57", "G58", "G59"};
    if (index < 0 || index >= 6) return "";
    return codes[index];
}
