# Garage Door Keypad

ESPHome firmware and Home Assistant configuration for a classic ESP32-based garage-door Wiegand keypad/RFID controller.

The controller is an **ESP32S 30-pin USB-C NodeMCU development board with ESP32-WROOM-32 and CP2102**. The detected SoC is an **ESP32-D0WD-V3**. The active outdoor reader/keypad is a **Retekess T-AC04** using Wiegand output.

**GitHub `main` is the authoritative firmware/configuration source.** ESPHome Device Builder keeps only a small local wrapper containing secret substitutions and loads the firmware from this repository as a remote Git package.

## Current release

The current repository firmware is **v19**.

v19 adds a **close-only standalone-key shortcut**: when no PIN digits are in progress and Home Assistant reports the garage door exactly `open`, pressing either `*` or `#` requests `cover.close_cover`. The shortcut never opens the garage, never validates or bypasses a credential, and never disarms the alarm. Unknown, unavailable, or otherwise non-`open` garage states cause no action.

v18 introduced the compile-time keypad debug state as the **Debug Mode** diagnostic binary sensor for Home Assistant. Firmware versioning is owned by `esphome/garage-keypad.yaml`; its `firmware_version` substitution is incremented for every repository check-in that changes that file.

The current access-control behavior is:

- valid PIN and RFID credentials call the guarded keypad door-action API;
- if the garage is already open, a valid credential closes it immediately without changing the alarm;
- if the garage is already open and no PIN is being entered, standalone `*` or `#` also closes it without changing the alarm;
- opening always requires a valid credential, the explicit opening-enable helper to be on, and the ESP32 Debug Mode entity to positively report off;
- if the house alarm is already disarmed, an authorized opening proceeds normally;
- if the alarm is in a supported armed mode, the authorized keypad flow disarms it, remembers the exact prior armed mode, confirms disarm, and then opens the garage;
- after the garage closes, the alarm is restored only if the keypad opening flow was the thing that disarmed it;
- a manual re-arm before garage closure is preserved rather than overwritten;
- unknown, unavailable, triggered, or otherwise unsupported alarm states fail closed for opening.

## Security design

### PIN path

```text
Keypad PIN
   |
   v
ESP32 key_collector
   |
   | HMAC-SHA256(BLK3 device key, exact PIN string)
   v
64-character verifier
   |
   | encrypted ESPHome native API
   v
script.garage_keypad_validate_hmac
   |
   | top-level lookup in /config/garage_keypad_users.yaml
   v
friendly user / invalid credential
```

Plaintext PINs are not intentionally logged, published as ESPHome entities, stored in the Home Assistant authorization map, or sent over the ESPHome API during normal keypad use.

### RFID path

```text
Wiegand RFID tag
   |
   v
ESPHome Wiegand decoder
   |
   | decoded credential (temporarily logged during commissioning)
   v
HMAC-SHA256(BLK3 device key, exact decoded credential string)
   |
   | 64-character verifier over encrypted ESPHome API
   v
script.garage_keypad_validate_rfid_hmac
   |
   | nested rfid: lookup in /config/garage_keypad_users.yaml
   v
friendly user / invalid credential
```

The RFID verifier prevents the Home Assistant authorization file from containing raw RFID identifiers. It does **not** make a clonable static RFID credential cryptographically unclonable; the reader still receives the credential over Wiegand. See [`docs/RFID_ACCESS_DESIGN.md`](docs/RFID_ACCESS_DESIGN.md).

The device-specific 256-bit HMAC key is stored in ESP32 eFuse **BLK3**, permanently write-protected, and intentionally left readable by firmware because this classic ESP32 has no dedicated hardware HMAC peripheral. See [`docs/HMAC_PIN_DESIGN.md`](docs/HMAC_PIN_DESIGN.md).

## Garage keypad door-action logic

Both valid PIN and valid RFID paths call:

```text
script.garage_keypad_open_garage
```

Despite the historical script name, it is now the keypad **door-action API**.

### If the garage is already open

A valid credential calls `cover.close_cover` immediately. This close path does not disarm, arm, or otherwise modify the house alarm.

Firmware v19 additionally imports the garage cover state from Home Assistant. If **no numeric PIN digits are in progress**, Wiegand key 10 (`*`) or key 11 (`#`) may issue a direct `cover.close_cover` action, but only when the imported state is exactly `open`.

This standalone-key path is intentionally narrower than the credential path:

- it can issue only `cover.close_cover`;
- it never calls `script.garage_keypad_open_garage`;
- it never opens the garage;
- it never disarms or otherwise changes the alarm;
- `*` after entered digits remains the normal PIN-clear key;
- `#` after entered digits remains the normal PIN-submit key;
- after a PIN-entry timeout, the next standalone `*` or `#` is again eligible for close-only behavior;
- if the imported garage state is unknown, unavailable, uninitialized, closed, opening, or closing, the shortcut does nothing.

The safety interlocks below are opening interlocks. Debug Mode is an absolute lockout against **opening** through the keypad API; it does not prevent an already-open garage from being closed.

### If the garage is not already open

Opening first requires:

```text
input_boolean.garage_keypad_opening_enabled == on
binary_sensor.garage_garage_keypad_debug_mode == off
```

The alarm is then handled as follows:

- `disarmed`: proceed to opening without setting an alarm-restore marker;
- `armed_home`, `armed_away`, `armed_night`, `armed_vacation`, or `armed_custom_bypass`: remember that exact mode, disarm, wait up to 15 seconds for confirmed `disarmed`, store the restore marker, then open;
- `unknown`, `unavailable`, `triggered`, or any other state: the final confirmed-disarmed condition fails and the garage does not open.

The actual `cover.open_cover` action cannot run until the alarm positively reports `disarmed`.

### Restoring the alarm after garage closure

The companion automation is:

```text
automation.garage_keypad_restore_alarm_after_garage_closes
```

and its checked-in fragment is [`homeassistant/garage-keypad-automation.yaml`](homeassistant/garage-keypad-automation.yaml).

The persistent helper `input_select.garage_keypad_alarm_restore_mode` records whether the keypad opening flow owns a pending alarm restore and which armed mode to restore.

When the garage reaches `closed`:

- marker `none` -> do nothing;
- marker set + alarm still `disarmed` -> restore the recorded armed mode;
- marker set + alarm already manually re-armed -> preserve the current armed state and clear the marker.

This also works when a keypad-owned opening is later closed with standalone `*` or `#`: the close itself does not touch the alarm, and the existing closure automation performs the pending restore.

## Threat-model note

This HMAC design primarily hardens configuration and backup disclosure. If an attacker already controls Home Assistant, protecting the keypad validation path from that same attacker adds little garage-door security because Home Assistant itself already has the ability to operate the garage door.

The standalone `*`/`#` shortcut intentionally requires no credential because it can only close an already-open garage. It adds no path to opening or alarm disarm.

## Current features

- GitHub-backed ESPHome remote-package workflow
- Wi-Fi connectivity
- ESPHome native API with Noise encryption
- Password-protected OTA updates
- Explicit ESPHome Safe Mode recovery
- Fallback Wi-Fi AP with its own password
- GPIO2 blue connection-status LED
- Home Assistant API-client tracking
- Native Wiegand keypad and RFID input
- 4-8 digit PIN collection with `#` submit, `*` clear, and 10-second timeout
- Standalone `*` or `#` close-only shortcut when the garage is already open
- Device-local HMAC-SHA256 PIN transformation
- Device-local HMAC-SHA256 RFID transformation
- 256-bit device key in write-protected ESP32 eFuse BLK3
- One file-backed authorization database for PIN and RFID HMACs
- RFID decoded/raw diagnostics without logging 4-bit or 8-bit keypad frames
- Administrative PIN-to-HMAC generator action and Home Assistant helper script
- Script trace storage disabled where PIN/RFID verifier material is handled
- ESP32 Debug Mode diagnostic exposed to Home Assistant
- Valid PIN/RFID credentials routed to one guarded keypad door-action script
- Valid credential closes an already-open garage without changing the alarm
- Fail-closed opening gate with explicit enable and debug-mode lockout
- Conditional alarm disarm before opening and exact-mode restore after closure
- Latest valid/invalid keypad result recorded in `input_text.garage_keypad_activity`
- Wi-Fi signal, uptime, die temperature, IP, SSID, MAC, and firmware diagnostics

The ESPHome HTTP `web_server` is intentionally disabled. Management and telemetry use the encrypted native API instead of exposing an additional plaintext HTTP interface.

## Repository structure

```text
GarageDoorWiegandKeypad/
├── README.md
├── cad/
├── docs/
│   ├── BOM.md
│   ├── HMAC_PIN_DESIGN.md
│   ├── RFID_ACCESS_DESIGN.md
│   └── images/
├── esphome/
│   ├── garage-keypad.yaml
│   ├── device-builder-wrapper.example.yaml
│   └── secrets.example.yaml
└── homeassistant/
    ├── garage-keypad-script.yaml
    ├── garage-keypad-automation.yaml
    ├── garage-keypad-users.example.yaml
    └── secrets.example.yaml
```

## Hardware and wiring

The Retekess T-AC04 keypad/reader feeds Wiegand D0 and D1 through the HiLetgo BSS138 level shifter before reaching the ESP32.

Current default wiring:

```text
Keypad Green D0 -> level shifter HV3/LV3 -> GPIO22
Keypad White D1 -> level shifter HV2/LV2 -> GPIO19
```

These pins are substitutions and can be overridden from the local Device Builder wrapper if the physical wiring changes.

### Major hardware

| Qty | Part | Purpose |
|---:|---|---|
| 1 | Retekess T-AC04 Wiegand keypad / RFID reader | Outdoor keypad and Wiegand source |
| 1 | ESP32S 30-pin ESP32-WROOM-32 board | Controller |
| 1 | ESP32 DIN-rail carrier with integrated DC-DC buck converter | Screw-terminal carrier, DIN mounting, and regulated ESP32 power from 12 V |
| 1 | MEAN WELL HDR-30-12 | 12 V DIN-rail power supply |
| 1 | HiLetgo 4-channel BSS138 level shifter | Wiegand level shifting |
| As needed | 4-conductor security wire | Keypad-to-controller cable |
| As needed | 18 AWG PVC stranded wire | Internal power wiring |

See the complete as-built purchase list and links in [`docs/BOM.md`](docs/BOM.md).

## ESPHome Device Builder setup

The remote firmware uses substitutions because remote Git packages cannot directly read the local Device Builder `secrets.yaml`.

A local wrapper should provide:

```yaml
substitutions:
  wifi_ssid: !secret wifi_ssid
  wifi_password: !secret wifi_password
  ota_password: !secret ota_password
  fallback_ap_password: !secret fallback_ap_password
  garage_keypad_api_encryption_key: !secret garage_keypad_api_encryption_key

  # Testing only. This logs PIN HMAC verifiers, never plaintext keypad PINs.
  # It also sets the Home Assistant Debug Mode diagnostic to on, which is an
  # absolute lockout for garage OPENING through the keypad API.
  keypad_debug_logging: "false"

packages:
  garage_keypad:
    url: https://github.com/CitizenRacer/GarageDoorWiegandKeypad
    ref: main
    files:
      - esphome/garage-keypad.yaml
    refresh: 60s
```

The firmware defaults `garage_door_entity_id` to the current ratgdo garage cover. It may be overridden in the local wrapper if the Home Assistant entity ID changes. Do not override `firmware_version`; the repository package owns release versioning.

### ESPHome secrets

Keep these values only in the Device Builder's local `secrets.yaml`:

```yaml
wifi_ssid: "YOUR_WIFI_NAME"
wifi_password: "YOUR_WIFI_PASSWORD"
ota_password: "YOUR_OTA_PASSWORD"
fallback_ap_password: "YOUR_FALLBACK_AP_PASSWORD"
garage_keypad_api_encryption_key: "YOUR_32_BYTE_BASE64_NOISE_PSK"
```

Generate the API encryption key with:

```text
openssl rand -base64 32
```

Keep any trailing `=` padding.

## BLK3 HMAC key

The firmware provisions a device-specific 256-bit random key into classic ESP32 eFuse BLK3.

Provisioning:

- waits for Wi-Fi so the RF entropy source is active;
- requires the normal 256-bit uncoded BLK3 scheme;
- refuses to overwrite non-empty BLK3;
- verifies the burn before write protection;
- permanently write-protects BLK3;
- never logs the key.

A correctly provisioned controller reports:

```text
HMAC key already provisioned; BLK3 is write-protected and readable
```

The key is intentionally readable by firmware. See the HMAC design document for the threat-model implications.

## PIN processing

The key collector accepts 4-8 numeric digits. `#` submits, `*` clears, and incomplete entry times out after ten seconds.

Firmware separately tracks whether numeric PIN entry is active. When no digits are in progress, a standalone `*` or `#` is eligible for the v19 close-only shortcut described above. This does not change the collected PIN, HMAC, or credential-validation path.

On submission, firmware computes:

```text
HMAC-SHA256(BLK3 key, exact PIN string)
```

and sends only the 64-character lowercase hexadecimal verifier to:

```text
script.garage_keypad_validate_hmac
field: hmac
```

If HMAC generation fails, the firmware fails closed and supplies an invalid/empty verifier that cannot authorize.

A recognized verifier records the friendly user/activity result and then calls the guarded keypad door-action script.

## RFID processing

ESPHome's Wiegand component decodes parity-valid tag frames and supplies the decoded credential to `on_tag`. The commissioning log is:

```text
RFID tag received: <decoded credential>
```

`on_raw` also retains diagnostics for Wiegand frames larger than eight bits:

```text
Wiegand RFID/raw frame: <bits> bits, value=0x<raw>
```

The raw logger explicitly ignores 4-bit and 8-bit frames so keypad keystrokes are not exposed.

After logging the decoded tag, firmware computes:

```text
HMAC-SHA256(BLK3 key, exact decoded RFID credential string)
```

and sends only the verifier to:

```text
script.garage_keypad_validate_rfid_hmac
field: hmac
```

A recognized RFID verifier records/logs the friendly user result and then calls the same guarded keypad door-action script as a valid PIN.

## Home Assistant authorization database

The live authorization database is one local file:

```text
/config/garage_keypad_users.yaml
```

PIN HMAC entries remain at the top level. RFID HMAC entries live under `rfid:`:

```yaml
"<64-character PIN HMAC>": "Example PIN User"

rfid:
  "<64-character RFID HMAC>": "Example RFID User"
```

Do not store plaintext PINs or raw RFID credentials in this file, and **do not commit the live authorization file**. It is intentionally excluded from local Home Assistant version control as well as from this public repository workflow.

## Home Assistant scripts and automation

[`homeassistant/garage-keypad-script.yaml`](homeassistant/garage-keypad-script.yaml) contains:

- `script.garage_keypad_validate_hmac` — PIN verifier lookup, notification/activity logging, then guarded door action on success;
- `script.garage_keypad_validate_rfid_hmac` — nested RFID verifier lookup, notification/logging/activity, then guarded door action on success;
- `script.garage_keypad_open_garage` — guarded keypad door-action API: close if already open, otherwise use the opening/alarm safety flow;
- `script.garage_keypad_generate_pin_hmac` — administrative PIN HMAC helper.

[`homeassistant/garage-keypad-automation.yaml`](homeassistant/garage-keypad-automation.yaml) contains the alarm-restore automation described above.

The standalone v19 `*`/`#` shortcut is implemented in ESPHome and directly issues `cover.close_cover`; it does not use or alter the Home Assistant authorization scripts.

Required helpers:

```text
input_boolean.garage_keypad_opening_enabled
input_select.garage_keypad_alarm_restore_mode
input_text.garage_keypad_activity
```

The restore-mode helper options are:

```text
none
armed_home
armed_away
armed_night
armed_vacation
armed_custom_bypass
```

Use `none` as its initial/default option.

The notification action name is local configuration:

```yaml
garage_keypad_notify_service: "notify.mobile_app_your_phone"
```

Verifier-bearing scripts set:

```yaml
trace:
  stored_traces: 0
```

## Generating a verifier

The firmware exposes the administrative ESPHome action:

```text
esphome.garage_keypad_generate_pin_hmac
```

It accepts 4-8 numeric characters and returns the HMAC for the exact supplied string. The BLK3 key itself is never returned.

## Home Assistant action permission

Enable **Allow the device to perform Home Assistant actions** for the Garage Keypad ESPHome integration entry. Without this permission, the ESP32 cannot invoke the PIN/RFID validation scripts or issue the standalone v19 garage-close action.

## Debug logging

The local wrapper can temporarily set:

```yaml
keypad_debug_logging: "true"
```

Normal keypad entry still does **not** log plaintext PINs. Debug mode logs only the resulting PIN HMAC verifier.

v18 introduced the **Debug Mode** diagnostic binary sensor, and it remains present in v19. `on` means debug mode is active; `off` means it is not. The keypad opening path requires this entity to positively report `off`, so a missing/unknown/unavailable entity also blocks opening. Debug mode does not block close-only actions.

RFID commissioning currently logs decoded RFID credentials and raw Wiegand frames over eight bits. Remove those RFID diagnostic logs after commissioning if they are no longer useful.

## Safe Mode recovery

ESPHome Safe Mode is configured as:

```yaml
safe_mode:
  num_attempts: 5
  boot_is_good_after: 1min
  reboot_timeout: 10min
```

After repeated boot failures, ESPHome retains networking, logging, and OTA in Safe Mode. USB ROM-bootloader recovery remains available if needed.

## Blue status LED

The onboard GPIO2 LED indicates connectivity:

- **500 ms on / 500 ms off:** Wi-Fi disconnected/searching
- **Double blink + pause:** Wi-Fi connected, Home Assistant not connected
- **Solid blue:** Home Assistant connected to the encrypted API

## Diagnostics

The device exposes Home Assistant connection state, Debug Mode, Wi-Fi signal, uptime, ESP32 die temperature, IP address, SSID, MAC address, firmware version, restart, Safe Mode restart, and the administrative Generated PIN HMAC entity.
