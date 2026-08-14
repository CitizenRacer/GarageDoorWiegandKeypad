# Garage Door Keypad

ESPHome firmware for a classic ESP32-based garage door keypad controller. The detected SoC is an **ESP32-D0WD-V3**.

The current firmware is intentionally minimal. It is meant to verify that the ESP32 is alive, connected to Wi-Fi, visible to Home Assistant, and ready for wireless OTA updates before the keypad hardware is connected.

## Current features

- Wi-Fi connectivity
- ESPHome native API for Home Assistant
- OTA firmware updates
- Web status page on port 80
- Fallback Wi-Fi access point
- Wi-Fi signal sensor
- Uptime sensor
- IP address, SSID, and MAC address reporting
- Remote restart button

## Hardware

- ESP32 with ESP32-D0WD-V3 SoC
- Garage keypad/access controller — not connected yet
- 12 V project power supply
- 12 V to 5 V DC converter for the ESP32

The exact ESP32 development-board model has not yet been identified, so the firmware deliberately does not assume an onboard LED, PSRAM, flash size, or board-specific GPIO mapping. ESPHome is configured using the `esp32` silicon variant directly.

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
2. Fill in your Wi-Fi and password values in `secrets.yaml`.
3. Add `garage-keypad.yaml` to ESPHome Device Builder or compile it with ESPHome.
4. Connect the ESP32 by USB and perform the first installation over USB.
5. If the board is stuck in an `invalid header` boot loop from a previous incorrect image, erase the flash first, then install the new firmware over USB.
6. After it boots, verify that it connects to Wi-Fi and appears in ESPHome/Home Assistant.
7. Open `http://garage-keypad.local` or use the IP address shown by ESPHome.
8. Future firmware installations can be performed wirelessly with ESPHome OTA.

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

ESPHome recommends using the silicon `variant` directly when a specific development-board definition is not required. This also avoids making unsupported assumptions about board-specific peripherals.

## Secrets

Real credentials belong only in `esphome/secrets.yaml`. That file is ignored by Git and must not be committed.

Example:

```yaml
wifi_ssid: "YOUR_WIFI_NAME"
wifi_password: "YOUR_WIFI_PASSWORD"
ota_password: "YOUR_OTA_PASSWORD"
fallback_ap_password: "YOUR_FALLBACK_AP_PASSWORD"
```

## Status indication

No onboard LED is currently configured. The previously assumed ESP32-S3 SuperMini WS2812 on GPIO48 was incorrect for this hardware and has been removed. Until the exact development-board model is identified, device health should be verified through serial logs, the ESPHome API, the web interface, uptime, and Wi-Fi signal reporting.

## Next steps

Once the keypad is connected, the firmware can be extended with the keypad interface, credential handling, garage-door actions, and Home Assistant status/control entities.
