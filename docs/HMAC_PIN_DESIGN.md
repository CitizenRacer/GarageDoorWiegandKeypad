# HMAC PIN Verifier Design

## Purpose

Garage keypad PINs are short secrets. The project does not store plaintext PINs in Home Assistant. Firmware computes:

```text
HMAC-SHA256(device_secret, exact PIN string)
```

and Home Assistant stores only HMAC-to-friendly-name authorization mappings.

The HMAC key is a random 256-bit device secret held in the classic ESP32's eFuse BLK3. It is not stored in Home Assistant, GitHub, ESPHome YAML, or ordinary configuration backups.

This is **configuration-disclosure hardening**. It is not intended to make a fully compromised ESP32 or fully compromised Home Assistant host safe.

## Current system

Current firmware: **v19**

Current reader/keypad: **Retekess T-AC04**

PIN runtime flow:

```text
T-AC04 keypad
      |
      | Wiegand digits
      v
ESP32 key collector
      |
      | plaintext PIN exists transiently in RAM
      v
HMAC-SHA256(BLK3 key, exact PIN string)
      |
      | 64 lowercase hexadecimal characters
      v
encrypted ESPHome native API
      |
      v
script.garage_keypad_validate_hmac
      |
      | top-level verifier lookup
      v
/config/garage_keypad_users.yaml
      |
      +--> valid: friendly name -> script.garage_keypad_open_garage
      |
      +--> invalid: notify/activity only
```

The valid-credential path passes the friendly user name to the common door-action script so a successful opening can be announced in the kitchen.

## Firmware/Home Assistant contract

PIN validation:

```text
script ID: script.garage_keypad_validate_hmac
field:     hmac
value:     64-character lowercase HMAC-SHA256 verifier
```

Both valid PIN and RFID credentials ultimately use:

```text
script.garage_keypad_open_garage
```

as the common guarded keypad door-action API.

## HMAC key provisioning

Provisioning is one-time and defensive:

1. Firmware waits until Wi-Fi is connected so the hardware RNG has its RF entropy source active.
2. BLK3 must use the normal 256-bit uncoded eFuse scheme.
3. Provisioning refuses to modify a non-empty block.
4. Provisioning refuses an empty block that is already write-protected.
5. Provisioning refuses a read-protected block because this classic ESP32 must read the key in software.
6. `esp_fill_random()` generates 32 random bytes.
7. The value is burned into BLK3.
8. Firmware reads BLK3 back and verifies the burn byte-for-byte.
9. Temporary RAM copies are wiped.
10. BLK3 is permanently write-protected.

The normal provisioned state is logged as:

```text
HMAC key already provisioned; BLK3 is write-protected and readable
```

Write protection is permanent. The firmware intentionally does **not** enable read protection.

## Why BLK3 remains readable

This controller is a classic ESP32 rather than a newer part with a dedicated hardware HMAC peripheral that can consume an unreadable eFuse key directly.

Software HMAC therefore requires application firmware to read BLK3 and pass the key to Mbed TLS. Read-protecting BLK3 would prevent this firmware from computing PIN and RFID HMACs.

The intended security property is:

> The HMAC key is absent from normal configuration files, source control, Home Assistant storage, and backups.

It is not:

> The HMAC key is impossible to extract from a fully compromised ESP32.

## Live PIN processing

For each completed PIN, firmware:

1. reads the already-provisioned BLK3 key into a temporary RAM buffer;
2. computes HMAC-SHA256 over the exact PIN string;
3. wipes the temporary key buffer;
4. converts the 32-byte digest to 64 lowercase hexadecimal characters;
5. wipes the binary digest buffer;
6. sends only the hexadecimal verifier to Home Assistant.

If the eFuse state is invalid, the key cannot be read, SHA-256 is unavailable, or HMAC calculation fails, firmware fails closed. The plaintext PIN is not intentionally logged, published as an ESPHome entity, or sent to Home Assistant during normal keypad use.

The packaged production default is:

```yaml
keypad_debug_logging: "false"
```

When temporarily enabled, debug logging may log only the resulting PIN HMAC verifier. The verifier is authorization material and debug logging should be disabled in production.

Firmware v19 exposes the resulting compile-time state as the Home Assistant **Debug Mode** diagnostic binary sensor.

## Home Assistant authorization database

The live verifier-to-user database is:

```text
/config/garage_keypad_users.yaml
```

PIN entries are top-level HMAC-to-friendly-name mappings. RFID entries are under the separate `rfid:` mapping.

The repository contains only a non-secret example:

```text
homeassistant/garage-keypad-users.example.yaml
```

Plaintext PINs, raw RFID IDs, real credential verifiers, and the BLK3 key must not be committed.

Verifier-bearing validation scripts use:

```yaml
trace:
  stored_traces: 0
```

so submitted authorization material is not retained in stored Home Assistant script traces.

## Common guarded door-action behavior

A recognized PIN verifier calls:

```text
script.garage_keypad_open_garage
```

with the resolved friendly user name.

### Close branch

If the garage cover state is exactly `open`, a valid credential closes it immediately.

This close branch:

- does not disarm the alarm;
- does not arm the alarm;
- does not consult Debug Mode;
- does not start a new alarm-restore transaction.

Closing is intentionally allowed even when Debug Mode is on or unavailable because Debug Mode is an absolute lockout against **opening**, not closing.

### Opening gates

The opening branch begins only when all three conditions are positively true:

```text
cover state == closed
input_select.garage_keypad_alarm_restore_mode == none
binary_sensor.garage_garage_keypad_debug_mode == off
```

Therefore:

- `unknown`, `unavailable`, `opening`, `closing`, and any other non-`closed` cover state block opening;
- any pending restore marker blocks a new opening transaction;
- Debug Mode `on`, `unknown`, `unavailable`, or missing blocks opening.

There is no additional opening-enable toggle.

## Alarm transaction

Supported armed modes are:

```text
armed_home
armed_away
armed_night
armed_vacation
armed_custom_bypass
```

The opening transaction behaves as follows:

- If the alarm is already `disarmed`, opening proceeds without creating a restore marker.
- If the alarm is in a supported armed mode, the script captures the exact mode, requests disarm, waits up to 15 seconds for a positive `disarmed` transition if needed, requires the final alarm state to be exactly `disarmed`, stores the captured mode in `input_select.garage_keypad_alarm_restore_mode`, and then opens.
- If the alarm is `unknown`, `unavailable`, `triggered`, or any unsupported state, the final confirmed-disarmed condition blocks opening.

After a successful opening, the kitchen Alexa announces:

```text
<friendly user name> opened the garage door
```

## Conditional alarm restoration

The companion automation is:

```text
automation.garage_keypad_restore_alarm_after_garage_closes
```

The marker is:

```text
input_select.garage_keypad_alarm_restore_mode
```

The marker is set only when the keypad flow itself disarmed an armed alarm.

When the garage later transitions to `closed`:

- marker set + alarm still `disarmed` -> restore the exact saved armed mode;
- marker set + alarm already in a supported armed state -> preserve that armed state and clear the stale marker;
- marker `none` -> do nothing.

If somebody manually re-arms to a supported armed state before the garage closes, the automation treats that transition as intentional, preserves the selected armed state, and **immediately clears the pending marker**. The later garage-close event therefore cannot overwrite the user's manual choice.

If the alarm was already disarmed before keypad access, no marker is created and the garage-closing event does not arm the system.

## Standalone close keys

Firmware v19 also allows a standalone `*` or standalone `#` to request `cover.close_cover` only when Home Assistant reports the garage exactly `open` and no numeric PIN entry is in progress.

This path is not authorization. It is close-only:

- it never validates a credential;
- it never calls the common door-action API;
- it never opens the garage;
- it never changes the alarm.

## Activity logging

Valid and invalid PIN attempts update:

```text
input_text.garage_keypad_activity
```

with the friendly-user result or invalid-attempt result and a timestamp. The verifier itself is not written there.

## Administrative PIN HMAC generator

The device exposes an ESPHome API action for adding or rotating authorized PIN entries without exporting the BLK3 key:

```text
esphome.garage_keypad_generate_pin_hmac
```

It accepts a 4-8 digit numeric string and returns the HMAC for the exact supplied string. Text input preserves leading zeroes.

The repository also includes:

```text
script.garage_keypad_generate_pin_hmac
```

Because this administrative helper receives a plaintext PIN, stored traces are disabled for it as well.

## Threat model

### Protects against

This design reduces exposure from:

- accidentally publishing the Home Assistant authorization map;
- committing the map to source control;
- leaking a configuration backup containing the map;
- sharing configuration snippets that include the map.

A party that obtains only the verifier map does not also receive the device-specific HMAC key needed for ordinary offline PIN enumeration using the normal HMAC construction.

### Does not protect against

**Full ESP32 compromise:** malicious code can potentially read the intentionally readable BLK3 key and observe keypad input.

**Full Home Assistant compromise:** Home Assistant already has direct garage-door control, so a party that fully controls Home Assistant does not need to defeat keypad authorization.

**Physical/keypad observation:** HMAC does not prevent someone from watching PIN entry or intercepting Wiegand digits before the ESP32 hashes them.

**Malicious firmware:** malicious firmware can observe plaintext keypad input and can read BLK3.

## Device replacement and recovery

The BLK3 key is device-specific and there is no supported key-export workflow.

If the ESP32 is replaced, the replacement controller receives a new random BLK3 key. Existing PIN and RFID verifier mappings will no longer match. Re-derive each authorized credential on the replacement controller and rebuild `/config/garage_keypad_users.yaml`.

## Migration history

- **v9:** provisioned and permanently write-protected the 256-bit BLK3 key.
- **v10/v11:** added firmware/HMAC status diagnostics.
- **v12:** added the administrative PIN-to-HMAC generator.
- **v13:** fixed ESPHome generator compatibility.
- **v14:** switched live PIN processing to local HMAC-SHA256 and HMAC-only Home Assistant validation.
- **v16/v17:** added Wiegand RFID handling and HMAC-protected RFID validation.
- **v18:** exposed Debug Mode to Home Assistant.
- **v19:** added standalone `*` / `#` close-only behavior when the garage is exactly open.
- **Current Home Assistant workflow:** exact-closed + marker-none + Debug-Mode-off opening gates, exact-mode alarm transaction/restoration, immediate marker clearing on manual re-arm, and friendly-name Alexa announcement after successful opening.
