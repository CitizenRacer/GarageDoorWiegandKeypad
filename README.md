# Garage Door Keypad

ESPHome firmware and Home Assistant configuration for a classic ESP32-based garage door Wiegand keypad controller. The controller is an **ESP32S 30-pin USB-C NodeMCU development board with ESP32-WROOM-32 and CP2102**. The detected SoC is an **ESP32-D0WD-V3**.

**GitHub `main` is the authoritative firmware/configuration source.** ESPHome Device Builder keeps only a small local wrapper containing references to its local secrets and loads the actual firmware from this repository as a remote Git package.

## Current features

- GitHub-backed ESPHome remote-package workflow
- Wi-Fi connectivity
- ESPHome native API for Home Assistant with Noise encryption
- Password-protected ESPHome OTA firmware updates
- Explicit ESPHome Safe Mode recovery after repeated boot failures
- Home Assistant button to restart directly into Safe Mode
- Fallback Wi-Fi access point with its own password
- GPIO2 blue connection-status LED with distinct Wi-Fi and Home Assistant states
- Intentional suppression of ESPHome's GPIO2 strapping-pin warning for the onboard LED
- Explicit Home Assistant API-client tracking so ESPHome log viewers do not affect the LED state
- Home Assistant diagnostic entity showing the filtered HA API connection state
- API client identity/address logging on connect and disconnect for diagnostics
- Native Wiegand keypad input with configurable D0/D1 GPIO substitutions
- 4-8 digit PIN collection with `#` submit, `*` clear, and 10-second timeout
- Direct PIN submission to Home Assistant over the encrypted native API
- Home Assistant-side PIN authorization map stored in local `secrets.yaml`
- Home Assistant validation script that opens the configured garage door only for authorized PINs
- Friendly-name access logging without recording the submitted PIN
- Script trace storage disabled for the security-sensitive PIN validation script
- Explicit keypad debug mode that can log completed PINs during bench testing
- Wi-Fi signal, uptime, ESP32 die temperature, IP address, SSID, MAC, and firmware-version diagnostics

The ESPHome HTTP `web_server` is intentionally disabled. The keypad handles security-sensitive information, so normal management and telemetry use the encrypted native API instead of exposing an additional plaintext HTTP interface.

## Bill of materials

| Qty | Part | Purpose | Link |
|---:|---|---|---|
| 1 | **S20-ID IP68 Wiegand keypad / RFID reader** | Outdoor keypad and 125 kHz ID credential reader; provides Wiegand D0/D1 | [Amazon](https://amzn.to/4zhUrBZ) |
| 1 | **ESP32S 30-pin USB-C ESP32-WROOM-32 development board** | Main controller running ESPHome | [Amazon](https://amzn.to/4wNM9PX) |
| 1 | **eletechsup ES350+485 30-pin ESP32 expansion / terminal board** | Screw-terminal carrier and convenient GPIO/power breakout | [Amazon](https://amzn.to/3SA5LZx) |
| 1 | **MEAN WELL HDR-30-12 DIN-rail power supply** | 120 VAC project power supply providing 12 V DC | [Amazon](https://amzn.to/4zhTsSj) |
| 1 | **HiLetgo 4-channel BSS138 bidirectional logic level shifter** | Level shifts Wiegand D0/D1 for the 3.3 V ESP32 | [Amazon](https://amzn.to/4geWuy3) |
| As needed | **4-conductor 22 AWG security wire, in-wall rated** | In-wall cable between keypad and project enclosure | [Amazon](https://amzn.to/3TZ253Y) |
| As needed | **18 AWG stranded wire** | Internal project power wiring | [Amazon](https://amzn.to/4wEJs36) |
| 1 | **AC power cable** | Mains input cable for the enclosure | [Amazon](https://amzn.to/4ze44kZ) |
| 1 | **Project box / enclosure** | Houses the power supply, controller, level shifter, DIN rail, and terminals | [Amazon](https://amzn.to/4wyDtg6) |
| As needed | **35 mm DIN rail** | Internal mounting rail | [Amazon](https://amzn.to/4wNLYEh) |
| As needed | **DIN-rail wire connectors / terminal blocks** | Organized power and signal distribution | [Amazon](https://amzn.to/4qj1sy7) |
| 1 | **3D-printed level-shifter DIN holder** | Mounts the HiLetgo level-shifter PCB | [`cad/HiLetgo_Level_Shifter_DIN_CableClamp.scad`](cad/HiLetgo_Level_Shifter_DIN_CableClamp.scad) |

## Repository structure

```text
GarageDoorWiegandKeypad/
├── README.md
├── .gitignore
├── cad/
│   └── HiLetgo_Level_Shifter_DIN_CableClamp.scad
├── docs/
│   └── images/
├── esphome/
│   ├── garage-keypad.yaml
│   ├── device-builder-wrapper.example.yaml
│   └── secrets.example.yaml
└── homeassistant/
    ├── garage-keypad-script.yaml
    └── secrets.example.yaml
```

## ESPHome Device Builder setup

ESPHome remote Git packages cannot perform `!secret` lookups inside the remote package. The firmware in `esphome/garage-keypad.yaml` therefore uses substitutions. A small configuration kept locally in Device Builder maps those substitutions to Device Builder's local `secrets.yaml`.

Use [`esphome/device-builder-wrapper.example.yaml`](esphome/device-builder-wrapper.example.yaml) as the local Garage Keypad configuration in Device Builder:

```yaml
substitutions:
  wifi_ssid: !secret wifi_ssid
  wifi_password: !secret wifi_password
  ota_password: !secret ota_password
  fallback_ap_password: !secret fallback_ap_password
  garage_keypad_api_encryption_key: !secret garage_keypad_api_encryption_key

  # TESTING ONLY. Remove this override or set it false before production.
  keypad_debug_logging: "true"

  # Optional pin overrides; the remote package defaults to these.
  # garage_keypad_d0_pin: "GPIO25"
  # garage_keypad_d1_pin: "GPIO26"

packages:
  garage_keypad:
    url: https://github.com/CitizenRacer/GarageDoorWiegandKeypad
    ref: main
    files:
      - esphome/garage-keypad.yaml
    refresh: 5min
```

The repository is public, so no GitHub credentials are required. `ref: main` makes Device Builder consume the current `main` branch.

### ESPHome secrets

Keep these values in ESPHome Device Builder's local `secrets.yaml`:

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

Keep the complete Base64 value, including any trailing `=` padding. Never commit real credentials.

### Normal firmware update workflow

1. Firmware changes are committed to `main`.
2. Every check-in that modifies `esphome/garage-keypad.yaml` increments its integer `firmware_version` by one.
3. Device Builder loads the local wrapper and the GitHub package.
4. Compile and install, normally over OTA.
5. The **Firmware Version** diagnostic entity in Home Assistant reports the installed project version.

## ESP32 target

The hardware reports:

```text
ESP32-D0WD-V3
```

The firmware therefore targets the original/classic ESP32 directly:

```yaml
esp32:
  variant: esp32
  framework:
    type: esp-idf
```

## Wiegand keypad wiring and PIN collection

The S20-ID keypad feeds Wiegand D0 and D1 through the HiLetgo BSS138 level shifter before reaching the ESP32. The default ESP32-side pins are:

```text
D0 -> GPIO25
D1 -> GPIO26
```

They are substitutions and can be overridden from the local Device Builder wrapper:

```yaml
substitutions:
  garage_keypad_d0_pin: "GPIO25"
  garage_keypad_d1_pin: "GPIO26"
```

The key collector accepts numeric PINs from four through eight digits long. `#` submits, `*` clears the current entry, and an incomplete entry times out after ten seconds.

```yaml
key_collector:
  - id: garage_keypad_pin
    source_id: garage_keypad_wiegand
    min_length: 4
    max_length: 8
    allowed_keys: "0123456789"
    end_keys: "#"
    end_key_required: true
    clear_keys: "*"
    timeout: 10s
```

A completed PIN is not exposed as a sensor or text sensor. ESPHome passes it transiently to Home Assistant:

```yaml
- homeassistant.action:
    action: script.garage_keypad_validate_pin
    data:
      pin: !lambda |-
        return x.str();
```

The ESP32 contains no authoritative PIN database and performs no local authorization. There is intentionally no local fallback path.

### Home Assistant action permission

For PIN submission to work, enable **Allow the device to perform Home Assistant actions** for the Garage Keypad ESPHome integration entry.

## Home Assistant PIN validation

The repository contains [`homeassistant/garage-keypad-script.yaml`](homeassistant/garage-keypad-script.yaml). It defines `script.garage_keypad_validate_pin`, which is the action called by the ESP32.

The script intentionally remains **file-based YAML** because it uses `!secret`. It is provided in GitHub only; adding the file to this repository does not modify or install anything in a running Home Assistant instance.

### PIN map

Add the equivalent of the following to Home Assistant's local `/config/secrets.yaml`:

```yaml
garage_keypad_pins:
  "1234": "Example User"
  "5678": "Example Guest"

garage_keypad_garage_entity: "cover.your_garage_door"
```

See [`homeassistant/secrets.example.yaml`](homeassistant/secrets.example.yaml) for the repository-safe example.

The mapping is **PIN -> friendly name**. Keep every PIN quoted so a PIN such as `0420` remains exactly `0420` rather than being interpreted as a number.

Changing the PIN map is entirely a Home Assistant configuration change; it does not require recompiling or reflashing the ESP32.

### Validation behavior

For an authorized PIN, the script:

1. Looks up the submitted string in `garage_keypad_pins`.
2. Calls `cover.open_cover` for `garage_keypad_garage_entity`.
3. Writes a logbook entry containing only the friendly credential name.

For an invalid PIN, it records only `Access denied: invalid PIN` and does not operate the garage door.

The script sets:

```yaml
trace:
  stored_traces: 0
```

because the submitted PIN is an input variable and should not be retained in Home Assistant script traces. Home Assistant's own documentation also warns that values referenced through `!secret` in scripts/automations can be visible to Home Assistant administrators in source/trace views, so administrator access should be treated as trusted access.

### Loading the file

The file is shaped like a normal file-based `scripts.yaml` fragment: its top level is the script ID `garage_keypad_validate_pin`. It can be merged into an existing file-based script configuration or included using Home Assistant's YAML include mechanisms. Because `!secret` is used, it should not be pasted into the UI script YAML editor.

No Home Assistant installation changes are performed by this repository.

## Keypad debug logging

The remote firmware defaults to:

```yaml
keypad_debug_logging: "false"
```

During bench testing, the local Device Builder wrapper can override it with:

```yaml
keypad_debug_logging: "true"
```

Entering PIN `1234` then produces a deliberately conspicuous warning:

```text
[W][keypad]: DEBUG MODE - PIN entered: [1234]
```

**This exposes real PINs in plaintext to ESPHome logs and any connected remote log viewer. Disable debug logging before production use.**

## Security

Home Assistant communicates with the keypad over ESPHome's encrypted native API. The plaintext ESPHome `web_server` component is intentionally not enabled. OTA updates use a separate password, and the fallback Wi-Fi network has its own password.

Outside explicit temporary keypad debug mode, completed PINs are not published as Home Assistant entity states and are not intentionally written to the ESPHome log. The Home Assistant validation script does not include submitted PINs in logbook messages and stores zero script traces.

`secrets.yaml` separates sensitive values from shareable YAML but is not itself encrypted. Never commit the real Home Assistant or ESPHome secrets files.

## Safe Mode recovery

ESPHome Safe Mode is explicitly configured:

```yaml
safe_mode:
  num_attempts: 5
  boot_is_good_after: 1min
  reboot_timeout: 10min
```

After five failed boot attempts, ESPHome enters Safe Mode while retaining networking, logging, and OTA. If ESPHome cannot boot at all, the ESP32 ROM bootloader remains available: hold **BOOT**, press and release **EN/RST**, then release **BOOT** for USB recovery.

## Onboard LEDs

### Red power LED

The red LED is the board's hardware power indicator and is not software controlled.

### Blue status LED

The onboard blue/user LED is on **GPIO2**:

- **500 ms on / 500 ms off:** Wi-Fi disconnected/searching.
- **Double blink + pause:** Wi-Fi connected, Home Assistant not connected.
- **Solid blue:** Home Assistant connected to the encrypted native API.

GPIO2 is an ESP32 boot strapping pin. The firmware uses the board's existing onboard LED without adding an external pull-up/down and explicitly suppresses ESPHome's intentional-use strapping warning.

## Diagnostics

The ESP32 exposes Home Assistant connection state, Wi-Fi signal, uptime, internal silicon temperature, IP address, connected SSID, Wi-Fi MAC address, firmware version, restart, and Safe Mode restart diagnostics. API client connection/disconnection logs identify the client without including credentials or application payloads.
