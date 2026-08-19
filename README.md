# Garage Door Keypad

ESPHome firmware and Home Assistant configuration for a classic ESP32-based garage-door Wiegand keypad/RFID controller.

The controller is an **ESP32S 30-pin USB-C NodeMCU development board with ESP32-WROOM-32 and CP2102**. The detected SoC is an **ESP32-D0WD-V3**.

**GitHub `main` is the authoritative firmware/configuration source.** ESPHome Device Builder keeps only a small local wrapper containing secret substitutions and loads the firmware from this repository as a remote Git package.

## Current release

The current repository firmware is **v18**.

v18 exposes the compile-time keypad debug state as the **Debug Mode** diagnostic binary sensor for Home Assistant. The garage-opening API is designed to fail closed: it can run only when opening has been explicitly enabled, the ESP32 positively reports Debug Mode off, and the house alarm positively reports disarmed. PIN and RFID validators remain disconnected from garage-door control until opening is explicitly enabled.

v17 added HMAC-protected RFID authorization while preserving the existing PIN path. Wiegand RFID credentials are decoded by ESPHome, logged during commissioning, transformed on the ESP32 with HMAC-SHA256 using the existing BLK3 device key, and sent to Home Assistant only as a 64-character verifier.

The firmware version is exposed through the ESPHome project version and the **Firmware Version** diagnostic entity. `esphome/garage-keypad.yaml` increments `firmware_version` for every repository check-in of that file.

## Security design

### PIN path

```text
Keypad PIN
   |
   v
ESP32 key_collector
   |
   | HMAC-SHA256(BLK3 device key, exact PIN string)
   v
64-character verifier
   |
   | encrypted ESPHome native API
   v
script.garage_keypad_validate_hmac
   |
   | top-level lookup in /config/garage_keypad_users.yaml
   v
friendly user / invalid credential
```

Plaintext PINs are not intentionally logged, published as ESPHome entities, stored in the Home Assistant authorization map, or sent over the ESPHome API during normal keypad use.

### RFID path

```text
Wiegand RFID tag
   |
   v
ESPHome Wiegand decoder
   |
   | decoded credential (temporarily logged during commissioning)
   v
HMAC-SHA256(BLK3 device key, exact decoded credential string)
   |
   | 64-character verifier over encrypted ESPHome API
   v
script.garage_keypad_validate_rfid_hmac
   |
   | nested rfid: lookup in /config/garage_keypad_users.yaml
   v
friendly user / invalid credential
```

The RFID verifier prevents the Home Assistant authorization file from containing raw RFID identifiers. It does **not** make a clonable static RFID credential cryptographically unclonable; the reader still receives the credential over Wiegand. See [`docs/RFID_ACCESS_DESIGN.md`](docs/RFID_ACCESS_DESIGN.md).

The device-specific 256-bit HMAC key is stored in ESP32 eFuse **BLK3**, permanently write-protected, and intentionally left readable by firmware because this classic ESP32 has no dedicated hardware HMAC peripheral. See [`docs/HMAC_PIN_DESIGN.md`](docs/HMAC_PIN_DESIGN.md).

### Garage-opening API safety gates

The live Home Assistant opening API is `script.garage_keypad_open_garage`. It is intentionally disabled by default and is not currently called by either credential validator.

Before `cover.open_cover` can run, Home Assistant requires all three native state conditions to pass:

```text
input_boolean.garage_keypad_opening_enabled == on
binary_sensor.garage_garage_keypad_debug_mode == off
alarm_control_panel.5744_surety_5744 == disarmed
```

These are fail-closed checks. `unknown`, `unavailable`, a missing debug entity, debug mode on, any armed alarm state, or opening-enable off stops the script before garage-door control.

**Debug mode is an absolute lockout.** The garage must never be opened through this API while the keypad is in debug mode.

## Threat-model note

This HMAC design primarily hardens configuration and backup disclosure. If an attacker already controls Home Assistant, protecting the keypad validation path from that same attacker adds little garage-door security because Home Assistant itself already has the ability to operate the garage door.

## Current features

- GitHub-backed ESPHome remote-package workflow
- Wi-Fi connectivity
- ESPHome native API with Noise encryption
- Password-protected OTA updates
- Explicit ESPHome Safe Mode recovery
- Fallback Wi-Fi AP with its own password
- GPIO2 blue connection-status LED
- Home Assistant API-client tracking
- Native Wiegand keypad and RFID input
- 4-8 digit PIN collection with `#` submit, `*` clear, and 10-second timeout
- Device-local HMAC-SHA256 PIN transformation
- Device-local HMAC-SHA256 RFID transformation
- 256-bit device key in write-protected ESP32 eFuse BLK3
- One file-backed authorization database for PIN and RFID HMACs
- RFID decoded/raw diagnostics without logging 4-bit or 8-bit keypad frames
- Administrative PIN-to-HMAC generator action and Home Assistant helper script
- Script trace storage disabled where PIN/RFID verifier material is handled
- ESP32 Debug Mode diagnostic exposed to Home Assistant
- Fail-closed garage-opening API with explicit enable, debug-mode lockout, and alarm-disarmed gate
- Wi-Fi signal, uptime, die temperature, IP, SSID, MAC, and firmware diagnostics

The ESPHome HTTP `web_server` is intentionally disabled. Management and telemetry use the encrypted native API instead of exposing an additional plaintext HTTP interface.

## Repository structure

```text
GarageDoorWiegandKeypad/
├── README.md
├── cad/
├── docs/
│   ├── HMAC_PIN_DESIGN.md
│   ├── RFID_ACCESS_DESIGN.md
│   └── images/
├── esphome/
│   ├── garage-keypad.yaml
│   ├── device-builder-wrapper.example.yaml
│   └── secrets.example.yaml
└── homeassistant/
    ├── garage-keypad-script.yaml
    ├── garage-keypad-users.example.yaml
    └── secrets.example.yaml
```

## Hardware and wiring

The S20-ID keypad feeds Wiegand D0 and D1 through the HiLetgo BSS138 level shifter before reaching the ESP32.

Current default wiring:

```text
Keypad Green D0 -> level shifter HV3/LV3 -> GPIO22
Keypad White D1 -> level shifter HV2/LV2 -> GPIO19
```

These pins are substitutions and can be overridden from the local Device Builder wrapper if the physical wiring changes.

### Major hardware

| Qty | Part | Purpose |
|---:|---|---|
| 1 | S20-ID IP68 Wiegand keypad / RFID reader | Outdoor keypad and Wiegand source |
| 1 | ESP32S 30-pin ESP32-WROOM-32 board | Controller |
| 1 | eletechsup ES350+485 30-pin expansion board | Screw-terminal carrier |
| 1 | MEAN WELL HDR-30-12 | 12 V DIN-rail power supply |
| 1 | HiLetgo 4-channel BSS138 level shifter | Wiegand level shifting |
| As needed | 4-conductor 22 AWG security wire | Keypad-to-controller cable |
| As needed | 18 AWG stranded wire | Internal power wiring |

## ESPHome Device Builder setup

The remote firmware uses substitutions because remote Git packages cannot directly read the local Device Builder `secrets.yaml`.

A local wrapper should provide:

```yaml
substitutions:
  wifi_ssid: !secret wifi_ssid
  wifi_password: !secret wifi_password
  ota_password: !secret ota_password
  fallback_ap_password: !secret fallback_ap_password
  garage_keypad_api_encryption_key: !secret garage_keypad_api_encryption_key

  # Testing only. This logs PIN HMAC verifiers, never plaintext keypad PINs.
  # It also sets the Home Assistant Debug Mode diagnostic to on, which is an
  # absolute lockout for the garage-opening API.
  keypad_debug_logging: "false"

packages:
  garage_keypad:
    url: https://github.com/CitizenRacer/GarageDoorWiegandKeypad
    ref: main
    files:
      - esphome/garage-keypad.yaml
    refresh: 60s
```

Do not override `firmware_version` in the local wrapper; the repository package owns release versioning.

### ESPHome secrets

Keep these values only in the Device Builder's local `secrets.yaml`:

```yaml
wifi_ssid: "YOUR_WIFI_NAME"
wifi_password: "YOUR_WIFI_PASSWORD"
ota_password: "YOUR_OTA_PASSWORD"
fallback_ap_password: "YOUR_FALLBACK_AP_PASSWORD"
garage_keypad_api_encryption_key: "YOUR_32_BYTE_BASE64_NOISE_PSK"
```

Generate the API encryption key with:

```text
openssl rand -base64 32
```

Keep any trailing `=` padding.

## BLK3 HMAC key

The firmware provisions a device-specific 256-bit random key into classic ESP32 eFuse BLK3.

Provisioning:

- waits for Wi-Fi so the RF entropy source is active;
- requires the normal 256-bit uncoded BLK3 scheme;
- refuses to overwrite non-empty BLK3;
- verifies the burn before write protection;
- permanently write-protects BLK3;
- never logs the key.

A correctly provisioned controller reports:

```text
HMAC key already provisioned; BLK3 is write-protected and readable
```

The key is intentionally readable by firmware. See the HMAC design document for the threat-model implications.

## PIN processing

The key collector accepts 4-8 numeric digits. `#` submits, `*` clears, and incomplete entry times out after ten seconds.

On submission, firmware computes:

```text
HMAC-SHA256(BLK3 key, exact PIN string)
```

and sends only the 64-character lowercase hexadecimal verifier to:

```text
script.garage_keypad_validate_hmac
field: hmac
```

If HMAC generation fails, the firmware fails closed and supplies an invalid/empty verifier that cannot authorize.

## RFID processing

ESPHome's Wiegand component decodes parity-valid tag frames and supplies the decoded credential to `on_tag`. The commissioning log is:

```text
RFID tag received: <decoded credential>
```

`on_raw` also retains diagnostics for Wiegand frames larger than eight bits:

```text
Wiegand RFID/raw frame: <bits> bits, value=0x<raw>
```

The raw logger explicitly ignores 4-bit and 8-bit frames so keypad keystrokes are not exposed.

After logging the decoded tag, firmware computes:

```text
HMAC-SHA256(BLK3 key, exact decoded RFID credential string)
```

and sends only the verifier to:

```text
script.garage_keypad_validate_rfid_hmac
field: hmac
```

The tested red RFID tag decodes as `5400449`; the live authorization database should contain its **HMAC verifier**, not `5400449`, under the nested `rfid:` map with friendly name `Red Tag`.

## Home Assistant authorization database

The live authorization database is one local file:

```text
/config/garage_keypad_users.yaml
```

Existing PIN HMAC entries remain at the top level. RFID HMAC entries live under `rfid:`:

```yaml
"<64-character PIN HMAC>": "Example PIN User"

rfid:
  "<64-character RFID HMAC>": "Red Tag"
```

This shape intentionally avoids migrating the existing PIN map.

Do not store plaintext PINs or raw RFID credentials in this file, and do not commit the live file.

## Home Assistant scripts

[`homeassistant/garage-keypad-script.yaml`](homeassistant/garage-keypad-script.yaml) contains:

- `script.garage_keypad_validate_hmac` — PIN verifier lookup and notification path; no garage control.
- `script.garage_keypad_validate_rfid_hmac` — RFID verifier lookup under `rfid:` with logging/notification; no garage control.
- `script.garage_keypad_open_garage` — fail-closed garage-opening API, disabled unless the explicit enable helper is on and both safety-state checks pass.
- `script.garage_keypad_generate_pin_hmac` — administrative PIN HMAC helper.

The opening API requires this Home Assistant helper:

```text
input_boolean.garage_keypad_opening_enabled
```

It must remain **off** until garage opening is explicitly enabled. Turning it on is not sufficient by itself: Debug Mode must also be off and the house alarm must be disarmed.

The notification action name is local configuration:

```yaml
garage_keypad_notify_service: "notify.mobile_app_your_phone"
```

Verifier-bearing scripts set:

```yaml
trace:
  stored_traces: 0
```

## Generating a verifier

The firmware exposes the administrative ESPHome action:

```text
esphome.garage_keypad_generate_pin_hmac
```

It accepts 4-8 numeric characters and returns the HMAC for the exact supplied string. Because the current tested RFID credential `5400449` is a seven-digit numeric string and RFID HMACs use the exact decoded credential with the same BLK3 key, this existing action can also be used once to obtain the verifier needed to register the tested `Red Tag` entry.

The BLK3 key itself is never returned.

## Home Assistant action permission

Enable **Allow the device to perform Home Assistant actions** for the Garage Keypad ESPHome integration entry. Without this permission, the ESP32 cannot invoke the PIN or RFID validation scripts.

## Debug logging

The local wrapper can temporarily set:

```yaml
keypad_debug_logging: "true"
```

Normal keypad entry still does **not** log plaintext PINs. Debug mode logs only the resulting PIN HMAC verifier.

v18 also exposes the same compile-time setting to Home Assistant as the **Debug Mode** diagnostic binary sensor. `on` means debug mode is active; `off` means it is not. The garage-opening API requires this entity to positively report `off`, so a missing/unknown/unavailable entity also blocks opening.

RFID commissioning currently logs decoded RFID credentials and raw Wiegand frames over eight bits. Remove those RFID diagnostic logs after commissioning if they are no longer useful.

## Safe Mode recovery

ESPHome Safe Mode is configured as:

```yaml
safe_mode:
  num_attempts: 5
  boot_is_good_after: 1min
  reboot_timeout: 10min
```

After repeated boot failures, ESPHome retains networking, logging, and OTA in Safe Mode. USB ROM-bootloader recovery remains available if needed.

## Blue status LED

The onboard GPIO2 LED indicates connectivity:

- **500 ms on / 500 ms off:** Wi-Fi disconnected/searching
- **Double blink + pause:** Wi-Fi connected, Home Assistant not connected
- **Solid blue:** Home Assistant connected to the encrypted API

## Diagnostics

The device exposes Home Assistant connection state, Debug Mode, Wi-Fi signal, uptime, ESP32 die temperature, IP address, SSID, MAC address, firmware version, restart, Safe Mode restart, and the administrative Generated PIN HMAC entity.
