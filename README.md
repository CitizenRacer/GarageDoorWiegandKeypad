# Garage Door Keypad

ESPHome firmware for a classic ESP32-based garage door keypad controller. The board is sold by Aideepen as an **ESP32S 30-pin USB-C NodeMCU development board with ESP32-WROOM-32 and CP2102** (Amazon ASIN `B0DNYR973V`). The detected SoC is an **ESP32-D0WD-V3**.

The current firmware provides the secure connectivity and recovery foundation for the garage keypad before the keypad hardware is connected.

## Current features

- Wi-Fi connectivity
- ESPHome native API for Home Assistant with Noise encryption
- Password-protected ESPHome OTA firmware updates
- Explicit ESPHome Safe Mode recovery after repeated boot failures
- Home Assistant button to restart directly into Safe Mode
- Fallback Wi-Fi access point with its own password
- GPIO2 blue connection-status LED with distinct Wi-Fi and Home Assistant states
- Wi-Fi signal sensor
- Uptime sensor
- IP address, SSID, and MAC address reporting
- Remote restart button

The ESPHome HTTP `web_server` is intentionally disabled. The keypad will eventually handle security-sensitive information, so normal management and telemetry use the encrypted native API instead of exposing an additional plaintext HTTP interface.

## Hardware

- Aideepen ESP32S 30-pin USB-C NodeMCU development board
  - ESP32-WROOM-32 module
  - ESP32-D0WD-V3 SoC
  - CP2102 USB-to-serial interface
  - USB-C connector
  - 30-pin layout
  - Amazon ASIN `B0DNYR973V`
- Garage keypad/access controller — not connected yet
- 12 V project power supply
- 12 V to 5 V DC converter for the ESP32

The firmware uses the classic `esp32` silicon variant directly. The onboard blue LED is connected to GPIO2 and is used as a firmware-controlled connection-status indicator.

## Repository structure

```text
GarageDoorKeypad/
├── README.md
├── .gitignore
└── esphome/
    ├── garage-keypad.yaml
    └── secrets.example.yaml
```

## Initial setup

1. Copy `esphome/secrets.example.yaml` to `esphome/secrets.yaml`.
2. Fill in the Wi-Fi, OTA, fallback-AP, and API-encryption values in `secrets.yaml`.
3. Generate a unique ESPHome API encryption key with `openssl rand -base64 32`, or another cryptographically secure method that produces 32 random bytes encoded as base64.
4. Store that value as `garage_keypad_api_encryption_key` in `secrets.yaml`.
5. Add `garage-keypad.yaml` to ESPHome Device Builder or compile it with ESPHome.
6. When ESPHome Device Builder asks for the board family, choose **ESP32** (classic ESP32), not ESP32-S2/S3/C3/C6.
7. Connect the ESP32 by USB-C and perform the first installation over USB if the device has not yet been provisioned. Existing installations can normally be updated over ESPHome OTA.
8. If the board is stuck in an `invalid header` boot loop from an earlier incorrect image, erase the flash first and reinstall over USB.
9. After enabling API encryption, Home Assistant must be configured with the same Noise PSK stored in `garage_keypad_api_encryption_key` before it can reconnect to the device.
10. Future firmware installations can normally be performed wirelessly with ESPHome OTA.

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

## Secrets

Real credentials belong only in `esphome/secrets.yaml`. That file is ignored by Git and must not be committed.

Example:

```yaml
wifi_ssid: "YOUR_WIFI_NAME"
wifi_password: "YOUR_WIFI_PASSWORD"
ota_password: "YOUR_OTA_PASSWORD"
fallback_ap_password: "YOUR_FALLBACK_AP_PASSWORD"
garage_keypad_api_encryption_key: "YOUR_32_BYTE_BASE64_NOISE_PSK"
```

The API encryption key is deliberately namespaced as `garage_keypad_api_encryption_key` so a shared ESPHome `secrets.yaml` can contain independent keys for multiple devices without ambiguity or accidental reuse. Use a unique key for this device and do not commit the real value to the repository.

## Security

Home Assistant communicates with the keypad over ESPHome's native API. The firmware enables ESPHome's Noise-based API encryption using the namespaced secret `garage_keypad_api_encryption_key`.

```yaml
api:
  encryption:
    key: !secret garage_keypad_api_encryption_key
```

The same 32-byte base64 Noise PSK must be stored in Home Assistant's ESPHome integration for this device. Without the matching key, Home Assistant cannot establish the encrypted API session.

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

If firmware damage prevents ESPHome itself from running, the ESP32's ROM serial bootloader remains available. Hold **BOOT**, press and release **EN/RST**, then release **BOOT** to enter the hardware download mode for USB recovery.

## Onboard LEDs

### Red power LED

A red LED is illuminated whenever the board is powered. It is the board's power indicator and is not intended as a software-controlled status LED.

### Blue status LED

The firmware configures the onboard blue/user LED on **GPIO2** as an internal connection-status indicator:

- **Regular blink — 500 ms on / 500 ms off:** Wi-Fi is disconnected and the ESP32 is searching/reconnecting.
- **Double blink, then pause:** Wi-Fi is connected, but Home Assistant has not established a state-subscribing ESPHome API connection. The pattern is 250 ms on, 250 ms off, 250 ms on, then a one-second pause before repeating.
- **Solid blue:** Home Assistant is connected to the encrypted ESPHome native API.

The API check uses `state_subscription_only: true` so a logger-only ESPHome API connection does not falsely make the LED appear fully connected.

## Next steps

Once the keypad is connected, the firmware can be extended with the keypad interface, credential handling, garage-door actions, and Home Assistant status/control entities. Security-sensitive values should remain local to the device/Home Assistant wherever practical and should not be emitted into logs or exposed as unnecessary entities.
