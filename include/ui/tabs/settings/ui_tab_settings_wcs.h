#ifndef UI_TAB_SETTINGS_WCS_H
#define UI_TAB_SETTINGS_WCS_H

#include <lvgl.h>

class UITabSettingsWCS {
public:
    static void create(lv_obj_t *parent);
    
    // Keyboard support
    static lv_obj_t* keyboard;
    static lv_obj_t* parent_tab;
    static void showKeyboard(lv_obj_t *ta);
    static void hideKeyboard();
    
private:
    static void btn_save_event_handler(lv_event_t *e);
    static void btn_reset_event_handler(lv_event_t *e);
    
    static lv_obj_t *name_inputs[6];
    static lv_obj_t *lock_buttons[6];
    static lv_obj_t *status_label;
};

#endif // UI_TAB_SETTINGS_WCS_H
