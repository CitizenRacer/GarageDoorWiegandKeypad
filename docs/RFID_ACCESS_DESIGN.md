# RFID access status

Firmware v20 deliberately **does not authorize RFID credentials**.

The Retekess T-AC04 and ESPHome Wiegand component still decode 26-, 34-, and 37-bit RFID frames, and commissioning diagnostics remain available:

```text
RFID tag received: <decoded credential> (authorization disabled)
Wiegand RFID/raw frame: <bits> bits, value=0x<raw>
```

Raw logging remains restricted to frames greater than 8 bits so 4-bit/8-bit keypad keystroke frames are never raw-logged.

## Why authorization is disabled

The project moved PIN management to Lock Code Manager in v20 and removed the custom HMAC credential system entirely. Although LCM has credential-type concepts, the current external managed-credential path used by this project is PIN-oriented. Treating a raw RFID identifier as a PIN would produce misleading credential semantics and make future migration harder.

Therefore the v20 rule is:

```text
RFID frame -> decode/diagnose -> NO authorization -> NO garage action
```

## Future target

When LCM supports RFID credentials end to end for external readers, the intended flow is:

```text
T-AC04 RFID -> ESPHome -> LCM RFID credential validation -> friendly user -> guarded garage action
```

At that point the project should use LCM's real RFID credential type and unified credential-used event. Do not reintroduce the old HMAC map as an interim design.
