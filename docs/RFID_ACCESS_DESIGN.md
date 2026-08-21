# RFID Access Design

## Purpose

Firmware v17 extended the Garage Door Keypad from PIN-only authorization to Wiegand RFID authorization without sending raw RFID credentials to Home Assistant during normal validation. Firmware v18 added the Home Assistant-visible Debug Mode safety state used by the guarded keypad opening path.

The RFID path reuses the same device-specific 256-bit HMAC key already provisioned in ESP32 eFuse BLK3 for PIN validation.

## Runtime flow

```text
RFID tag
   |
   | Wiegand 26/34/37
   v
ESPHome Wiegand decoder
   |
   | decoded credential string
   v
HMAC-SHA256(BLK3 key, decoded credential)
   |
   | 64 lowercase hex characters
   v
encrypted ESPHome native API
   |
   v
script.garage_keypad_validate_rfid_hmac
   |
   | nested rfid: lookup
   v
/config/garage_keypad_users.yaml
   |
   +--> authorized: notify/log/activity -> guarded keypad door action
   |
   +--> unauthorized: notify/log/activity only
```

The ESP32 does not contain the RFID authorization database and does not decide which tag is authorized. It transforms the decoded Wiegand credential into a verifier and asks Home Assistant to validate it.

## Authorization-file format

PIN and RFID authorization use the same local file:

```text
/config/garage_keypad_users.yaml
```

PIN HMAC entries remain top-level. RFID entries are nested:

```yaml
"<64-character PIN HMAC>": "PIN User"

rfid:
  "<64-character RFID HMAC>": "RFID User"
```

This preserves the PIN lookup contract while giving RFID a distinct namespace. Raw RFID identifiers do not belong in the authorization file, and the live authorization file must not be committed to the public repository.

## HMAC input

The RFID HMAC input is the exact decoded credential string supplied by ESPHome's Wiegand `on_tag` trigger:

```text
HMAC-SHA256(BLK3 key, exact decoded credential string)
```

Because the administrative `generate_pin_hmac` action accepts a 4-8 digit numeric string and uses the same BLK3 key/HMAC operation, it can also be used to register a numeric RFID credential when the decoded value happens to fit that input contract. That is an administrative convenience only; RFID runtime processing does not enter the key collector or PIN validation script.

## Logging during commissioning

RFID diagnostic logging remains enabled while commissioning.

Decoded tags log as:

```text
RFID tag received: <decoded credential>
```

Raw frames greater than eight bits log as:

```text
Wiegand RFID/raw frame: <bits> bits, value=0x<raw>
```

4-bit and 8-bit raw frames are never raw-logged because those are keypad keystrokes and could expose PIN digits.

The commissioning logs therefore still disclose RFID identifiers to anyone who can read ESPHome logs. HMACing the Home Assistant lookup protects the stored authorization database and normal API validation path; it does not make those commissioning logs confidential.

## Authorized RFID door behavior

A recognized RFID verifier now calls:

```text
script.garage_keypad_open_garage
```

The script name is historical; it is now the keypad door-action API.

If the garage is already open, a valid RFID credential closes it immediately. That close branch does not alter the house alarm.

If the garage is not already open, opening requires:

```text
input_boolean.garage_keypad_opening_enabled == on
binary_sensor.garage_garage_keypad_debug_mode == off
```

The alarm path then behaves as follows:

- if already `disarmed`, opening may proceed;
- if in `armed_home`, `armed_away`, `armed_night`, `armed_vacation`, or `armed_custom_bypass`, the script records the exact mode, disarms the alarm, waits for confirmed `disarmed`, stores the restore marker, and only then opens the garage;
- `unknown`, `unavailable`, `triggered`, or any unsupported state fails the final confirmed-disarmed condition and blocks opening.

Debug Mode is an absolute lockout against **opening** through the keypad API. Closing an already-open garage with a valid credential remains allowed.

## Alarm restoration

The companion Home Assistant automation is:

```text
automation.garage_keypad_restore_alarm_after_garage_closes
```

The marker helper is:

```text
input_select.garage_keypad_alarm_restore_mode
```

The opening script sets the marker only when the keypad flow itself disarmed an armed alarm. When the garage closes, the automation restores that exact prior armed mode. If the alarm was already disarmed before keypad access, the marker remains `none` and no re-arm occurs.

If someone manually re-arms before garage closure, the automation preserves that current armed state and clears the stale restore marker rather than overriding the manual choice.

## Threat model

HMACing RFID credentials provides configuration-disclosure hardening and keeps raw tag identifiers out of the Home Assistant authorization database and normal ESPHome-to-Home-Assistant validation call.

It does **not** prevent cloning or replay of a static RFID credential. A party that can read or reproduce the Wiegand credential presented by a valid tag can still impersonate that tag at the reader.

It also does not attempt to defend the garage door against an attacker who already controls Home Assistant. Such an attacker can already invoke Home Assistant's garage-door controls directly.

## Failure behavior

RFID authorization fails closed if:

- BLK3 is not in the expected uncoded 256-bit mode;
- BLK3 is read-protected;
- the HMAC key is not write-protected;
- the BLK3 key cannot be read;
- the key is empty;
- SHA-256 is unavailable;
- HMAC computation fails;
- Home Assistant receives an empty/invalid verifier;
- the verifier is not present in the nested `rfid:` map.

For the opening branch, garage control additionally fails closed if:

- opening has not been explicitly enabled;
- the Debug Mode entity is missing, unknown, unavailable, or on;
- the alarm cannot be positively brought to `disarmed`.

An unrecognized or failed RFID credential never reaches garage-door control.
