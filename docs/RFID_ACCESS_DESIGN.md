# RFID access status

Production firmware v20 deliberately **does not authorize RFID credentials**.

The Retekess T-AC04 and ESPHome Wiegand component still decode 26-, 34-, and 37-bit RFID frames, and commissioning diagnostics remain available:

```text
RFID tag received: <decoded credential> (authorization disabled)
Wiegand RFID/raw frame: <bits> bits, value=0x<raw>
```

Raw logging remains restricted to frames greater than 8 bits so 4-bit/8-bit keypad keystroke frames are never raw-logged.

## Production behavior

The v20 production cutover validated PIN access through Lock Code Manager. RFID was intentionally excluded from that cutover and cannot operate the garage.

The rule is:

```text
RFID frame -> decode/diagnose -> NO authorization -> NO garage action
```

An RFID frame does not call `lock_code_manager.use_credential`, does not call `script.garage_keypad_open_garage`, and does not open or close the garage.

## Why authorization is disabled

The project moved PIN management to Lock Code Manager in v20 and removed the custom HMAC credential system from the firmware path. Although LCM has credential-type concepts, the managed external-credential path currently used by this project is PIN-oriented.

Treating a raw RFID identifier as a PIN would create misleading credential semantics and make a later proper RFID migration harder. The old HMAC-based RFID authorization path should not be reintroduced as an interim design.

## Diagnostics and confidentiality

RFID commissioning logs can expose decoded/static RFID identifiers to anyone who can read ESPHome logs. Those identifiers should therefore be treated as credential material even though RFID authorization is disabled.

The raw Wiegand logger must continue to enforce `bits > 8`. Four-bit and eight-bit frames are keypad keystrokes and must never be raw-logged because doing so could expose PIN digits.

## Future target

When Lock Code Manager supports the intended RFID credential type end to end for external readers, the target flow is:

```text
T-AC04 RFID
   |
   v
ESPHome Wiegand decoder
   |
   v
LCM RFID credential validation
   |
   v
friendly user
   |
   v
guarded script.garage_keypad_open_garage
```

At that point the project should use LCM's real RFID credential type and unified credential-used event while preserving the same guarded physical-operation layer used by PINs.
