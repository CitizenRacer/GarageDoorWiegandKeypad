# HMAC PIN Verifier Design

## Purpose

The garage keypad uses short numeric PINs. Those PINs are secrets, but they have very little entropy compared with a cryptographic key. A 4-digit PIN has only 10,000 possible values, and even an 8-digit PIN has only 100,000,000 possible values.

The goal of this design is to prevent the Home Assistant configuration, source repository, configuration backups, or other stored files from directly revealing the keypad PINs or allowing someone who obtains only those files to cheaply recover the PINs offline.

This is intentionally a narrow threat model. It is not intended to make a fully compromised ESP32 or fully compromised Home Assistant host safe.

## Threat being mitigated

Without a keyed verifier, a Home Assistant PIN map might contain plaintext values such as:

```yaml
"1234": "Alice"
"8675309": "Bob"
```

Anyone who obtains that file immediately learns the valid PINs.

Replacing the PINs with ordinary SHA-256 hashes is not sufficient:

```text
SHA256("1234")
```

Because the PIN space is small, an attacker can simply hash every possible 4-8 digit PIN and compare the results. Adding a public salt changes the hash values but does not solve the fundamental problem: the attacker still has everything required to perform the same offline search.

The design therefore uses a secret 256-bit HMAC key that is not stored in Home Assistant, the GitHub repository, or the ESPHome YAML.

The stored verifier is:

```text
HMAC-SHA256(device_secret, PIN)
```

An attacker who obtains only the Home Assistant verifier map does not have the secret key and therefore cannot perform the normal offline PIN-enumeration attack.

## High-level design

```text
                     ESP32

             +-------------------+
             | eFuse BLK3         |
             | 256-bit HMAC key   |
             | write-protected    |
             | readable by FW     |
             +---------+---------+
                       |
                       v
PIN -----> HMAC-SHA256(key, PIN) -----> 64-character hex verifier
                                               |
                                               v
                                      Home Assistant map

```

Home Assistant stores mappings keyed by the HMAC verifier rather than by the plaintext PIN.

Conceptually:

```yaml
"7ab4...64 hex characters...d912": "Alice"
"26f1...64 hex characters...aa80": "Bob"
```

The HMAC is deterministic: the same PIN evaluated by the same ESP32 produces the same verifier every time. Different PINs produce different verifiers, and the same PIN on another ESP32 with a different device key produces a different verifier.

## HMAC key provisioning

The device uses classic ESP32 eFuse block `BLK3` for the HMAC key.

Provisioning is deliberately one-time and defensive:

1. The firmware waits until Wi-Fi has connected so the ESP32 hardware random-number generator is operating with the RF entropy source active.
2. The firmware requires BLK3 to use the normal 256-bit uncoded eFuse scheme.
3. The firmware refuses to provision if BLK3 is read-protected, already contains data, or is already write-protected while empty.
4. The firmware generates 32 random bytes with `esp_fill_random()`.
5. The firmware burns the 256-bit value into BLK3.
6. The firmware reads BLK3 back and verifies the programmed value byte-for-byte.
7. The temporary RAM copies of the key are wiped.
8. The firmware permanently write-protects BLK3.
9. BLK3 remains readable by firmware because the classic ESP32 does not provide the newer hardware-HMAC architecture used by later ESP32 variants.

The resulting normal state is reported as:

```text
HMAC key already provisioned; BLK3 is write-protected and readable
```

Write protection is permanent. The key cannot be replaced in that BLK3 block after provisioning.

## Why BLK3 is readable

On this classic ESP32, software HMAC requires firmware to read the key and supply it to the HMAC implementation. If BLK3 were read-protected, application firmware would no longer be able to obtain the key and could not calculate the PIN verifier.

This is weaker than a secure-element or newer-ESP32 design in which dedicated cryptographic hardware can consume a key that software itself cannot read.

The security property we rely on here is therefore:

> The HMAC key is absent from normal configuration files, source control, Home Assistant storage, and backups.

It is **not**:

> The HMAC key is impossible to extract from a fully compromised ESP32.

## PIN HMAC generator

The firmware exposes an ESPHome API action named:

```text
esphome.garage_keypad_generate_pin_hmac
```

It accepts the PIN as a string so leading zeroes are preserved:

```yaml
action: esphome.garage_keypad_generate_pin_hmac
data:
  pin: "0123"
```

The generator:

1. Requires a 4-8 digit numeric string.
2. Verifies that BLK3 is 256-bit, readable, non-empty, and write-protected.
3. Reads the BLK3 key into RAM.
4. Computes HMAC-SHA256 over the exact PIN string.
5. Wipes the RAM copy of the key and binary digest.
6. Returns a 64-character lowercase hexadecimal verifier.
7. Publishes the verifier to the `Generated PIN HMAC` diagnostic text sensor for convenient copying.

The API does not provide an operation that returns the BLK3 key itself.

The generator exists primarily to provision and maintain the Home Assistant verifier map.

## Intended runtime validation flow

The final runtime design is:

```text
Keypad
  |
  | PIN
  v
ESP32 key collector
  |
  | HMAC-SHA256(BLK3 key, PIN)
  v
64-character verifier
  |
  | encrypted ESPHome native API
  v
Home Assistant
  |
  | lookup verifier in user map
  v
valid / invalid + associated user
```

In that final state, Home Assistant does not need the plaintext PIN or the HMAC key for normal validation.

### Migration note

Firmware v12 introduced the HMAC generator, but at that point the normal keypad validation path still sent the plaintext PIN to the existing Home Assistant validation script. The generator was added first so all existing PINs could be converted to HMAC verifiers and the Home Assistant map could be migrated safely before switching the live keypad path.

This document should be updated when the normal keypad path is changed to send the HMAC verifier instead of the plaintext PIN.

## What this protects against

This design materially improves protection against several realistic accidental-disclosure scenarios:

- accidentally publishing the Home Assistant PIN map;
- committing the verifier map to a public or shared source repository;
- leaking a configuration backup containing the verifier map;
- sharing configuration snippets while forgetting that the map is included;
- an attacker obtaining only the stored verifier file and attempting an offline PIN dictionary attack.

The last case is the main reason for HMAC rather than ordinary SHA-256 or SHA-256 plus a public salt. The HMAC key is required to test PIN guesses.

## What this does not protect against

### Full ESP32 compromise

The classic ESP32 firmware must be able to read BLK3 in order to calculate HMACs. Code executing with sufficient privilege on the ESP32 can therefore potentially obtain the key.

Write protection prevents changing the eFuse key; it does not make the key unreadable.

### Full Home Assistant compromise

A fully compromised Home Assistant installation should be treated as outside this threat model. Depending on the state of the system, an attacker may be able to invoke the ESPHome HMAC-generation action repeatedly and use the ESP32 as an online PIN-guessing oracle.

The generator is therefore not equivalent to a hardware security module with authorization or rate limiting.

### Keypad observation

HMAC does not prevent someone from learning a PIN by physically observing a user enter it, compromising the keypad wiring before the ESP32 processes the digits, or otherwise obtaining the plaintext at the point of entry.

### Malicious firmware

A malicious firmware image running on the ESP32 can read keypad input and, because BLK3 is intentionally readable, can also read the HMAC key. This design does not attempt to solve malicious-firmware resistance.

### Weak user-chosen PINs

HMAC prevents offline verification without the key, but it does not make a weak PIN intrinsically strong. PIN length, rate limiting, lockout behavior, physical security, and authorization policy remain separate controls.

## Why not store the HMAC key in `secrets.yaml`?

Putting the key in `secrets.yaml` would still be better than placing it directly in a public YAML file, but it would make the key part of the Home Assistant / ESPHome configuration secret-management domain and therefore more likely to appear in configuration backups or be exposed alongside the rest of the builder environment.

Using eFuse keeps the HMAC key device-local and removes it from normal configuration material entirely.

This separation specifically addresses the project's primary concern: a configuration-file disclosure should not also disclose everything required to recover the PINs.

## Why write-protect the key?

Once provisioned, the key should never change. If the key changed, every stored HMAC verifier would become invalid.

Permanent write protection provides two useful properties:

- accidental firmware bugs cannot overwrite BLK3; and
- later software cannot silently rotate the device key and invalidate the verifier database.

Read protection is intentionally not enabled because this particular ESP32 requires software access to the key for HMAC computation.

## Device replacement and recovery

The HMAC key is intentionally device-specific and there is no supported key-export workflow.

If the ESP32 is replaced, the new device will generate a new random BLK3 key. Every PIN must then be run through the new device's HMAC generator and the Home Assistant verifier map regenerated.

This is a deliberate tradeoff: configuration backups contain the verifier map but not the secret required to reproduce it on another device.

The plaintext PINs therefore need to be recoverable from the humans or another appropriately protected administrative source when replacing the controller.

## Security summary

The design is best understood as **configuration-disclosure hardening**.

It converts this failure mode:

```text
Home Assistant configuration leaked
        -> PINs immediately exposed
```

into:

```text
Home Assistant verifier map leaked
        -> attacker has HMAC values only
        -> offline PIN enumeration requires the separate ESP32-held key
```

It deliberately does not claim resistance to total compromise of the ESP32 or Home Assistant runtime.

For the current hardware, that is an appropriate improvement at very low operational cost while keeping plaintext PINs out of long-lived configuration files.