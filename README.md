# Garage Door Keypad

ESPHome firmware and Home Assistant configuration for a classic ESP32-based garage-door Wiegand keypad/RFID controller.

The controller is an **ESP32S 30-pin USB-C NodeMCU development board with ESP32-WROOM-32 and CP2102**. The active outdoor reader/keypad is a **Retekess T-AC04** using Wiegand output.

**GitHub `main` is the authoritative firmware/configuration source.** ESPHome Device Builder keeps only a small local wrapper containing secret substitutions and loads the firmware from this repository as a remote Git package.

## Current release

The current repository firmware is **v19**.

v19 adds a close-only standalone-key shortcut. When no PIN digits are in progress and Home Assistant reports the garage door exactly `open`, pressing either `*` or `#` requests `cover.close_cover`. The shortcut never opens the garage, never validates or bypasses a credential, and never changes the alarm. Unknown, unavailable, uninitialized, closed, opening, or closing garage states cause no action.

The packaged production default is:

```yaml
keypad_debug_logging: "false"
```

Firmware v19 exposes the resulting state to Home Assistant as the **Debug Mode** diagnostic binary sensor. The opening path fails closed unless `binary_sensor.garage_garage_keypad_debug_mode` is exactly `off`.

## Current access-control contract

Both valid PIN and valid RFID credentials ultimately call the common Home Assistant door-action script:

```text
script.garage_keypad_open_garage
```

The script name is historical; it is the common keypad **door-action API**.

Its behavior is deliberately state-specific:

- If the garage cover state is exactly `open`, a valid credential closes it immediately. This branch does not alter the alarm.
- Firmware v19 also permits a standalone `*` or standalone `#` to close the garage only when the imported cover state is exactly `open`. These keys never open the garage.
- Opening is considered only when the cover state is exactly `closed`. `unknown`, `unavailable`, `opening`, `closing`, and every other non-`closed` state fail closed.
- Opening requires `input_select.garage_keypad_alarm_restore_mode` to be exactly `none`. A new opening transaction never starts while a prior keypad-owned alarm restore is pending.
- Opening requires `binary_sensor.garage_garage_keypad_debug_mode` to be exactly `off`. `on`, `unknown`, `unavailable`, or a missing entity block opening. Closing an already-open garage is still allowed.
- If the alarm is already `disarmed`, the garage may open without creating a restore marker.
- If the alarm is in a supported armed state, the script captures the exact armed mode, disarms the alarm, positively confirms `disarmed`, stores the original mode in `input_select.garage_keypad_alarm_restore_mode`, and only then opens.
- Supported armed modes are `armed_home`, `armed_away`, `armed_night`, `armed_vacation`, and `armed_custom_bypass`.
- Any unsupported, unknown, unavailable, triggered, or otherwise non-`disarmed` alarm state blocks opening.
- After a successful opening, the kitchen Alexa announces: `"<friendly user name> opened the garage door"`.

There is no additional opening-enable toggle in the current design; the positive state checks above are the complete opening gate.

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

Use `none` as its initial/default option.

The marker means **the keypad flow itself disarmed the alarm and therefore owns a pending restoration**.

Opening transaction:

1. Require garage cover exactly `closed`.
2. Require restore marker exactly `none`.
3. Require Debug Mode exactly `off`.
4. Read the current alarm state.
5. If already `disarmed`, continue without changing the marker.
6. If in a supported armed state, remember that exact state, request disarm, wait for positive confirmation of `disarmed`, then store the remembered state in the marker.
7. Require the alarm to be exactly `disarmed`.
8. Open the garage.
9. Announce the friendly user name on the kitchen Alexa.

Restoration transaction:

- When the garage later transitions to `closed`, if the marker is set and the alarm is still `disarmed`, restore the exact saved mode.
- If somebody manually re-arms the alarm to any supported armed state before the garage closes, preserve that chosen armed state and **immediately clear the pending marker**.
- If the garage closes while the marker is set but the alarm is already in a supported armed state, preserve that state and clear the stale marker.
- If the alarm was already disarmed before keypad access, the marker stays `none` and garage closure does not arm the system.

The checked-in automation is [`homeassistant/garage-keypad-automation.yaml`](homeassistant/garage-keypad-automation.yaml).

## Authorization architecture

### PIN path

```text
Retekess T-AC04 PIN
   |
   v
ESP32 key collector
   |
   | HMAC-SHA256(BLK3 device key, exact PIN string)
   v
64-character lowercase verifier
   |
   | encrypted ESPHome native API
   v
script.garage_keypad_validate_hmac
   |
   | top-level lookup in /config/garage_keypad_users.yaml
   v
friendly user / invalid credential
   |
   +--> valid: script.garage_keypad_open_garage(person_name=<friendly user>)
```

Plaintext PINs are not intentionally logged, published as ESPHome entities, stored in the Home Assistant authorization map, or sent to Home Assistant during normal keypad use.

### RFID path

```text
Retekess T-AC04 RFID credential
   |
   | Wiegand 26/34/37 decoded credential
   v
ESP32
   |
   | HMAC-SHA256(BLK3 device key, exact decoded credential string)
   v
64-character lowercase verifier
   |
   | encrypted ESPHome native API
   v
script.garage_keypad_validate_rfid_hmac
   |
   | nested rfid: lookup in /config/garage_keypad_users.yaml
   v
friendly user / invalid credential
   |
   +--> valid: script.garage_keypad_open_garage(person_name=<friendly user>)
```

RFID uses the same authorization model and the same device BLK3 HMAC key as PINs. The decoded RFID credential is HMACed locally; only the lowercase 64-character verifier is sent to Home Assistant.

The live authorization database is:

```text
/config/garage_keypad_users.yaml
```

PIN HMAC-to-name mappings are top-level; RFID HMAC-to-name mappings are under `rfid:`. Do not commit the live file. Do not put plaintext PINs, raw RFID IDs, the BLK3 key, or real verifier values in this repository.

See [`docs/HMAC_PIN_DESIGN.md`](docs/HMAC_PIN_DESIGN.md) and [`docs/RFID_ACCESS_DESIGN.md`](docs/RFID_ACCESS_DESIGN.md).

## Wiegand diagnostics and PIN confidentiality

RFID commissioning diagnostics may log:

```text
RFID tag received: <decoded credential>
Wiegand RFID/raw frame: <bits> bits, value=0x<raw>
```

The raw Wiegand logger is intentionally restricted to frames **greater than 8 bits**. It must never raw-log 4-bit or 8-bit frames because those frames are keypad keystrokes and could disclose PIN digits.

`keypad_debug_logging: "true"` may log completed PIN HMAC verifiers for troubleshooting, but never intentionally logs plaintext PINs. HMAC verifiers are authorization material; keep debug logging off in production.

## Standalone `*` / `#` close-only behavior

Wiegand key 10 (`*`) and key 11 (`#`) have two contexts:

- after numeric PIN digits, `*` remains PIN clear and `#` remains PIN submit;
- with no numeric PIN entry in progress, either key may request `cover.close_cover` only if the imported garage state is exactly `open`.

The standalone path:

- never calls the credential validators;
- never calls `script.garage_keypad_open_garage`;
- never calls `cover.open_cover`;
- never disarms or arms the alarm;
- does nothing for any garage state other than exactly `open`.

## Hardware and wiring

The active keypad/reader is the **Retekess T-AC04**.

Installed Wiegand signal path:

```text
T-AC04 Green D0 -> level shifter HV3/LV3 -> ESP32 GPIO22
T-AC04 White D1 -> level shifter HV2/LV2 -> ESP32 GPIO19
```

The firmware substitutions default to GPIO22 for D0 and GPIO19 for D1. They may be overridden only if the physical wiring changes.

See the as-built bill of materials in [`docs/BOM.md`](docs/BOM.md).

## ESPHome package and Device Builder

The remote firmware is [`esphome/garage-keypad.yaml`](esphome/garage-keypad.yaml). The current package is firmware v19. Do not increment `firmware_version` unless that firmware file itself changes.

A local Device Builder wrapper supplies secrets and imports the package. See [`esphome/device-builder-wrapper.example.yaml`](esphome/device-builder-wrapper.example.yaml).

Required local substitutions include Wi-Fi credentials, OTA password, fallback AP password, and the ESPHome API Noise key. The production wrapper should leave:

```yaml
keypad_debug_logging: "false"
```

Enable **Allow the device to perform Home Assistant actions** for the Garage Keypad ESPHome integration entry. Without that permission, the device cannot invoke validation scripts or send the standalone close-only action.

## Home Assistant files

[`homeassistant/garage-keypad-script.yaml`](homeassistant/garage-keypad-script.yaml) contains:

- `script.garage_keypad_validate_hmac` — PIN HMAC lookup, notification/activity logging, then common door action on success;
- `script.garage_keypad_validate_rfid_hmac` — RFID HMAC lookup, notification/logging/activity, then common door action on success;
- `script.garage_keypad_open_garage` — common guarded keypad door-action API;
- `script.garage_keypad_generate_pin_hmac` — administrative PIN-to-HMAC helper.

[`homeassistant/garage-keypad-automation.yaml`](homeassistant/garage-keypad-automation.yaml) contains the keypad-owned alarm restoration and manual-rearm ownership-clearing logic.

Required helpers:

```text
input_select.garage_keypad_alarm_restore_mode
input_text.garage_keypad_activity
```

Verifier-bearing scripts use `trace.stored_traces: 0` so submitted authorization material is not retained in stored script traces.

## Security model

This design is configuration-disclosure hardening, not a claim that a fully compromised ESP32 or Home Assistant host remains safe.

- The 256-bit HMAC key is device-specific, stored in classic ESP32 eFuse BLK3, permanently write-protected, and intentionally readable by firmware because this controller performs software HMAC.
- A Home Assistant authorization-file leak reveals verifier-to-name mappings but not plaintext PINs, raw RFID credentials, or the BLK3 key.
- A fully compromised ESP32 can potentially observe keypad input and read the BLK3 key.
- A fully compromised Home Assistant installation is already capable of directly operating the garage and is outside the keypad-validation threat model.
- Static RFID credentials remain clonable/replayable if an attacker learns the underlying credential; HMAC protects storage/API representation, not the RF credential itself.
- Debug Mode is an absolute **opening** lockout, not a closing lockout.

## Device replacement / recovery

The BLK3 HMAC key is device-specific and there is no supported key-export workflow. Replacing the ESP32 creates a new HMAC key, so all authorized PIN and RFID credentials must be re-derived on the replacement device and `/config/garage_keypad_users.yaml` rebuilt with the new verifier mappings.

ESPHome Safe Mode is also enabled for firmware boot recovery. After repeated failed boots, networking, logging, and OTA remain available; USB ROM-bootloader recovery remains the final fallback.

## Repository structure

```text
GarageDoorWiegandKeypad/
├── README.md
├── cad/
├── docs/
│   ├── BOM.md
│   ├── HMAC_PIN_DESIGN.md
│   └── RFID_ACCESS_DESIGN.md
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
