# Garage Door Keypad

ESPHome firmware and Home Assistant configuration for a classic ESP32-based garage-door Wiegand keypad controller.

The controller is an **ESP32S 30-pin USB-C NodeMCU development board with ESP32-WROOM-32 and CP2102**. The active outdoor reader/keypad is a **Retekess T-AC04** using Wiegand output.

## Release status

The repository firmware on `main` is **v22**. The last confirmed production deployment is **v21**.

v22 changes only the standalone `*` / `#` close shortcut. Firmware no longer trusts a cached Home Assistant garage-door state and no longer calls `cover.close_cover` directly. A standalone `*` or `#` now always delegates to the Home Assistant close-only API `script.garage_keypad_close_garage`, which refreshes RATGDO telemetry when needed and proceeds only when the refreshed state is positively `open`. Ambiguous telemetry fails closed, and this standalone path has no route that can open the garage or alter the alarm.

Valid PIN behavior remains unchanged from v21: Lock Code Manager validates the credential, invalid attempts are logged to Home Assistant Activity with the LCM reason and no PIN value, and accepted credentials call the guarded `script.garage_keypad_open_garage` flow.

The PIN path is:

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
   |
   +--> invalid: Activity entry with LCM reason; no garage action
```

The v20 production cutover established that valid physical PINs resolve to the correct LCM users, invalid PINs are rejected, PIN values do not appear in ESPHome logs, Debug Mode blocks opening during no-motion testing, and the production guarded path opens the garage after Debug Mode is intentionally disabled.

## Required runtime dependency

This project has a direct runtime dependency on **[Lock Code Manager](https://github.com/raman325/lock_code_manager)**, a Home Assistant custom integration. Use **LCM 5.3.0 or later**.

Lock Code Manager is the canonical source for keypad users and PINs. Adding, removing, enabling, disabling, or scheduling a keypad user should be done in LCM rather than by editing a YAML credential map.

The ESPHome package cannot install or enforce the presence of a Home Assistant custom integration. If LCM is missing, unavailable, or its action call fails, credential validation fails closed and firmware refuses garage operation.

For GitHub tooling, `.github/workflows/dependency-submission.yml` submits `raman325/lock_code_manager` as a **direct runtime dependency** to GitHub's Dependency Graph. This makes the relationship machine-readable in **Insights → Dependency graph** even though ESPHome YAML has no native manifest field for Home Assistant integration dependencies.

## Current access-control contract

Credential validation and physical garage operation are deliberately separate.

LCM answers **who is authorized**. `script.garage_keypad_open_garage` decides **whether and how the physical garage may move** for valid PINs. `script.garage_keypad_close_garage` is a separate close-only API for standalone `*` / `#` commands.

The guarded door-action layer uses these rules:

- If the garage cover state is exactly `open`, a valid PIN closes it. This branch does not alter the alarm.
- A standalone `*` or `#` never decides garage state in firmware. It always calls `script.garage_keypad_close_garage` when no PIN entry is in progress.
- The close-only Home Assistant script calls `cover.close_cover` immediately only when RATGDO already positively reports `open`.
- If RATGDO is not positively `open`, the close-only script presses `button.ratgdov25i_15cde7_query_status`, waits up to 3 seconds for a definitive `open` or `closed` state when needed, and requires the result to be exactly `open` before closing.
- If refreshed telemetry is `closed`, transitional, unavailable, unknown, or otherwise not positively `open`, the standalone close request does nothing. Ambiguous telemetry therefore fails closed.
- The standalone close-only script has no path that can open the garage and does not change the alarm.
- For valid PIN handling, opening is considered only when the guarded Home Assistant path positively establishes the required terminal state. Unknown, unavailable, or otherwise unsafe states fail closed.
- Opening requires `input_select.garage_keypad_alarm_restore_mode` to be exactly `none`.
- Opening requires `binary_sensor.garage_garage_keypad_debug_mode` to be exactly `off`.
- If the alarm is already disarmed, the garage may open without creating a restore marker.
- If the alarm is in a supported armed state, the script records the exact mode, disarms, positively confirms `disarmed`, records keypad ownership of that disarm, and only then opens.
- Supported armed modes are `armed_home`, `armed_away`, `armed_night`, `armed_vacation`, and `armed_custom_bypass`.
- Unsupported, unknown, unavailable, triggered, or otherwise non-disarmed alarm states block opening.
- The production live script verifies RATGDO motor activity and retries the opening request when needed before treating the operation as successful.
- When RATGDO reports `opening` or `closing` while the motor is off, the production valid-PIN script refreshes RATGDO status before deciding whether to open or close and fails closed if a definitive state cannot be established.
- Only after a confirmed actual opening does the kitchen Alexa announce `"<friendly user name> opened the garage door"`.

An LCM `lock_code_manager_credential_used` event means a credential was accepted. It is **not** proof that the garage moved; garage motion remains the responsibility of the guarded operation layer.

## Lock Code Manager configuration

The production keypad uses the lockless LCM entry **KOZ2 Locks**. Firmware uses its stable config-entry ID by default and reports the Garage Keypad as the credential source and the RATGDO cover as the target.

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

LCM returns `valid`, `user`, and `reason`.

- `valid: true` -> firmware passes the returned friendly user name to `script.garage_keypad_open_garage`.
- `valid: false` -> firmware does not call the garage script. It logs a Home Assistant Activity entry such as `Credential rejected - Lock Code Manager reason: unknown_code`.
- action/response failure -> firmware fails closed and refuses garage operation.

No Activity entry contains the submitted PIN.

Enable **Allow the device to perform Home Assistant actions** for the Garage Keypad ESPHome integration entry. ESPHome and Home Assistant 2025.11.0 or later are required for reliable action-response capture.

## Debug Mode

v22 retains Debug Mode as an independent physical-operation safety control:

```yaml
keypad_debug_mode: "false"
```

The normal production setting is `false`. Set it to `true` only for an intentional no-motion/maintenance test and redeploy the firmware. The Home Assistant opening path fails closed unless `binary_sensor.garage_garage_keypad_debug_mode` positively reports `off`.

Debug Mode has nothing to do with credential logging. PINs are never intentionally logged in either mode. Debug Mode blocks opening but does not block closing an already-open garage.

## PIN confidentiality

There is no PIN HMAC, verifier map, HMAC generator, eFuse-key dependency, PIN sensor, or custom PIN-validation script in the v20-v22 firmware path.

The plaintext PIN exists only transiently in the ESPHome key collector and in the encrypted native-API request to `lock_code_manager.use_credential`. It is never intentionally published as an entity state, written to ESPHome logs, or written to Home Assistant Activity/Logbook.

Firmware logs only the PIN length and LCM validation result/reason. Rejected-credential Activity entries contain only the LCM reason.

## RFID status

RFID authorization is **disabled in v22**.

The firmware continues to decode and log 26/34/37-bit Wiegand RFID frames for commissioning, but it does not submit RFID IDs to LCM and does not operate the garage from an RFID credential. The LCM external-credential path used by this project is PIN-oriented; RFID identifiers are not represented as PINs simply to force them through the integration.

See [`docs/RFID_ACCESS_DESIGN.md`](docs/RFID_ACCESS_DESIGN.md).

## Wiegand diagnostics

RFID commissioning diagnostics may log:

```text
RFID tag received: <decoded credential> (authorization disabled)
Wiegand RFID/raw frame: <bits> bits, value=0x<raw>
```

The raw Wiegand logger is intentionally restricted to frames **greater than 8 bits**. It must never raw-log 4-bit or 8-bit frames because those frames are keypad keystrokes and could disclose PIN digits.

## Standalone `*` / `#` close-only behavior

Wiegand key 10 (`*`) and key 11 (`#`) have two contexts:

- after numeric PIN digits, `*` remains PIN clear and `#` remains PIN submit exactly as before;
- with no numeric PIN entry in progress, either key calls `script.garage_keypad_close_garage`.

Firmware does **not** import or inspect garage-door state for this shortcut in v22. It does not call `cover.close_cover` directly and does not route the command through `script.garage_keypad_open_garage`.

`script.garage_keypad_close_garage` is intentionally structurally close-only:

1. If RATGDO already positively reports `open`, it calls `cover.close_cover`.
2. Otherwise it presses `button.ratgdov25i_15cde7_query_status`.
3. If necessary, it waits up to 3 seconds for `open` or `closed`.
4. It requires the final state to be exactly `open` before issuing a close.
5. Any other result does nothing.

Because the script contains no open action and no alarm action, a standalone `*` / `#` command cannot open the garage or change alarm state. Stale, transitional, unavailable, unknown, or otherwise ambiguous telemetry fails closed.

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

The repository firmware package is [`esphome/garage-keypad.yaml`](esphome/garage-keypad.yaml), currently firmware **v22**.

Firmware versioning is explicit: increment `firmware_version` whenever `esphome/garage-keypad.yaml` itself is checked in with a firmware change. Documentation/workflow-only changes do **not** require a firmware-version increment.

A local Device Builder wrapper supplies secrets and imports the package from `main`. See [`esphome/device-builder-wrapper.example.yaml`](esphome/device-builder-wrapper.example.yaml).

Required local substitutions include Wi-Fi credentials, OTA password, fallback AP password, and the ESPHome API Noise key. The LCM config-entry ID and source/target entities are normal non-secret substitutions and can be overridden if the Home Assistant installation changes.

The production local wrapper should use:

```yaml
keypad_debug_mode: "false"
```

Old v19 wrapper extensions such as `generated_pin_hmac` or `keypad_debug_logging` are obsolete and must not be carried forward.

## Home Assistant files

[`homeassistant/garage-keypad-script.yaml`](homeassistant/garage-keypad-script.yaml) documents the common guarded valid-PIN door-action API. The production live `script.garage_keypad_open_garage` contains additional RATGDO status-refresh and motor-start verification/retry behavior; do not replace that more capable live script with the simpler checked-in baseline.

v22 also requires the live Home Assistant script `script.garage_keypad_close_garage` for standalone `*` / `#`. That script is close-only: it refreshes RATGDO status when the door is not already positively `open`, requires a final `open` state, and otherwise performs no action. It must never contain an open action or alarm-management path.

[`homeassistant/garage-keypad-automation.yaml`](homeassistant/garage-keypad-automation.yaml) contains keypad-owned alarm restoration and manual-rearm ownership-clearing logic.

Required helper:

```text
input_select.garage_keypad_alarm_restore_mode
```

The old `garage_keypad_users.yaml`, PIN HMAC validator, RFID HMAC validator, and HMAC-generation helper are obsolete for the LCM production architecture. See [`docs/LCM_MIGRATION.md`](docs/LCM_MIGRATION.md) for rollback-cleanup guidance.

## Security model

- PINs are stored and managed by Lock Code Manager.
- A keypad submission travels to Home Assistant through ESPHome's encrypted native API.
- No entity publishes the PIN, avoiding Recorder history of keypad codes.
- The firmware never intentionally logs plaintext PINs.
- Invalid-attempt Activity entries expose the LCM reason, not the submitted PIN.
- Standalone `*` / `#` close requests are delegated to a Home Assistant script that is structurally incapable of opening the garage.
- Firmware does not trust cached garage state for standalone close commands; ambiguous RATGDO telemetry is refreshed and still fails closed unless the result is positively `open`.
- A fully compromised Home Assistant installation can already directly operate the garage and is outside the keypad-validation threat model.
- The previously burned classic-ESP32 eFuse BLK3 bits cannot be erased, but v20-v22 do not read or use them.
- Debug Mode remains an absolute opening lockout, not a closing lockout.

## Migration and rollback

The v19 HMAC-to-v20 LCM production cutover is complete. v22 retains the same LCM credential architecture and v21 rejection logging; it changes only the standalone close shortcut to delegate all state validation to the Home Assistant close-only script.

See [`docs/LCM_MIGRATION.md`](docs/LCM_MIGRATION.md) for the completed validation record and remaining rollback cleanup.

Until the old live HMAC scripts/file are intentionally removed, reinstalling v19 remains a rollback option. Once those live rollback artifacts are deleted, LCM is the sole supported credential authority.

## Repository structure

```text
GarageDoorWiegandKeypad/
├── .github/
│   └── workflows/
│       └── dependency-submission.yml
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
