# Lock Code Manager migration

## Status

The v19 HMAC-to-v20 Lock Code Manager migration is **complete in production**.

Firmware v20 is merged to `main`, deployed to the physical Garage Keypad, and validated through the full production path. Lock Code Manager is now the canonical PIN/user store.

The only remaining migration work is optional rollback cleanup on the live Home Assistant instance: remove the obsolete v19 HMAC validators, HMAC generator, and credential-map file after deciding that v19 rollback is no longer needed.

## Production architecture

```text
Retekess T-AC04 PIN
   |
   v
ESPHome v20 key collector
   |
   | encrypted native API
   v
lock_code_manager.use_credential
   |
   v
{ valid, user, reason }
   |
   +--> valid: script.garage_keypad_open_garage(person_name=<LCM user>)
   |
   +--> invalid: stop; no garage action
```

LCM owns credential validity and user identity. `script.garage_keypad_open_garage` remains the guarded physical-operation layer and must not be bypassed.

## Completed cutover record

### 1. LCM population and direct validation — complete

The production lockless `KOZ2 Locks` entry was populated with the intended production keypad users/PINs and validated with `lock_code_manager.use_credential` before firmware cutover.

Expected response fields are:

```text
valid
user
reason
```

Invalid reasons observed/expected include `unknown_code`, `user_disabled`, and `condition_not_met`.

### 2. v20 merged to `main` — complete

Pull request #1, `Firmware v20: migrate keypad PIN validation to Lock Code Manager`, was merged from `lcm-native-credentials` into `main`.

The firmware remains version `20`; the merge itself did not create a new firmware version.

### 3. First v20 deployment with Debug Mode on — complete

The local Device Builder wrapper was updated for v20 and deployed with:

```yaml
substitutions:
  keypad_debug_mode: "true"
```

Stale v19 wrapper configuration referencing `generated_pin_hmac` was removed because that entity no longer exists in v20.

Home Assistant then reported firmware version `20` and Debug Mode `on`.

### 4. Physical no-motion test — passed

Physical keypad submissions were tested while Debug Mode remained on.

Observed results:

- valid physical PIN submissions reached `lock_code_manager.use_credential`;
- LCM resolved valid credentials to the correct friendly users;
- invalid PINs were rejected as `unknown_code`;
- invalid credentials did not reach the guarded garage-operation path;
- ESPHome logs contained PIN length and validation results but not the actual PIN values;
- accepted credentials did not move the garage while Debug Mode was on.

This verified the intended chain through the physical Wiegand keypad, ESPHome key collector, LCM, and the guarded Home Assistant operation script without allowing door motion.

### 5. Production deployment with Debug Mode off — complete

After the no-motion test passed, v20 was redeployed with:

```yaml
keypad_debug_mode: "false"
```

The Debug Mode binary sensor reported `off`.

A valid physical keypad PIN then successfully opened the garage through the normal v20 LCM path and the existing guarded `script.garage_keypad_open_garage` operation layer.

The production cutover is therefore complete.

## Current production requirements

- Lock Code Manager remains the canonical PIN/user database.
- Garage Keypad ESPHome integration must retain **Allow the device to perform Home Assistant actions**.
- ESPHome and Home Assistant 2025.11.0 or later are required for reliable `homeassistant.action` response capture.
- Production `keypad_debug_mode` should be `"false"`.
- The guarded `script.garage_keypad_open_garage` must remain the only valid-credential path to physical garage operation.
- The production live garage script's RATGDO motor-start verification/retry behavior should be preserved.
- PIN values must never be intentionally logged or exposed as entity state/history.
- Raw 4-bit and 8-bit Wiegand frames must never be logged.
- RFID authorization remains disabled in v20.

## Remaining rollback cleanup

The old HMAC path is no longer used by production v20. It may remain temporarily on the live Home Assistant installation only as rollback material.

When rollback is no longer desired, verify there are no active references and remove the obsolete live artifacts:

- `script.garage_keypad_validate_hmac`;
- `script.garage_keypad_validate_rfid_hmac`;
- the administrative HMAC generator script/action;
- the old `garage_keypad_users.yaml` credential file;
- stale Home Assistant references to `generate_pin_hmac`, `Generated PIN HMAC`, or the old validator names;
- stale Device Builder wrapper configuration such as `keypad_debug_logging` or `!extend generated_pin_hmac`.

Do **not** remove `script.garage_keypad_open_garage` or the alarm-restoration automation; those remain part of the production design.

The ESP32's previously fused BLK3 bits are permanent and cannot be erased. Firmware v20 simply does not read or use them.

## Rollback

Until the live HMAC rollback artifacts are removed, rollback remains possible by reinstalling firmware v19 and restoring/using the legacy HMAC validator path.

After those artifacts are intentionally deleted, v20 + Lock Code Manager becomes the sole supported credential architecture.

## RFID

RFID authorization is deliberately disabled in v20. The Wiegand decoder and diagnostics remain available, but RFID IDs are not sent to LCM as fake PINs and cannot operate the garage.

Revisit RFID only when the managed LCM credential flow supports the intended RFID credential type end to end. See [`RFID_ACCESS_DESIGN.md`](RFID_ACCESS_DESIGN.md).
