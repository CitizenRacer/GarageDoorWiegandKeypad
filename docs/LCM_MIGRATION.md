# Lock Code Manager migration

This document describes the v19 HMAC-to-v20 Lock Code Manager migration. It is intentionally fail-safe: no step requires moving the garage door until the final production verification.

## Preconditions

- Lock Code Manager 5.3.0 or later; the production installation currently has the lockless `KOZ2 Locks` entry.
- ESPHome 2025.10.0 or later for `homeassistant.action` response capture.
- Garage Keypad ESPHome integration permission **Allow the device to perform Home Assistant actions** enabled.
- Existing `script.garage_keypad_open_garage` retained unchanged during the authentication migration.
- Old HMAC scripts and credential map retained until rollback is no longer needed.

## 1. Populate LCM

Make Lock Code Manager the canonical PIN database. Add every authorized keypad person to the `KOZ2 Locks` entry using the actual PIN intended for that person. Use LCM's enabled state and optional conditions/schedules rather than a custom YAML map.

Do not put PINs in this repository, ESPHome substitutions, entity states, helpers, logs, or documentation.

## 2. Validate LCM without garage motion

Call `lock_code_manager.use_credential` directly from Home Assistant for each authorized PIN and confirm the returned `user` is correct. Test at least one invalid PIN and, if desired, a temporarily disabled user.

These calls must stop at LCM. Do not call `script.garage_keypad_open_garage` during this phase.

Expected response fields:

```text
valid
user
reason
```

Invalid reasons include `unknown_code`, `user_disabled`, and `condition_not_met`.

## 3. Deploy v20 in Debug Mode

Build/deploy firmware v20 with a local wrapper override:

```yaml
substitutions:
  keypad_debug_mode: "true"
```

Confirm the Home Assistant Debug Mode binary sensor is `on` before testing a PIN.

## 4. Physical no-motion test

At the physical T-AC04 keypad:

1. Enter a valid PIN and submit with `#`.
2. Confirm LCM records the credential use and resolves the correct user.
3. Confirm the firmware reaches the guarded door-action script.
4. Confirm `script.garage_keypad_open_garage` refuses opening because Debug Mode is on.
5. Enter an invalid PIN and confirm the guarded door-action script is not called.
6. Inspect ESPHome/Home Assistant logs and entity history. The PIN must not appear.

Do not test the standalone close key unless physical door movement has been explicitly authorized; that path intentionally bypasses credential validation because it is close-only.

## 5. Production cutover

After the no-motion test passes, set:

```yaml
keypad_debug_mode: "false"
```

and redeploy. Confirm the Debug Mode binary sensor positively reports `off`.

Only then perform any explicitly authorized physical open/close test.

## 6. Remove the rollback HMAC path

After v20 has operated correctly:

- remove `script.garage_keypad_validate_hmac`;
- remove `script.garage_keypad_validate_rfid_hmac`;
- remove any administrative HMAC generator script/action;
- remove the old `garage_keypad_users.yaml` credential file after verifying nothing references it;
- remove stale Home Assistant references to `generate_pin_hmac`, `Generated PIN HMAC`, or the old validator names.

The ESP32's previously fused BLK3 bits are permanent and cannot be erased. v20 simply never reads or uses them.

## RFID

RFID authorization is deliberately disabled in v20. Keep the Wiegand RFID diagnostics, but do not represent RFID IDs as LCM PINs. Revisit RFID when LCM's managed credential implementation supports that credential type end to end.

## Rollback

Until step 6, rollback is straightforward: reinstall v19 and restore/use the existing HMAC validator scripts and credential file. Do not delete that Home Assistant path before the v20 no-motion test is complete.
