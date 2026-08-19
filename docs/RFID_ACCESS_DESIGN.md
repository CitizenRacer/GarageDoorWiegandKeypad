# RFID Access Design

## Purpose

Firmware v17 extended the Garage Door Keypad from PIN-only authorization to Wiegand RFID authorization without sending raw RFID credentials to Home Assistant during normal validation. Firmware v18 adds the Home Assistant-visible Debug Mode safety state used by the separate garage-opening API.

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
   +--> authorized: notify/log only
   |
   +--> unauthorized: notify/log only
```

The ESP32 does not contain the RFID authorization database and does not decide which tag is authorized. It only transforms the decoded Wiegand credential into a verifier and asks Home Assistant to validate it.

Garage-door control is intentionally disconnected from the RFID validator until explicitly enabled.

## Authorization-file format

PIN and RFID authorization use the same local file:

```text
/config/garage_keypad_users.yaml
```

Existing PIN HMAC entries remain top-level. RFID entries are nested:

```yaml
"<64-character PIN HMAC>": "PIN User"

rfid:
  "<64-character RFID HMAC>": "RFID User"
```

This preserves the existing PIN lookup contract while giving RFID a distinct namespace.

Raw RFID identifiers do not belong in the authorization file.

## HMAC input

The RFID HMAC input is the exact decoded credential string supplied by ESPHome's Wiegand `on_tag` trigger.

For the tested red tag:

```text
Decoded RFID credential: 5400449
```

The firmware therefore computes:

```text
HMAC-SHA256(BLK3 key, "5400449")
```

The resulting verifier belongs in the nested `rfid:` map with friendly user name:

```text
Red Tag
```

Because this tested credential is a seven-digit numeric string, the existing administrative `generate_pin_hmac` ESPHome action can also compute the same verifier for registration. That is an administrative convenience only; RFID runtime processing does not enter the key collector or PIN validation script.

## Logging during commissioning

RFID diagnostic logging remains enabled for now.

Decoded tags log as:

```text
RFID tag received: <decoded credential>
```

Raw frames greater than eight bits log as:

```text
Wiegand RFID/raw frame: <bits> bits, value=0x<raw>
```

4-bit and 8-bit raw frames are never logged because those are keypad keystrokes and could expose PIN digits.

The current logs therefore still disclose RFID identifiers to anyone who can read ESPHome logs. HMACing the Home Assistant lookup protects the stored authorization database and API validation path; it does not make those commissioning logs confidential.

## Garage-opening behavior

A valid RFID verifier is handled by:

```text
script.garage_keypad_validate_rfid_hmac
```

The validator loads `/config/garage_keypad_users.yaml`, reads only the nested `rfid:` mapping, resolves the submitted HMAC to a friendly user, and logs/notifies the result. It does **not** currently operate the garage door.

The separate opening API is:

```text
script.garage_keypad_open_garage
```

It is intentionally disabled by default and requires all of these native Home Assistant state conditions before `cover.open_cover` can run:

```text
input_boolean.garage_keypad_opening_enabled == on
binary_sensor.garage_garage_keypad_debug_mode == off
alarm_control_panel.5744_surety_5744 == disarmed
```

The checks are fail-closed. A missing, `unknown`, or `unavailable` state fails the condition. Debug mode is an absolute lockout: the garage-opening API must never open the door while Debug Mode is on.

The RFID validator is intentionally not wired to call the opening API until garage opening is explicitly enabled.

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

The garage-opening API independently fails closed if:

- opening has not been explicitly enabled;
- the Debug Mode entity is missing, unknown, unavailable, or on;
- the house alarm is missing, unknown, unavailable, armed, triggered, or otherwise not exactly `disarmed`.

An unrecognized or failed RFID credential never reaches garage-door control.
