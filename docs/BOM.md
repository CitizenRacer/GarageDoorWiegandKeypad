# Garage Door Keypad — As-Built Bill of Materials

This is the hardware bill of materials for the installed Garage Door Keypad system. It documents the parts actually selected for the project rather than a generic reference design.

> **Amazon Associates disclosure:** As an Amazon Associate I earn from qualifying purchases.

Amazon links supplied by the project owner are preserved as-is because they already contain the owner's associate attribution. Other Amazon links use associate tag `k-20`.

## Core electronics

| Qty | Part | Purpose | Purchase link |
|---:|---|---|---|
| 1 | Retekess T-AC04 Wiegand keypad / RFID reader | Outdoor PIN keypad and RFID reader | [Amazon](https://www.amazon.com/dp/B07QSFR4FF?tag=k-20) |
| 1 | 30-pin ESP32-WROOM-32 USB-C development board, CP2102 | ESPHome controller | [Amazon](https://www.amazon.com/dp/B0CR5Y2JVD?tag=k-20) |
| 1 | ESP32 DIN-rail carrier with integrated DC-DC buck converter | DIN mounting, screw-terminal breakout, and regulated ESP32 power from the 12 V supply | [AliExpress](https://a.aliexpress.com/_mLu7eDp) |
| 1 | MEAN WELL HDR-30-12 DIN-rail power supply | 120 VAC to 12 VDC power supply for the keypad/control system | [Amazon](https://www.amazon.com/dp/B06XWRWSHT?tag=k-20) |
| 1 | HiLetgo 4-channel BSS138 bidirectional logic-level converter | Wiegand D0/D1 level shifting between the 12 V reader side and ESP32 logic | [Amazon](https://www.amazon.com/dp/B07F7W91LC?tag=k-20) |
| 1 | Custom 3D-printed HiLetgo DIN-rail mount | Secures the level-shifter PCB to the DIN rail | Repository CAD: [`../cad/ChatGPT_HiLetgo_Level_Shifter_DIN_Mount.scad`](../cad/ChatGPT_HiLetgo_Level_Shifter_DIN_Mount.scad) |

### Power architecture

There is **no separate buck-converter module** in the finished system. The ESP32 DIN-rail carrier has the DC-DC converter built in.

```text
120 VAC
   |
   v
MEAN WELL HDR-30-12
   |
   +---- 12 VDC ----> Retekess T-AC04
   |
   +---- 12 VDC ----> ESP32 DIN carrier
                         |
                         +--> integrated buck converter --> ESP32
```

## Enclosure and DIN hardware

| Qty | Part | Purpose | Purchase link |
|---:|---|---|---|
| 1 | Clear-cover electrical enclosure / control box | Houses the DIN rail, power supply, ESP32 carrier, and level shifter | [Amazon](https://amzn.to/4xVVENP) |
| 1 | VAMRONE 35 mm x 7.5 mm slotted aluminum DIN rail | Mounting rail inside the enclosure | [Amazon](https://www.amazon.com/dp/B088FC2KB8?tag=k-20) |
| As needed | CGELE PG7 IP68 nylon cable glands, 3–7 mm | Cable entry, strain relief, and enclosure sealing | [Amazon](https://www.amazon.com/dp/B09GV9Q79C?tag=k-20) |
| 1 | 3 ft 16/3 SJTW grounded power cord | AC mains feed to the HDR-30-12 | [Amazon](https://www.amazon.com/dp/B07BQCMPF2?tag=k-20) |

## Wire and cable

| Qty | Part | Purpose | Purchase link |
|---:|---|---|---|
| As needed | 22 AWG, 4-conductor, stranded CMR security/access-control cable | Cable run from the outdoor T-AC04 to the control enclosure | [Amazon](https://amzn.to/3U5sbm1) |
| As needed | 18 AWG PVC stranded hookup wire | Internal low-voltage power wiring | [Amazon](https://amzn.to/3UrP2YX) |

## Wiegand wiring

The installed Wiegand signal path is:

```text
T-AC04 Green D0 -> level shifter HV3/LV3 -> ESP32 GPIO22
T-AC04 White D1 -> level shifter HV2/LV2 -> ESP32 GPIO19
```

The T-AC04 is powered from the 12 V supply. The ESP32 carrier is also fed from 12 V and uses its integrated buck converter to power the ESP32.

## Existing-system dependencies

These are required by the complete installed system but are not part of the keypad control-box purchase BOM:

- LiftMaster garage-door opener
- ratgdo garage-door interface
- Home Assistant
- ESPHome Device Builder
- Home Assistant alarm integration used by the guarded opening workflow

## Notes

- The active reader is the **Retekess T-AC04**. Older project discussions referenced an S20-ID reader; that is not the final installed reader.
- The ESP32 is the classic ESP32-WROOM-32 design used by the current firmware, not one of the later ESP32-S3 spare boards.
- The HiLetgo level shifter is mounted using the project's custom DIN-rail part.
- The live authorization database, HMAC key material, PINs, and RFID credentials are intentionally **not** part of this document or repository.
