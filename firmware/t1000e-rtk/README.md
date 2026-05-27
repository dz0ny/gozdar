# T1000-E RTK BLE Bridge

Minimal firmware for the Seeed SenseCAP T1000-E. It exposes the onboard GNSS module over BLE UART:

- GNSS NMEA output is sent from the T1000-E to the connected BLE central.
- Any bytes written by the BLE central are forwarded to the GNSS UART as correction input.

The firmware does not connect to an NTRIP caster by itself. The phone or host app must:

1. Connect to BLE device `Gozdar-RTK`.
2. Read NMEA, especially GGA, from BLE notifications.
3. Connect to the NTRIP caster and send GGA.
4. Write received RTCM correction bytes back to the BLE RX characteristic.

On boot the firmware configures the AG3335 GNSS module with PAIR commands:

- `PAIR382,1` repeated 25 times to lock sleep mode, matching SoftRF's T1000-E AG3335 setup.
- `PAIR104,1` to request dual-band mode on modules that support it.
- `PAIR066,1,1,1,1,1,1` to request GPS, GLONASS, Galileo, BDS, QZSS, and NavIC.
- `PAIR410,1` to request SBAS.
- `PAIR050,1000` to request a 1 Hz fix interval.

These settings are sent on each boot and are not saved with `PAIR513`, so unsupported commands should
not permanently change the receiver configuration.

RTK rover operation does not use RTCM output commands such as `PAIR432`, `PAIR434`, or `PAIR436`.
Those are for base/raw RTCM output workflows. For this bridge, correction bytes are forwarded raw to
the GNSS UART RX with no NMEA wrapper.

BLE UART UUIDs use the Nordic UART Service:

- Service: `6E400001-B5A3-F393-E0A9-E50E24DCCA9E`
- RX, app to device: `6E400002-B5A3-F393-E0A9-E50E24DCCA9E`
- TX, device to app: `6E400003-B5A3-F393-E0A9-E50E24DCCA9E`

Build:

```sh
pio run -d firmware/t1000e-rtk
```

Upload:

```sh
pio run -d firmware/t1000e-rtk -t upload
```
