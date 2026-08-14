# Garage Door Keypad

ESPHome firmware for a classic ESP32-based garage door keypad controller. The board is sold by Aideepen as an **ESP32S 30-pin USB-C NodeMCU development board with ESP32-WROOM-32 and CP2102** (Amazon ASIN `B0DNYR973V`). The detected SoC is an **ESP32-D0WD-V3**.

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

The firmware uses the classic `esp32` silicon variant directly. It does not currently depend on board-specific peripherals or GPIO assumptions.

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

A red LED has been observed illuminated whenever the board is powered. On this style of 30-pin ESP32 development board, the red LED is the power indicator and is not intended as a software-controlled status LED.

Many 30-pin ESP32-WROOM-32 development boards also provide a programmable blue/user LED connected to GPIO2. The exact Aideepen product listing does not explicitly document that connection, so GPIO2 is **not currently configured as an LED in the firmware**. It can be tested later without making the firmware depend on it.

Device health should currently be verified through serial logs, the ESPHome API, the web interface, uptime, and Wi-Fi signal reporting.

## Next steps

Once the keypad is connected, the firmware can be extended with the keypad interface, credential handling, garage-door actions, and Home Assistant status/control entities.
