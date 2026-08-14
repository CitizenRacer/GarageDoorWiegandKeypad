# Garage Door Keypad

ESPHome firmware for a classic ESP32-based garage door keypad controller. The controller is an **ESP32S 30-pin USB-C NodeMCU development board with ESP32-WROOM-32 and CP2102**. The detected SoC is an **ESP32-D0WD-V3**.

**GitHub `main` is the authoritative firmware source.** ESPHome Device Builder keeps only a small local wrapper containing references to its local secrets and loads the actual firmware from this repository as a remote Git package.

## Current features

- GitHub-backed ESPHome remote-package workflow
- Wi-Fi connectivity
- ESPHome native API for Home Assistant with Noise encryption
- Password-protected ESPHome OTA firmware updates
- Explicit ESPHome Safe Mode recovery after repeated boot failures
- Home Assistant button to restart directly into Safe Mode
- Fallback Wi-Fi access point with its own password
- GPIO2 blue connection-status LED with distinct Wi-Fi and Home Assistant states
- Explicit Home Assistant API-client tracking so ESPHome log viewers do not affect the LED state
- Home Assistant diagnostic entity showing the filtered HA API connection state
- API client identity/address logging on connect and disconnect for diagnostics
- Wi-Fi signal sensor
- Uptime sensor
- ESP32 internal die-temperature diagnostic sensor
- IP address, SSID, and MAC address reporting
- Firmware version exposed to Home Assistant
- Remote restart button

The ESPHome HTTP `web_server` is intentionally disabled. The keypad will eventually handle security-sensitive information, so normal management and telemetry use the encrypted native API instead of exposing an additional plaintext HTTP interface.

## Bill of materials

The following are the selected parts for the current build. Amazon links point to the specific parts chosen for this project.

| Qty | Part | Purpose | Link |
|---:|---|---|---|
| 1 | **S20-ID IP68 Wiegand keypad / RFID reader** | Outdoor keypad and 125 kHz ID credential reader; provides Wiegand D0/D1 to the controller | [Amazon](https://amzn.to/4zhUrBZ) |
| 1 | **ESP32S 30-pin USB-C ESP32-WROOM-32 development board** | Main controller running ESPHome | [Amazon](https://amzn.to/4wNM9PX) |
| 1 | **eletechsup ES350+485 30-pin ESP32 expansion / terminal board** | Screw-terminal carrier for the ESP32 with convenient power/GPIO breakout and DIN-rail-friendly mounting | [Amazon](https://amzn.to/3SA5LZx) |
| 1 | **MEAN WELL HDR-30-12 DIN-rail power supply** | 120 VAC project power supply providing 12 V DC | [Amazon](https://amzn.to/4zhTsSj) |
| 1 | **HiLetgo 4-channel BSS138 bidirectional logic level shifter** | Level shifts the keypad Wiegand D0/D1 signals for the 3.3 V ESP32 | [Amazon](https://amzn.to/4geWuy3) |
| As needed | **4-conductor 22 AWG security wire, in-wall rated** | In-wall cable between the outdoor keypad and the project enclosure | [Amazon](https://amzn.to/3TZ253Y) |
| As needed | **18 AWG stranded wire** | Internal project power wiring | [Amazon](https://amzn.to/4wEJs36) |
| 1 | **AC power cable** | Mains input cable for the project enclosure | [Amazon](https://amzn.to/4ze44kZ) |
| 1 | **Project box / enclosure** | Houses the power supply, controller, level shifter, DIN rail, and terminal blocks | [Amazon](https://amzn.to/4wyDtg6) |
| As needed | **35 mm DIN rail** | Additional internal mounting rail | [Amazon](https://amzn.to/4wNLYEh) |
| As needed | **DIN-rail wire connectors / terminal blocks** | Organized power and signal distribution inside the enclosure | [Amazon](https://amzn.to/4qj1sy7) |
| 1 | **3D-printed level-shifter DIN holder** | Mounts the HiLetgo level-shifter PCB to the DIN rail | [`cad/HiLetgo_Level_Shifter_DIN_CableClamp.scad`](cad/HiLetgo_Level_Shifter_DIN_CableClamp.scad) |

### Reference images

#### S20-ID IP68 Wiegand keypad

<a href="https://amzn.to/4zhUrBZ"><img src="https://esphome.io/images/wiegand.jpg" alt="S20-ID Wiegand keypad and RFID reader" width="260"></a>

#### ESP32S 30-pin USB-C board

<a href="https://amzn.to/4wNM9PX"><img src="https://down-vn.img.susercontent.com/file/sg-11134201-7qven-ljgyfu3ej66q67" alt="ESP32S 30-pin USB-C ESP32-WROOM-32 development board" width="420"></a>

#### ESP32 screw-terminal expansion board

<a href="https://amzn.to/3SA5LZx"><img src="docs/images/esp32-terminal-board.jpg" alt="eletechsup ES350+485 30-pin ESP32 expansion terminal board" width="560"></a>

#### MEAN WELL HDR-30-12 power supply

<a href="https://amzn.to/4zhTsSj"><img src="https://nowyelektronik.pl/img/p/3/4/7/6/7/7/347677-large_default.jpg" alt="MEAN WELL HDR-30-12 DIN rail power supply" width="360"></a>

The firmware uses the classic `esp32` silicon variant directly. The onboard blue LED is connected to GPIO2 and is used as a firmware-controlled connection-status indicator.

## Repository structure

```text
GarageDoorWiegandKeypad/
├── README.md
├── .gitignore
├── cad/
│   └── HiLetgo_Level_Shifter_DIN_CableClamp.scad
├── docs/
│   └── images/
│       └── esp32-terminal-board.jpg
└── esphome/
    ├── garage-keypad.yaml
    ├── device-builder-wrapper.example.yaml
    └── secrets.example.yaml
```

## ESPHome Device Builder setup

ESPHome remote Git packages cannot perform `!secret` lookups inside the remote package. The firmware in `esphome/garage-keypad.yaml` therefore uses substitutions such as `${wifi_password}`. A small configuration kept locally in Device Builder maps those substitutions to Device Builder's local `secrets.yaml`.

ESPHome documents this pattern in its [Remote/Git Packages](https://esphome.io/components/packages/#remote-git-packages) documentation.

Use the contents of [`esphome/device-builder-wrapper.example.yaml`](esphome/device-builder-wrapper.example.yaml) as the **local Garage Keypad configuration in Device Builder**:

```yaml
substitutions:
  wifi_ssid: !secret wifi_ssid
  wifi_password: !secret wifi_password
  ota_password: !secret ota_password
  fallback_ap_password: !secret fallback_ap_password
  garage_keypad_api_encryption_key: !secret garage_keypad_api_encryption_key

packages:
  garage_keypad:
    url: https://github.com/CitizenRacer/GarageDoorWiegandKeypad
    ref: main
    files:
      - esphome/garage-keypad.yaml
    refresh: 5min
```

The repository is public, so no GitHub username, token, or password is required. `ref: main` makes Device Builder consume the current `main` branch. `refresh: 5min` allows ESPHome to cache the repository briefly while still picking up new commits quickly.

### Secrets

Keep these values in ESPHome Device Builder's **local** `secrets.yaml`:

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

Keep the complete Base64 value, including any trailing `=` padding. Real credentials must never be committed to this repository. `esphome/secrets.example.yaml` exists only as a reference for the required secret names.

### Normal update workflow

1. Firmware changes are committed to `main` in this repository.
2. Every check-in that modifies `esphome/garage-keypad.yaml` increments its integer `firmware_version` by one.
3. ESPHome Device Builder loads the local wrapper, refreshes the Git package from GitHub, and merges the local secret-backed substitutions into it.
4. Compile and install the update from Device Builder, normally over OTA.
5. The **Firmware Version** diagnostic entity in Home Assistant reports the version compiled from the GitHub package.

This eliminates the need to manually keep a second full copy of `garage-keypad.yaml` inside Device Builder.

## Initial installation / recovery

1. Configure the Device Builder wrapper and local secrets as described above.
2. When Device Builder asks for the board family, choose **ESP32** (classic ESP32), not ESP32-S2/S3/C3/C6.
3. Connect the ESP32 by USB-C and perform the first installation over USB if the device has not yet been provisioned.
4. If the board is stuck in an `invalid header` boot loop from an earlier incorrect image, erase the flash first and reinstall over USB.
5. Home Assistant must use the same Noise PSK stored in `garage_keypad_api_encryption_key` before it can establish the encrypted native API connection.
6. Subsequent firmware installations can normally be performed wirelessly with ESPHome OTA.

## ESP32 target

The hardware reports:

```text
ESP32-D0WD-V3
```

This is the original/classic ESP32 family, not an ESP32-S3. The firmware therefore uses:

```yaml
esp32:
  variant: esp32
  framework:
    type: esp-idf
```

Using the silicon variant directly avoids unnecessary board-specific assumptions while remaining correct for this ESP32-WROOM-32 development board.

## Security

Home Assistant communicates with the keypad over ESPHome's native API. The remote firmware package consumes the encryption key as a substitution supplied by the local Device Builder configuration:

```yaml
api:
  encryption:
    key: "${garage_keypad_api_encryption_key}"
```

The local Device Builder wrapper maps that substitution to:

```yaml
garage_keypad_api_encryption_key: !secret garage_keypad_api_encryption_key
```

The plaintext ESPHome `web_server` component is intentionally not enabled. OTA updates remain protected by the separate `ota_password`, and the fallback Wi-Fi network has its own `fallback_ap_password`.

## Safe Mode recovery

ESPHome Safe Mode is explicitly configured:

```yaml
safe_mode:
  num_attempts: 5
  boot_is_good_after: 1min
  reboot_timeout: 10min
```

Behavior:

- A boot is considered successful after the firmware runs continuously for one minute.
- After five failed boot attempts, ESPHome enters Safe Mode.
- Safe Mode disables normal components while retaining networking, serial logging, and OTA so a bad firmware configuration can usually be repaired wirelessly.
- Safe Mode remains available for ten minutes before rebooting and trying normal firmware again.
- Home Assistant exposes a **Restart in Safe Mode** button for intentionally entering the recovery environment before an OTA repair.

If firmware damage prevents ESPHome itself from running, the ESP32's ROM serial bootloader remains available. Hold **BOOT**, press and release **EN/RST**, then release **BOOT** to enter hardware download mode for USB recovery.

## Onboard LEDs

### Red power LED

A red LED is illuminated whenever the board is powered. It is the board's power indicator and is not intended as a software-controlled status LED.

### Blue status LED

The firmware configures the onboard blue/user LED on **GPIO2** as an internal connection-status indicator:

- **Regular blink — 500 ms on / 500 ms off:** Wi-Fi is disconnected and the ESP32 is searching/reconnecting.
- **Double blink, then pause:** Wi-Fi is connected, but Home Assistant is not connected to the ESPHome API. The pattern is 250 ms on, 250 ms off, 250 ms on, then a one-second pause before repeating.
- **Solid blue:** Home Assistant is connected to the encrypted ESPHome native API.

Home Assistant connection state is tracked from ESPHome's API `on_client_connected` and `on_client_disconnected` events. Only clients whose reported `client_info` begins with `Home Assistant ` count toward the solid-blue state. This prevents an `ESPHome Logs` client from changing the LED indication.

## Home Assistant connection status entity

The device exposes a diagnostic binary sensor named **Home Assistant Connected**. It uses the same filtered `home_assistant_api_connections` counter as the blue LED:

```yaml
binary_sensor:
  - platform: template
    name: "Home Assistant Connected"
    id: home_assistant_connected
    device_class: connectivity
    entity_category: diagnostic
    lambda: |-
      return id(home_assistant_api_connections) > 0;
```

Home Assistant's `connectivity` binary-sensor device class renders the state as **Connected** or **Disconnected**. If the native API transport itself is lost, Home Assistant will normally mark the ESPHome device/entities unavailable because the ESP32 cannot transmit a final state over a connection that no longer exists.

## ESP32 temperature diagnostic

The device exposes the ESP32's internal silicon temperature as **ESP32 Temperature**:

```yaml
sensor:
  - platform: internal_temperature
    name: "ESP32 Temperature"
    entity_category: diagnostic
    update_interval: 60s
```

This is the ESP32 die temperature, not the ambient temperature inside the enclosure. It is intended for hardware-health and thermal-trend diagnostics rather than room-temperature measurement.

## API client diagnostics

Every ESPHome native-API client connection and disconnection is logged with the reported `client_info` and remote address. This distinguishes Home Assistant from ESPHome Device Builder/log clients.

The diagnostic message is delayed by three seconds because a newly connected remote log viewer is not yet subscribed to the log stream at the exact instant its API connection is established. The Home Assistant connection counter used by the status LED is updated immediately; only the diagnostic log message is delayed.

Example:

```text
[api_client] Connected: client_info='Home Assistant 2026.x.x' address='10.0.0.x'
[api_client] Disconnected: client_info='Home Assistant 2026.x.x' address='10.0.0.x'
```

These messages do not include the Noise PSK, Wi-Fi password, keypad credentials, or application payload data.

## Next steps

Once the keypad is connected, the firmware can be extended with the Wiegand interface, credential handling, garage-door actions, and Home Assistant status/control entities. Security-sensitive values should remain local to the device/Home Assistant wherever practical and should not be emitted into logs or exposed as unnecessary entities.
