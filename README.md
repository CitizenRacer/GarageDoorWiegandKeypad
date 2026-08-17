# Garage Door Keypad

ESPHome firmware and Home Assistant configuration for a classic ESP32-based garage door Wiegand keypad controller.

The controller is an **ESP32S 30-pin USB-C NodeMCU development board with ESP32-WROOM-32 and CP2102**. The detected SoC is an **ESP32-D0WD-V3**.

**GitHub `main` is the authoritative firmware/configuration source.** ESPHome Device Builder keeps only a small local wrapper containing secret substitutions and loads the firmware from this repository as a remote Git package.

## Current security design

Firmware v14 performs live keypad validation with a device-local HMAC verifier.

```text
Keypad PIN
   |
   v
ESP32
   |
   | HMAC-SHA256(BLK3 device key, PIN)
   v
64-character verifier
   |
   | encrypted ESPHome native API
   v
Home Assistant
   |
   | lookup in /config/garage_keypad_users.yaml
   v
friendly user / invalid credential
   |
   v
notification-only test path
```

The device-specific 256-bit HMAC key is stored in ESP32 eFuse **BLK3**, permanently write-protected, and intentionally left readable by firmware because this classic ESP32 has no dedicated hardware HMAC peripheral.

Home Assistant stores only HMAC verifier-to-user mappings. Plaintext PINs are not intentionally logged, published as ESPHome entities, stored in the Home Assistant authorization map, or sent over the ESPHome API during normal keypad use.

**The current Home Assistant validation path is deliberately notification-only and does not open the garage door.** This is the safe v14 end-to-end test configuration.

See [`docs/HMAC_PIN_DESIGN.md`](docs/HMAC_PIN_DESIGN.md) for the complete threat model, design rationale, migration history, and limitations.

## Current features

- GitHub-backed ESPHome remote-package workflow
- Wi-Fi connectivity
- ESPHome native API with Noise encryption
- Password-protected OTA updates
- Explicit ESPHome Safe Mode recovery
- Fallback Wi-Fi AP with its own password
- GPIO2 blue connection-status LED
- Home Assistant API-client tracking
- Native Wiegand keypad input
- 4-8 digit PIN collection with `#` submit, `*` clear, and 10-second timeout
- Device-local HMAC-SHA256 PIN transformation
- 256-bit device key in write-protected ESP32 eFuse BLK3
- File-backed HMAC verifier-to-user map in Home Assistant
- Administrative PIN-to-HMAC generator action and Home Assistant helper script
- Notification-only valid/invalid credential test path
- Script trace storage disabled anywhere verifier/PIN material is handled by the checked-in Home Assistant scripts
- Wi-Fi signal, uptime, die temperature, IP, SSID, MAC, and firmware diagnostics

The ESPHome HTTP `web_server` is intentionally disabled. Management and telemetry use the encrypted native API instead of exposing an additional plaintext HTTP interface.

## Repository structure

```text
GarageDoorWiegandKeypad/
├── README.md
├── cad/
├── docs/
│   ├── HMAC_PIN_DESIGN.md
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

  # Testing only. v14 logs HMAC verifiers, never plaintext keypad PINs.
  keypad_debug_logging: "true"

packages:
  garage_keypad:
    url: https://github.com/CitizenRacer/GarageDoorWiegandKeypad
    ref: main
    files:
      - esphome/garage-keypad.yaml
    refresh: 60s
```

The remote firmware defaults `keypad_debug_logging` to `false`.

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

## Firmware versioning and updates

`esphome/garage-keypad.yaml` contains an integer `firmware_version` substitution. Every repository check-in that modifies that file increments the version by one.

The current checked-in firmware is **v14**.

The device logs its firmware version and `ready` after initialization and again after an API client connects so remote log viewers can reliably see the version.

The normal update flow is:

1. Commit firmware changes to `main`.
2. Device Builder refreshes the remote package.
3. Compile and install, normally OTA.
4. Verify the **Firmware Version** diagnostic entity/log output.

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

## Keypad processing

The key collector accepts 4-8 numeric digits. `#` submits, `*` clears, and incomplete entry times out after ten seconds.

On submission, firmware computes:

```text
HMAC-SHA256(BLK3 key, exact PIN string)
```

and sends only the 64-character lowercase hexadecimal verifier to the Home Assistant script.

### Firmware-to-Home-Assistant interface contract

This exact interface is part of the v14 contract and should remain synchronized between firmware and Home Assistant:

```text
script: script.garage_keypad_validate_hmac
field:  hmac
value:  64-character lowercase HMAC-SHA256 verifier
```

Equivalent ESPHome action call:

```yaml
action: script.garage_keypad_validate_hmac
data:
  hmac: <64-character verifier>
```

If HMAC generation fails, the firmware fails closed and supplies an invalid/empty verifier that cannot authorize.

The ESP32 does not contain the user authorization database and does not make the user-mapping decision locally.

### Home Assistant action permission

Enable **Allow the device to perform Home Assistant actions** for the Garage Keypad ESPHome integration entry.

## Home Assistant authorization map

The live verifier map is a dedicated local file:

```text
/config/garage_keypad_users.yaml
```

Use [`homeassistant/garage-keypad-users.example.yaml`](homeassistant/garage-keypad-users.example.yaml) as the template:

```yaml
"<64-character HMAC>": "Example User"
"<64-character HMAC>": "Example Guest"
```

The mapping is **HMAC verifier -> friendly user name**. Plaintext PINs do not belong in this file.

The map was intentionally moved out of `secrets.yaml`. It is still sensitive authorization data and should not be committed, but a disclosure of this file alone does not include the ESP32-held HMAC key needed for ordinary offline PIN enumeration.

The checked-in Home Assistant script uses `file.read_file` with YAML decoding to load this map for each validation attempt.

## Current notification-only validation path

[`homeassistant/garage-keypad-script.yaml`](homeassistant/garage-keypad-script.yaml) defines the canonical firmware-facing script:

```text
script.garage_keypad_validate_hmac
```

It accepts:

```yaml
hmac: <64-character verifier>
```

For a matching verifier, it sends:

```text
Valid Code for User "<friendly name>"
```

For a non-matching verifier, it sends an invalid-code notification.

**It contains no `cover.open_cover` action and cannot open the garage door.** That is intentional during v14 end-to-end testing.

The notification action name is kept in local Home Assistant `secrets.yaml`:

```yaml
garage_keypad_notify_service: "notify.mobile_app_your_phone"
```

The validation script disables stored traces:

```yaml
trace:
  stored_traces: 0
```

## Generating a verifier for a PIN

The firmware exposes the administrative ESPHome action:

```text
esphome.garage_keypad_generate_pin_hmac
```

Example direct Home Assistant action call:

```yaml
action: esphome.garage_keypad_generate_pin_hmac
data:
  pin: "0123"
```

The PIN must be supplied as a string so leading zeroes are preserved.

The device returns a 64-character lowercase HMAC-SHA256 verifier and publishes the latest administratively generated verifier to the **Generated PIN HMAC** diagnostic text sensor for convenient copying.

The checked-in Home Assistant scripts also provide a wrapper:

```text
script.garage_keypad_generate_pin_hmac
```

That wrapper returns the ESP32 response and has stored traces disabled because its input is a plaintext provisioning PIN.

The BLK3 key itself is never returned.

## v14 end-to-end test procedure

Use this procedure when validating the HMAC cutover. It is deliberately safe to run without operating the garage door.

1. Confirm the device reports **Firmware Version 14** and the BLK3 status is provisioned/write-protected/readable.
2. Confirm Home Assistant has `script.garage_keypad_validate_hmac` loaded and the notification-only checked-in behavior is installed.
3. Confirm `/config/garage_keypad_users.yaml` contains the authorized verifier-to-user entries and no plaintext PINs.
4. Enter each authorized keypad code normally and submit with `#`.
5. Confirm a notification identifying the friendly user arrives for each authorized code.
6. Enter one unrecognized/fake code and confirm the invalid-code notification arrives.
7. Confirm no garage-cover action occurs during the entire test.
8. If troubleshooting, temporarily enable `keypad_debug_logging: "true"` and compare the logged verifier with the local map; disable it when finished.

Do not record actual PINs or live HMAC verifiers in issues, commits, screenshots, or test documentation.

## Debug logging

The local wrapper can temporarily set:

```yaml
keypad_debug_logging: "true"
```

Normal keypad entry still does **not** log plaintext PINs. Debug mode logs only the resulting HMAC verifier:

```text
DEBUG MODE - PIN HMAC: [<64 hex characters>]
```

HMAC verifiers are authorization material, so disable debug logging when it is not needed.

## Security boundary

This design is primarily intended to mitigate configuration and backup disclosure.

It protects against a leaked Home Assistant verifier map immediately revealing PINs or supporting ordinary offline PIN enumeration without the separate ESP32-held key.

It does **not** claim to protect against:

- full compromise of the ESP32 firmware;
- full compromise of Home Assistant;
- physical observation of PIN entry;
- interception of Wiegand digits before the ESP32;
- a malicious firmware image that can read BLK3 and keypad input.

See [`docs/HMAC_PIN_DESIGN.md`](docs/HMAC_PIN_DESIGN.md) for details.

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

The device exposes Home Assistant connection state, Wi-Fi signal, uptime, ESP32 die temperature, IP address, SSID, MAC address, firmware version, restart, Safe Mode restart, and the administrative Generated PIN HMAC entity.
