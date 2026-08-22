# RFID Access Design

## Purpose

The current Garage Door Keypad firmware is **v19** and the active reader is the **Retekess T-AC04**.

RFID authorization uses the same device-specific 256-bit HMAC key and the same Home Assistant authorization model as PINs. Raw RFID credentials are not stored in the Home Assistant authorization database and are not sent to Home Assistant during normal validation.

## Runtime flow

```text
Retekess T-AC04 RFID tag
   |
   | Wiegand 26/34/37
   v
ESPHome Wiegand decoder
   |
   | exact decoded credential string
   v
HMAC-SHA256(BLK3 key, decoded credential)
   |
   | 64 lowercase hexadecimal characters
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
   +--> authorized: friendly name -> script.garage_keypad_open_garage
   |
   +--> unauthorized: notify/log/activity only
```

The ESP32 does not contain the RFID authorization database and does not decide which tag is authorized. It transforms the decoded Wiegand credential into a verifier and asks Home Assistant to validate that verifier.

## Authorization file

PIN and RFID authorization share:

```text
/config/garage_keypad_users.yaml
```

PIN HMAC mappings remain at the top level. RFID HMAC mappings are nested under:

```yaml
rfid:
```

This keeps the two credential namespaces distinct while using one local authorization file.

Do not put plaintext PINs, raw RFID credential values, real authorization verifiers, or the BLK3 key in GitHub. Do not commit the live authorization file.

## HMAC input

The RFID HMAC input is the exact decoded credential string supplied by ESPHome's Wiegand `on_tag` trigger:

```text
HMAC-SHA256(BLK3 key, exact decoded credential string)
```

Firmware returns only the resulting lowercase 64-character hexadecimal HMAC to Home Assistant.

RFID runtime processing does not enter the PIN key collector and does not send the decoded credential to Home Assistant.

## Wiegand diagnostics

During commissioning, decoded RFID tags may be logged as:

```text
RFID tag received: <decoded credential>
```

Raw Wiegand frames greater than eight bits may also be logged:

```text
Wiegand RFID/raw frame: <bits> bits, value=0x<raw>
```

The raw logger has an important confidentiality rule:

> **4-bit and 8-bit Wiegand frames must never be raw-logged.**

Those frame sizes are keypad keystrokes and raw logging them could expose PIN digits.

The commissioning logs can therefore disclose RFID identifiers to anyone who can read ESPHome logs. HMAC protects the stored authorization database and normal ESPHome-to-Home-Assistant validation call; it does not make commissioning logs confidential.

## Valid RFID behavior

A recognized RFID verifier resolves to a friendly user name and calls:

```text
script.garage_keypad_open_garage
```

with that friendly name.

The script is the common keypad door-action API used by both PIN and RFID authorization.

### Garage exactly open

If the cover state is exactly `open`, a valid RFID credential closes the garage immediately.

The close branch does not alter the house alarm and is permitted regardless of Debug Mode.

### Opening

Opening is considered only if the garage cover state is exactly `closed`.

Before beginning an opening transaction, Home Assistant requires all of:

```text
cover state == closed
input_select.garage_keypad_alarm_restore_mode == none
binary_sensor.garage_garage_keypad_debug_mode == off
```

This is fail-closed behavior:

- `unknown`, `unavailable`, `opening`, `closing`, or any other non-`closed` cover state blocks opening;
- any pending alarm-restore marker blocks a new opening transaction;
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

The common opening flow behaves as follows:

- If the alarm is already `disarmed`, opening may proceed without setting a restore marker.
- If the alarm is in a supported armed mode, capture the exact current mode, request disarm, positively confirm `disarmed`, store the captured mode in `input_select.garage_keypad_alarm_restore_mode`, and only then open.
- If the alarm cannot be positively confirmed `disarmed`, opening is blocked.

After a successful opening, the kitchen Alexa announces:

```text
<friendly user name> opened the garage door
```

## Alarm restoration and manual re-arm

The companion automation is:

```text
automation.garage_keypad_restore_alarm_after_garage_closes
```

The marker is:

```text
input_select.garage_keypad_alarm_restore_mode
```

The marker is set only when the keypad opening flow itself disarmed an armed alarm.

When the garage later transitions to `closed` and the alarm is still `disarmed`, the automation restores the exact saved armed mode.

If someone manually re-arms to any supported armed state before the garage closes, the automation preserves that armed state and **immediately clears the pending marker**. The later garage-close event therefore does not overwrite the manual choice.

If the garage closes while the marker is still set but the alarm is already in a supported armed state, the automation preserves that current state and clears the stale marker.

If the alarm was already disarmed before keypad access, no marker is created and no re-arm is performed after closure.

## Standalone `*` / `#` close-only shortcut

Firmware v19 also supports pressing just `*` or just `#` while no PIN digits are in progress.

These standalone keys request `cover.close_cover` only if the imported Home Assistant cover state is exactly `open`.

They:

- do not validate PIN or RFID authorization;
- do not call the common door-action script;
- never open the garage;
- never disarm or arm the alarm;
- do nothing in any cover state other than exactly `open`.

## Debug Mode

Firmware v19 exposes the compile-time `keypad_debug_logging` setting as the Home Assistant **Debug Mode** diagnostic binary sensor.

The packaged default is:

```yaml
keypad_debug_logging: "false"
```

Opening requires the resulting Home Assistant Debug Mode state to be exactly `off`. Missing, `unknown`, `unavailable`, or `on` all block opening. Closing an already-open garage remains permitted.

## Threat model

HMACing RFID credentials provides configuration-disclosure hardening and keeps raw tag identifiers out of the Home Assistant authorization database and normal validation action.

It does **not** prevent cloning or replay of a static RFID credential. A party that can learn or reproduce the underlying Wiegand credential can still impersonate that tag at the reader.

A fully compromised Home Assistant installation is outside the keypad threat model because Home Assistant already has direct access to garage-door controls.

A fully compromised ESP32 can potentially read the intentionally readable BLK3 key and observe the decoded RFID credential.

## Failure behavior

RFID authorization fails closed if:

- BLK3 is not in the expected uncoded 256-bit mode;
- BLK3 is read-protected;
- the HMAC key is not write-protected;
- BLK3 cannot be read;
- the key is empty;
- SHA-256 is unavailable;
- HMAC computation fails;
- Home Assistant receives an invalid verifier;
- the verifier is not present in the nested `rfid:` map.

The opening branch additionally fails closed unless the cover is exactly `closed`, the restore marker is exactly `none`, Debug Mode is exactly `off`, and the alarm is positively `disarmed` before the open command is issued.

An unrecognized or failed RFID credential never reaches garage-door control.
