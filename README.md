# Garage Door Keypad

ESPHome firmware for an ESP32-S3 SuperMini that will eventually interface with the outdoor garage door keypad/access controller.

The current firmware is intentionally minimal. It is meant to verify that the ESP32 is alive, connected to Wi-Fi, visible to Home Assistant, and ready for wireless OTA updates before the keypad hardware is connected.

## Current features

- Wi-Fi connectivity
- ESPHome native API for Home Assistant
- OTA firmware updates
- Web status page on port 80
- Fallback Wi-Fi access point
- Onboard WS2812 status LED
- Wi-Fi signal sensor
- Uptime sensor
- IP address, SSID, and MAC address reporting
- Remote restart button

## Hardware

- ESP32-S3 SuperMini
- Garage keypad/access controller — not connected yet
- 12 V project power supply
- 12 V to 5 V DC converter for the ESP32

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
4. Connect the ESP32-S3 SuperMini by USB-C and perform the first installation over USB.
5. After it boots, verify that the onboard LED turns green and the device connects to Wi-Fi.
6. Open `http://garage-keypad.local` or use the IP address shown by ESPHome.
7. Future firmware installations can be performed wirelessly with ESPHome OTA.

## Secrets

Real credentials belong only in `esphome/secrets.yaml`. That file is ignored by Git and must not be committed.

Example:

```yaml
wifi_ssid: "YOUR_WIFI_NAME"
wifi_password: "YOUR_WIFI_PASSWORD"
ota_password: "YOUR_OTA_PASSWORD"
fallback_ap_password: "YOUR_FALLBACK_AP_PASSWORD"
```

## Status LED

The onboard WS2812 LED is configured on GPIO48. At boot, the firmware turns it green at low brightness as a simple visual indication that ESPHome has started.

## Next steps

Once the keypad is connected, the firmware can be extended with the keypad interface, credential handling, garage-door actions, and Home Assistant status/control entities.
