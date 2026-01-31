# Touch Troubleshooting Guide

## Issue Fixed: Inconsistent Touch Performance on Basic Hardware

### Problem
Touch was working perfectly on some Basic hardware units but not working (or working poorly) on others with identical hardware.

### Root Causes Identified

1. **GT911 Reset Pin Not Being Used**
   - The hardware has a reset pin (GPIO 38) but firmware was ignoring it (`pin_rst = -1`)
   - Without proper reset, GT911 initialization is unreliable across different hardware units
   - Some units might work by chance, others fail consistently

2. **I2C Clock Speed Too Fast**
   - Was using 400kHz (fast mode)
   - Some GT911 units are sensitive to I2C timing and work better at standard 100kHz
   - Signal integrity issues more common at higher speeds

3. **No Diagnostic Output**
   - No way to verify if GT911 was initializing properly
   - Users couldn't tell if problem was hardware or configuration

### Changes Made (v1.0.3+)

#### 1. Enable GT911 Reset Pin (Basic Hardware)
```cpp
cfg.pin_rst = TOUCH_RST;  // GPIO 38 - Now properly used
```

#### 2. Reduce I2C Clock Speed
```cpp
cfg.freq = 100000;  // 100kHz (was 400kHz)
```
Applied to both Basic and Advance hardware for consistency.

#### 3. Add GT911 Verification
After display initialization, firmware now scans I2C bus and reports:
```
Verifying GT911 touch controller...
  GT911 found at 0x5D (Primary address)
  GT911 verification: SUCCESS
```

If GT911 is not found, you'll see:
```
  WARNING: GT911 not responding on I2C bus!
  Touch may not work. Check connections and reset pin.
```

### Expected Behavior After Fix

**Working Touch:**
```
Backlight ON (PWM)
Verifying GT911 touch controller...
  GT911 found at 0x5D (Primary address)
  GT911 verification: SUCCESS
Initializing touch controller...
Touch I2C pins: SDA=19, SCL=20 (managed by LovyanGFX)
Touch Controller: GT911 initialized by LovyanGFX
Touch driver registered with LVGL
Touch driver initialized successfully
```

**Problematic Hardware:**
```
Backlight ON (PWM)
Verifying GT911 touch controller...
  WARNING: GT911 not responding on I2C bus!
  Touch may not work. Check connections and reset pin.
```

### Troubleshooting Steps

#### If Touch Still Not Working:

1. **Check Serial Monitor at 115200 baud**
   - Look for the verification messages above
   - If GT911 not found, likely hardware issue

2. **Verify Hardware Connections**
   - I2C SDA: GPIO 19
   - I2C SCL: GPIO 20
   - Reset: GPIO 38
   - Check for cold solder joints on these pins

3. **Try Lower I2C Speed**
   If still having issues, you can further reduce I2C speed in `display_driver.cpp`:
   ```cpp
   cfg.freq = 50000;  // 50kHz - very conservative
   ```

4. **Check for I2C Conflicts**
   - Make sure no other devices are using same I2C pins
   - Check for shorts or damaged traces

5. **Hardware Defect**
   - If GT911 never responds even with proper initialization, may be defective GT911 chip
   - Contact Elecrow support with serial log showing failed verification

### Technical Details

**GT911 I2C Addresses:**
- Primary: 0x5D (most common)
- Alternate: 0x14 (some units)

**Reset Timing:**
LovyanGFX handles the proper reset sequence:
1. Drive reset pin LOW
2. Wait 10ms
3. Drive reset pin HIGH
4. Wait 50ms for GT911 to initialize

Without reset pin configured, this sequence never happens, causing random initialization success/failure.

### Reporting Issues

If touch still doesn't work after this fix, please provide:
1. Full serial monitor log from boot (115200 baud)
2. Hardware version (check PCB marking)
3. Description of touch behavior (not working at all vs. intermittent vs. inaccurate)

Post in GitHub Issues: https://github.com/jeyeager65/FluidTouch/issues
