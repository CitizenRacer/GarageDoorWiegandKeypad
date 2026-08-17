# HMAC PIN Verifier Design

## Purpose

The garage keypad uses short numeric PINs. Those PINs are secrets, but they have very little entropy compared with a cryptographic key. A 4-digit PIN has only 10,000 possible values, and even an 8-digit PIN has only 100,000,000 possible values.

The goal of this design is to prevent Home Assistant configuration, source repositories, configuration backups, or other stored files from directly revealing keypad PINs or from giving someone who obtains only those files everything needed to recover the PINs offline.

This is deliberately **configuration-disclosure hardening**. It is not intended to make a fully compromised ESP32 or fully compromised Home Assistant host safe.

## Threat being mitigated

A plaintext authorization map such as:

```yaml
"1234": "Alice"
"8675309": "Bob"
```

immediately reveals the valid PINs if the file is leaked.

Ordinary SHA-256 is not a sufficient replacement:

```text
SHA256("1234")
```

The PIN space is small enough that an attacker can hash every possible 4-8 digit PIN and compare the results. A public salt changes the hash values but does not remove that offline guessing attack because the attacker still has everything required to test guesses.

This design instead stores:

```text
HMAC-SHA256(device_secret, PIN)
```

The HMAC key is a random 256-bit device secret held in the ESP32's eFuse BLK3. It is not stored in Home Assistant, GitHub, ESPHome YAML, or normal configuration backups.

An attacker who obtains only the Home Assistant verifier map therefore does not possess the secret needed to perform the normal offline PIN-enumeration attack.

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
Home Assistant
      |
      | lookup verifier in garage_keypad_hmacs
      v
valid / invalid + associated user
```

Home Assistant does not need the plaintext PIN or the HMAC key during normal validation.

The normal keypad path sends only the 64-character HMAC verifier to:

```text
script.garage_keypad_validate_hmac
```

with the field:

```yaml
hmac: <64-character verifier>
```

The authorization map is:

```yaml
garage_keypad_hmacs:
  "7ab4...64 hex characters...d912": "Alice"
  "26f1...64 hex characters...aa80": "Bob"
```

The HMAC is deterministic: the same PIN evaluated by this ESP32 produces the same verifier every time. A different ESP32 with a different BLK3 key produces a different verifier for the same PIN.

## HMAC key provisioning

The classic ESP32 uses eFuse block `BLK3` for the device HMAC key.

Provisioning is one-time and defensive:

1. Firmware waits until Wi-Fi is connected so the hardware RNG has the RF entropy source active.
2. BLK3 must use the normal 256-bit uncoded eFuse scheme.
3. Provisioning refuses to modify a non-empty block.
4. Provisioning refuses an empty block that is already write-protected.
5. Provisioning refuses a read-protected block because this classic ESP32 must read the key in software.
6. `esp_fill_random()` generates 32 random bytes.
7. The 256-bit value is burned into BLK3.
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

For each completed keypad PIN, firmware v14:

1. Reads the already-provisioned BLK3 key into a temporary RAM buffer.
2. Computes HMAC-SHA256 over the exact PIN string.
3. Wipes the temporary key buffer.
4. Converts the 32-byte digest to 64 lowercase hexadecimal characters.
5. Wipes the binary digest buffer.
6. Sends only the hexadecimal verifier to Home Assistant.

If the eFuse state is invalid, the key cannot be read, SHA-256 is unavailable, or HMAC calculation fails, the firmware fails closed. It emits an error and supplies an empty verifier, which the Home Assistant validation script rejects.

The plaintext PIN is not intentionally logged, published as an ESPHome entity, or sent to Home Assistant.

When `keypad_debug_logging` is enabled, only the HMAC verifier is logged:

```text
DEBUG MODE - PIN HMAC: [<64 hex characters>]
```

This verifier is still security-sensitive and debug logging should be disabled when it is not needed, but enabling debug mode no longer writes plaintext PINs to the log.

## Administrative PIN HMAC generator

The device retains an ESPHome API action for adding or rotating authorized PIN entries without exporting the BLK3 key:

```text
esphome.garage_keypad_generate_pin_hmac
```

Example:

```yaml
action: esphome.garage_keypad_generate_pin_hmac
data:
  pin: "0123"
```

The PIN is deliberately supplied as a string so leading zeroes are preserved.

The generator:

1. Requires a 4-8 digit numeric string.
2. Requires BLK3 to be 256-bit, readable, non-empty, and write-protected.
3. Reads the key into RAM.
4. Computes HMAC-SHA256 over the exact PIN string.
5. Wipes the RAM key and binary digest buffers.
6. Returns the 64-character lowercase hexadecimal verifier.
7. Publishes that verifier to the `Generated PIN HMAC` diagnostic text sensor for convenient administrative copying.

The API does not expose an operation that returns the BLK3 key itself.

This generator is an administrative provisioning tool. It is not part of normal keypad validation.

## Home Assistant validation

Home Assistant stores only verifier-to-user mappings:

```yaml
garage_keypad_hmacs:
  "<64 hex verifier>": "Friendly User Name"
```

The validation script accepts a field named `hmac`, requires the submitted value to be exactly 64 characters, and looks it up in `garage_keypad_hmacs`.

Successful access logs contain only the friendly credential name. Invalid access logs do not include the submitted verifier. Script trace storage is disabled for the validation script.

## What this protects against

This design materially improves protection against realistic accidental-disclosure scenarios, including:

- accidentally publishing the Home Assistant authorization map;
- committing the verifier map to a public or shared repository;
- leaking a configuration backup containing the map;
- sharing configuration snippets while forgetting the map is included;
- an attacker obtaining only the stored verifier map and trying to recover short PINs offline.

The last case is the reason for HMAC rather than ordinary SHA-256 or SHA-256 with a public salt. Testing a PIN guess requires the separate ESP32-held key.

## What this does not protect against

### Full ESP32 compromise

The classic ESP32 firmware must read BLK3 to calculate HMACs. Malicious code executing with sufficient privilege on the ESP32 can therefore potentially read the HMAC key and capture keypad input.

Write protection prevents changing the eFuse key. It does not make the key unreadable.

### Full Home Assistant compromise

A fully compromised Home Assistant installation is outside this threat model. An attacker with sufficient access may be able to invoke `generate_pin_hmac` repeatedly and use the ESP32 as an online PIN-guessing oracle.

The generator is not equivalent to an HSM or secure element with authorization and rate limiting.

### Physical/keypad observation

HMAC cannot stop someone from learning a PIN by watching a user enter it, compromising the keypad itself, or intercepting the Wiegand digit stream before the ESP32 performs the HMAC.

### Malicious firmware

A malicious firmware image can observe the plaintext keypad input and, because BLK3 is intentionally readable, can also obtain the HMAC key. This design does not attempt to provide secure-boot-based or hardware-backed malicious-firmware resistance.

### Weak user-selected PINs

HMAC protects the stored verifier map from ordinary offline enumeration without the device key. It does not make a weak PIN intrinsically strong. PIN length, attempt throttling, physical security, and authorization policy remain separate controls.

## Why the key is not in `secrets.yaml`

Putting the HMAC key in `secrets.yaml` would be better than embedding it directly in shareable YAML, but it would still place the key in the Home Assistant / ESPHome configuration-secret domain. That increases the chance that the key appears in configuration backups or is exposed alongside the verifier map.

Using eFuse keeps the key device-local and removes it from ordinary configuration material.

This directly addresses the project's primary threat: a configuration-file disclosure should not also disclose everything necessary to recover the PINs.

## Why the key is write-protected

The key must remain stable because every authorized HMAC verifier depends on it.

Permanent write protection means:

- firmware bugs cannot accidentally overwrite BLK3; and
- later software cannot silently rotate the device key and invalidate every stored verifier.

Read protection is intentionally not enabled because this classic ESP32 requires software access to the key.

## Device replacement and recovery

The BLK3 key is device-specific and there is no supported key-export workflow.

If the ESP32 is replaced, the replacement controller will generate a new random BLK3 key. Existing verifiers will no longer match. Each authorized PIN must be entered into the new controller's administrative HMAC generator and the Home Assistant verifier map rebuilt.

This is an intentional tradeoff: configuration backups contain verifier values but not the secret needed to reproduce them on another device.

## Migration history

- **v9:** provisioned and permanently write-protected the 256-bit BLK3 key.
- **v10/v11:** added reliable firmware/HMAC status diagnostics.
- **v12:** added the administrative PIN-to-HMAC generator.
- **v13:** fixed ESPHome `StringRef` compatibility for the generator.
- **v14:** switched live keypad validation from plaintext PIN submission to local HMAC-SHA256 and HMAC-only Home Assistant validation.

The migration deliberately converted the Home Assistant verifier map before v14 was deployed so authorization would not be broken during the cutover.

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

For the current hardware and threat model, it keeps plaintext PINs out of long-lived configuration and out of the normal device-to-Home-Assistant validation path at low operational cost.
