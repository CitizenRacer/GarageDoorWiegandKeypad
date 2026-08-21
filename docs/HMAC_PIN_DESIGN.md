# HMAC PIN Verifier Design

## Purpose

Garage keypad PINs are short numeric secrets. A 4-digit PIN has only 10,000 possible values, and even an 8-digit PIN has only 100,000,000. Storing plaintext PINs in Home Assistant would therefore make an accidental configuration disclosure immediately reveal working credentials.

The project stores and submits this instead:

```text
HMAC-SHA256(device_secret, PIN)
```

The HMAC key is a random 256-bit device secret held in the ESP32's eFuse BLK3. It is not stored in Home Assistant, GitHub, ESPHome YAML, or ordinary configuration backups.

This is deliberately **configuration-disclosure hardening**. It is not intended to make a fully compromised ESP32 or fully compromised Home Assistant host safe.

## Why HMAC instead of SHA-256

A value such as:

```text
SHA256("1234")
```

can be attacked by hashing the entire small PIN space. A public salt changes the values but does not prevent the attacker from testing every guess.

With:

```text
HMAC-SHA256(device_secret, "1234")
```

a party that obtains only the Home Assistant verifier map does not have the separate 256-bit ESP32 key required to test PIN guesses using the normal construction.

## Runtime architecture

Firmware v14 and later use the HMAC verifier for the live keypad path:

```text
Outdoor keypad
      |
      | Wiegand digits
      v
ESP32 key collector
      |
      | plaintext PIN exists transiently in RAM
      v
HMAC-SHA256(BLK3 key, PIN)
      |
      | 64 lowercase hex characters
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
      +--> valid: notify/activity -> guarded keypad door action
      |
      +--> invalid: notify/activity only
```

Home Assistant does not need the plaintext PIN or the HMAC key during normal validation.

## Firmware/Home Assistant interface contract

The firmware-facing script contract is:

```text
script ID: script.garage_keypad_validate_hmac
field:     hmac
value:     64-character lowercase HMAC-SHA256 verifier
```

Firmware invokes it as:

```yaml
action: script.garage_keypad_validate_hmac
data:
  hmac: <64-character verifier>
```

The HMAC is deterministic: the same PIN evaluated by this ESP32 produces the same verifier every time. A different ESP32 with a different BLK3 key produces a different verifier for the same PIN.

## HMAC key provisioning

The classic ESP32 uses eFuse block `BLK3` for the device HMAC key.

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

The controller is a classic ESP32, not a newer part with a dedicated hardware HMAC peripheral that can consume an unreadable eFuse key directly.

Software HMAC therefore requires application firmware to read BLK3 and pass the key to Mbed TLS. If BLK3 were read-protected, this firmware could no longer calculate PIN HMACs.

The security property is:

> The HMAC key is absent from normal configuration files, source control, Home Assistant storage, and backups.

It is not:

> The HMAC key is impossible to extract from a fully compromised ESP32.

## Live PIN processing

For each completed keypad PIN, firmware:

1. reads the already-provisioned BLK3 key into a temporary RAM buffer;
2. computes HMAC-SHA256 over the exact PIN string;
3. wipes the temporary key buffer;
4. converts the 32-byte digest to 64 lowercase hexadecimal characters;
5. wipes the binary digest buffer;
6. sends only the hexadecimal verifier to Home Assistant.

If the eFuse state is invalid, the key cannot be read, SHA-256 is unavailable, or HMAC calculation fails, firmware fails closed. The plaintext PIN is not intentionally logged, published as an ESPHome entity, or sent to Home Assistant during normal keypad use.

When `keypad_debug_logging` is enabled, only the resulting HMAC verifier is logged. The verifier is still authorization material, so debug logging should be disabled when it is not needed.

Firmware v18 exposes that compile-time debug setting as the Home Assistant **Debug Mode** diagnostic binary sensor. Debug Mode being on is an absolute lockout against opening the garage through the keypad door-action API.

## Home Assistant verifier database

The live verifier-to-user database is:

```text
/config/garage_keypad_users.yaml
```

PIN entries are top-level:

```yaml
"<64-character PIN HMAC>": "Friendly User Name"
```

RFID entries are kept under the separate `rfid:` mapping. Plaintext PINs do not belong in the file. Live verifier values also should not be committed to the public repository.

The repository contains only the non-secret template:

```text
homeassistant/garage-keypad-users.example.yaml
```

The checked-in validation script reads the YAML file with `file.read_file` on each validation attempt and performs an exact verifier lookup. Verifier-bearing scripts set `trace.stored_traces: 0` so submitted authorization material is not retained in stored script traces.

## Valid PIN behavior

A recognized PIN verifier now records the friendly-user activity and calls:

```text
script.garage_keypad_open_garage
```

The historical script name is retained for compatibility, but it now acts as the keypad door-action API.

### Garage already open

A valid credential closes the garage immediately and does not change the house alarm.

### Garage not already open

Opening requires:

```text
input_boolean.garage_keypad_opening_enabled == on
binary_sensor.garage_garage_keypad_debug_mode == off
```

If the alarm is already `disarmed`, opening may proceed without creating an alarm restore marker.

If the alarm is in one of the supported armed modes:

```text
armed_home
armed_away
armed_night
armed_vacation
armed_custom_bypass
```

the script captures that exact mode, disarms the alarm, waits up to 15 seconds for confirmed `disarmed`, stores the prior mode in `input_select.garage_keypad_alarm_restore_mode`, and then opens the garage.

Any alarm state that cannot be positively brought to `disarmed` blocks opening.

## Conditional alarm restoration

The companion automation:

```text
automation.garage_keypad_restore_alarm_after_garage_closes
```

restores the exact prior mode after the garage closes **if and only if** the keypad opening flow had disarmed the alarm and therefore left a pending restore marker.

If the alarm was already disarmed before keypad access, the marker remains `none` and the automation does not arm the system.

If somebody manually re-arms before the garage closes, the automation preserves that armed state and clears the pending marker after closure rather than overriding the manual choice.

## Activity logging

Valid and invalid PIN attempts update:

```text
input_text.garage_keypad_activity
```

with the friendly-user result (for a valid credential) or invalid-attempt result and a timestamp. The HMAC verifier itself is not written there.

## Administrative PIN HMAC generator

The device exposes an ESPHome API action for adding or rotating authorized PIN entries without exporting the BLK3 key:

```text
esphome.garage_keypad_generate_pin_hmac
```

It accepts a 4-8 digit numeric string and returns the HMAC for the exact supplied string. The PIN is deliberately supplied as text so leading zeroes are preserved.

The generator requires BLK3 to be 256-bit, readable, non-empty, and write-protected; computes the HMAC; wipes temporary key and digest buffers; and returns the 64-character lowercase verifier. It does not expose the BLK3 key itself.

The repository also contains the Home Assistant wrapper:

```text
script.garage_keypad_generate_pin_hmac
```

Because this helper's input is a plaintext PIN, its stored traces are disabled as well.

## What this protects against

This design materially improves protection against realistic accidental-disclosure scenarios, including:

- accidentally publishing a Home Assistant authorization map;
- committing the verifier map to a public or shared repository;
- leaking a configuration backup containing the map;
- sharing configuration snippets while forgetting the map is included;
- an attacker obtaining only the stored verifier map and trying to recover short PINs offline without the device key.

## What this does not protect against

### Full ESP32 compromise

The classic ESP32 firmware must read BLK3 to calculate HMACs. Malicious code executing with sufficient privilege on the ESP32 can therefore potentially read the HMAC key and capture keypad input. Write protection prevents changing the key; it does not make it unreadable.

### Full Home Assistant compromise

A fully compromised Home Assistant installation is outside this threat model. Home Assistant already has direct access to the garage-door control surface, so compromising the keypad validation path is not required to operate the garage.

An attacker with sufficient Home Assistant access may also be able to invoke the administrative HMAC generator repeatedly and use the ESP32 as an online PIN-guessing oracle.

### Physical/keypad observation

HMAC cannot stop someone from learning a PIN by watching a user enter it, compromising the keypad itself, or intercepting the Wiegand digit stream before the ESP32 performs the HMAC.

### Malicious firmware

A malicious firmware image can observe plaintext keypad input and, because BLK3 is intentionally readable, can also obtain the HMAC key. This design does not claim secure-boot/HSM resistance to malicious firmware.

## Device replacement and recovery

The BLK3 key is device-specific and there is no supported key-export workflow.

If the ESP32 is replaced, the replacement controller will generate a new random BLK3 key. Existing verifiers will no longer match. Each authorized PIN must be entered into the new controller's administrative HMAC generator and the Home Assistant verifier map rebuilt.

## Migration history

- **v9:** provisioned and permanently write-protected the 256-bit BLK3 key.
- **v10/v11:** added reliable firmware/HMAC status diagnostics.
- **v12:** added the administrative PIN-to-HMAC generator.
- **v13:** fixed ESPHome `StringRef` compatibility for the generator.
- **v14:** switched live keypad processing from plaintext PIN submission to local HMAC-SHA256 and HMAC-only Home Assistant validation.
- **v16/v17:** added Wiegand RFID handling and HMAC-protected RFID validation.
- **v18:** exposed Debug Mode to Home Assistant so keypad opening can fail closed when debugging is enabled.
- **Current Home Assistant workflow:** valid PIN/RFID credentials call a single guarded door-action script; an already-open garage closes on a valid credential; opening can temporarily disarm supported alarm modes and a separate automation restores the exact prior mode after closure only when the keypad flow owned the disarm.

## Security summary

The design converts this failure mode:

```text
Home Assistant configuration leaked
        -> plaintext PINs immediately exposed
```

into:

```text
Home Assistant verifier map leaked
        -> attacker has HMAC values only
        -> ordinary offline PIN enumeration requires the separate ESP32-held key
```

It deliberately does not claim resistance to total compromise of the ESP32 or Home Assistant runtime.
