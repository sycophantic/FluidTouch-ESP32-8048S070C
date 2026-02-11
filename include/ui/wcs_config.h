#ifndef WCS_CONFIG_H
#define WCS_CONFIG_H

#include <Arduino.h>

class WCSConfig {
public:
    // Load WCS configuration for current machine
    static void loadWCSConfig(int machine_index, char names[6][32], bool locks[6]);
    
    // Save WCS configuration for current machine
    static void saveWCSConfig(int machine_index, const char names[6][32], const bool locks[6]);
    
    // Save individual WCS name
    static void saveWCSName(int machine_index, int wcs_index, const char* name);
    
    // Save individual WCS lock status
    static void saveWCSLock(int machine_index, int wcs_index, bool locked);
    
    // Check if current WCS is locked
    static bool isCurrentWCSLocked();
    
    // Get current WCS name (returns empty string if no custom name)
    static void getCurrentWCSName(char* name_out, size_t max_len);
    
    // Get WCS index from code (G54=0, G55=1, etc.) Returns -1 if invalid
    static int getWCSIndex(const char* wcs_code);
    
    // Get WCS code from index (0=G54, 1=G55, etc.)
    static const char* getWCSCode(int index);
};

#endif // WCS_CONFIG_H
