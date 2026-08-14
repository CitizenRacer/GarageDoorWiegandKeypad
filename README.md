# Garage Door Keypad

ESPHome firmware for a classic ESP32-based garage door keypad controller. The board is sold by Aideepen as an **ESP32S 30-pin USB-C NodeMCU development board with ESP32-WROOM-32 and CP2102** (Amazon ASIN `B0DNYR973V`). The detected SoC is an **ESP32-D0WD-V3**.

The current firmware is intentionally minimal. It is meant to verify that the ESP32 is alive, connected to Wi-Fi, visible to Home Assistant, and ready for wireless OTA updates before the keypad hardware is connected.

## Current features

- Wi-Fi connectivity
- ESPHome native API for Home Assistant
- OTA firmware updates
- Web status page on port 80
- Fallback Wi-Fi access point
- GPIO2 blue connection-status LED
- Wi-Fi signal sensor
- Uptime sensor
- IP address, SSID, and MAC address reporting
- Remote restart button

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

The firmware uses the classic `esp32` silicon variant directly. The onboard blue LED is currently expected to be connected to GPIO2 and is used as a firmware-controlled connection-status indicator.

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
4. When ESPHome Device Builder asks for the board family, choose **ESP32** (classic ESP32), not ESP32-S2/S3/C3/C6.
5. Connect the ESP32 by USB-C and perform the first installation over USB.
6. If the board is stuck in an `invalid header` boot loop from a previous incorrect image, erase the flash first, then install the new firmware over USB.
7. After it boots, verify that it connects to Wi-Fi and appears in ESPHome/Home Assistant.
8. Open `http://garage-keypad.local` or use the IP address shown by ESPHome.
9. Future firmware installations can be performed wirelessly with ESPHome OTA.

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
```

## Onboard LEDs

### Red power LED

A red LED has been observed illuminated whenever the board is powered. On this style of 30-pin ESP32 development board, the red LED is the power indicator and is not intended as a software-controlled status LED.

### Blue status LED

The firmware now configures the expected onboard blue/user LED on **GPIO2** as an internal connection-status indicator:

- **Blinking every 500 ms:** Wi-Fi is disconnected and the ESP32 is searching/reconnecting.
- **Off:** Wi-Fi is connected, but Home Assistant has not yet established a state-subscribing ESPHome API connection.
- **Solid blue:** Home Assistant is connected to the ESPHome native API.

The API check uses `state_subscription_only: true` so a logger-only ESPHome API connection does not falsely make the LED appear fully connected.

GPIO2 is a common onboard-blue-LED mapping for this 30-pin ESP32-WROOM-32 layout, but it is being confirmed on this exact Aideepen board through this firmware. If the LED behaves inverted, the GPIO output can be marked `inverted: true`.

## Next steps

Once the keypad is connected, the firmware can be extended with the keypad interface, credential handling, garage-door actions, and Home Assistant status/control entities.
