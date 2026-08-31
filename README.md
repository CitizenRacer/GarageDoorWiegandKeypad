# Garage Door Keypad

ESPHome firmware and Home Assistant configuration for a classic ESP32-based garage-door Wiegand keypad controller.

The controller is an **ESP32S 30-pin USB-C NodeMCU development board with ESP32-WROOM-32 and CP2102**. The active outdoor reader/keypad is a **Retekess T-AC04** using Wiegand output.

## v20 migration status

Firmware **v20** replaces the project's custom HMAC credential system with **Lock Code Manager (LCM)** external credential validation. The migration is staged on the `lcm-native-credentials` branch until the live Home Assistant LCM entry is populated and the no-motion test is complete. Do not deploy this branch to the production keypad before that Home Assistant work is done.

The v20 PIN path is:

```text
Retekess T-AC04 PIN
   |
   v
ESP32 key collector
   |
   | encrypted ESPHome native API
   v
lock_code_manager.use_credential
   |
   | LCM user / PIN / enabled state / conditions
   v
{ valid, user, reason }
   |
   +--> valid: script.garage_keypad_open_garage(person_name=<LCM user>)
```

There is no PIN HMAC, verifier map, HMAC generator, eFuse-key dependency, PIN sensor, or custom PIN-validation script in v20. The PIN exists transiently in the keypad's key collector and the encrypted Home Assistant action request. It is never intentionally logged or published as an entity state.

Lock Code Manager is the canonical source for keypad users and PINs. Adding, removing, enabling, disabling, or scheduling a keypad user should be done in LCM rather than by editing a YAML credential map.

## Current access-control contract

Credential validation and physical garage operation are deliberately separate.

LCM answers **who is authorized**. `script.garage_keypad_open_garage` decides **whether and how the physical garage may move**.

The common door-action script retains the existing safety behavior:

- If the garage cover state is exactly `open`, a valid PIN closes it immediately. This branch does not alter the alarm.
- A standalone `*` or `#` also requests close only when the imported garage state is exactly `open`. It never validates a credential and can never open the garage.
- Opening is considered only when the cover state is exactly `closed`; unknown, unavailable, opening, closing, and all other states fail closed.
- Opening requires `input_select.garage_keypad_alarm_restore_mode` to be exactly `none`.
- Opening requires `binary_sensor.garage_garage_keypad_debug_mode` to be exactly `off`.
- If the alarm is already disarmed, the garage may open without creating a restore marker.
- If the alarm is in a supported armed state, the script records the exact mode, disarms, positively confirms `disarmed`, records keypad ownership of that disarm, and only then opens.
- Supported armed modes are `armed_home`, `armed_away`, `armed_night`, `armed_vacation`, and `armed_custom_bypass`.
- Unsupported, unknown, unavailable, triggered, or otherwise non-disarmed alarm states block opening.
- The production live script also verifies RATGDO motor activity/retries before treating an opening request as successful.
- Only after a confirmed actual opening does the kitchen Alexa announce `"<friendly user name> opened the garage door"`.

An LCM `lock_code_manager_credential_used` event means a credential was accepted. It is **not** proof that the garage moved.

## Lock Code Manager configuration

The production keypad uses the existing lockless LCM entry **KOZ2 Locks**. Firmware uses its stable config-entry ID by default and reports the Garage Keypad as the credential source and the RATGDO cover as the target.

The firmware calls:

```yaml
lock_code_manager.use_credential
```

with:

```text
config_entry_id = configured KOZ2 Locks entry
code            = PIN entered on keypad
source          = Garage Keypad attribution entity
target          = cover.ratgdov25i_15cde7_door
```

LCM returns `valid`, `user`, and `reason`. Invalid credentials stop in the firmware. Valid credentials call `script.garage_keypad_open_garage` with LCM's friendly user name.

Enable **Allow the device to perform Home Assistant actions** for the Garage Keypad ESPHome integration entry. Use ESPHome and Home Assistant 2025.11.0 or later for reliable action response capture.

## Debug Mode

v20 keeps Debug Mode as an independent safety control:

```yaml
keypad_debug_mode: "false"
```

This setting no longer has anything to do with credential logging. PINs are never intentionally logged in either mode.

The Home Assistant opening path fails closed unless `binary_sensor.garage_garage_keypad_debug_mode` positively reports `off`. For migration testing, override `keypad_debug_mode: "true"`; valid credentials can then be verified through LCM while the guarded opening script refuses physical garage operation.

Debug Mode does not block closing an already-open garage.

## RFID status

RFID authorization is **disabled in v20**.

The firmware continues to decode and log 26/34/37-bit Wiegand RFID frames for commissioning, but it does not submit RFID IDs to LCM and does not operate the garage from an RFID credential. LCM's current managed external-credential path is PIN-oriented; this project will not disguise RFID identifiers as PINs simply to force them through the integration.

See [`docs/RFID_ACCESS_DESIGN.md`](docs/RFID_ACCESS_DESIGN.md).

## Wiegand diagnostics and PIN confidentiality

RFID commissioning diagnostics may log:

```text
RFID tag received: <decoded credential> (authorization disabled)
Wiegand RFID/raw frame: <bits> bits, value=0x<raw>
```

The raw Wiegand logger is intentionally restricted to frames **greater than 8 bits**. It must never raw-log 4-bit or 8-bit frames because those frames are keypad keystrokes and could disclose PIN digits.

PIN logging is prohibited. Firmware logs only the PIN length and the LCM validation result/reason.

## Standalone `*` / `#` close-only behavior

Wiegand key 10 (`*`) and key 11 (`#`) have two contexts:

- after numeric PIN digits, `*` remains PIN clear and `#` remains PIN submit;
- with no numeric PIN entry in progress, either key may request `cover.close_cover` only if the imported garage state is exactly `open`.

The standalone path never calls LCM, never calls `script.garage_keypad_open_garage`, never calls `cover.open_cover`, and never changes the alarm.

## Alarm transaction and recovery behavior

The persistent ownership marker is:

```text
input_select.garage_keypad_alarm_restore_mode
```

with options:

```text
none
armed_home
armed_away
armed_night
armed_vacation
armed_custom_bypass
```

The marker means the keypad flow itself disarmed the alarm and therefore owns a pending restoration.

When the garage later closes, the companion automation restores the saved mode only when the keypad owns that restore. If somebody manually re-arms first, the automation preserves that state and clears the keypad marker.

The checked-in automation is [`homeassistant/garage-keypad-automation.yaml`](homeassistant/garage-keypad-automation.yaml).

## Hardware and wiring

Installed Wiegand signal path:

```text
T-AC04 Green D0 -> level shifter HV3/LV3 -> ESP32 GPIO22
T-AC04 White D1 -> level shifter HV2/LV2 -> ESP32 GPIO19
```

The firmware defaults to GPIO22 for D0 and GPIO19 for D1. See [`docs/BOM.md`](docs/BOM.md) for the as-built bill of materials.

## ESPHome package and Device Builder

The remote firmware is [`esphome/garage-keypad.yaml`](esphome/garage-keypad.yaml). Firmware versioning is explicit; increment `firmware_version` whenever that file is checked in with a firmware change.

A local Device Builder wrapper supplies secrets and imports the package. See [`esphome/device-builder-wrapper.example.yaml`](esphome/device-builder-wrapper.example.yaml).

Required local substitutions include Wi-Fi credentials, OTA password, fallback AP password, and the ESPHome API Noise key. The LCM config-entry ID and source/target entities are normal non-secret substitutions and can be overridden if the Home Assistant installation changes.

## Home Assistant files

[`homeassistant/garage-keypad-script.yaml`](homeassistant/garage-keypad-script.yaml) contains only the common guarded keypad door-action API. LCM performs PIN validation directly; there is no custom PIN validator or PIN-generation helper.

[`homeassistant/garage-keypad-automation.yaml`](homeassistant/garage-keypad-automation.yaml) contains keypad-owned alarm restoration and manual-rearm ownership-clearing logic.

Required helper:

```text
input_select.garage_keypad_alarm_restore_mode
```

The old `garage_keypad_users.yaml`, PIN HMAC validator, RFID HMAC validator, and HMAC-generation helper are obsolete after the live migration is verified. Keep them only as a temporary rollback mechanism during cutover, then remove them from Home Assistant.

## Security model

- PINs are stored where Lock Code Manager is designed to store/manage them.
- A keypad submission travels to Home Assistant through ESPHome's encrypted native API.
- No entity publishes the PIN, avoiding Recorder history of keypad codes.
- The firmware never intentionally logs plaintext PINs.
- A fully compromised Home Assistant installation can already directly operate the garage and is outside the keypad-validation threat model.
- The previously burned classic-ESP32 eFuse BLK3 bits cannot be erased, but v20 does not read or use them.
- Debug Mode remains an absolute opening lockout, not a closing lockout.

## Migration / rollback

See [`docs/LCM_MIGRATION.md`](docs/LCM_MIGRATION.md).

The safe cutover order is: populate LCM, validate credentials without door motion, deploy v20 with Debug Mode on, test the physical keypad while opening is blocked, then disable Debug Mode only after the full chain is confirmed. The old HMAC Home Assistant path should not be removed until those tests pass.

## Repository structure

```text
GarageDoorWiegandKeypad/
├── README.md
├── cad/
├── docs/
│   ├── BOM.md
│   ├── LCM_MIGRATION.md
│   └── RFID_ACCESS_DESIGN.md
├── esphome/
│   ├── garage-keypad.yaml
│   └── device-builder-wrapper.example.yaml
└── homeassistant/
    ├── garage-keypad-script.yaml
    └── garage-keypad-automation.yaml
```
