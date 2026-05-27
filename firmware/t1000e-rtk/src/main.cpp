#include <Arduino.h>
#include <bluefruit.h>
#include "variant.h"

namespace {
constexpr uint32_t gpsBaud = 115200;
constexpr uint16_t bleFlushIntervalMs = 20;
constexpr uint16_t gpsDataWindowMs = 2000;
constexpr uint16_t gpsFixWindowMs = 5000;
constexpr uint16_t gpsDataBlinkPeriodMs = 1500;
constexpr uint16_t gpsDataBlinkOnMs = 100;
constexpr uint16_t gpsFixBlinkPeriodMs = 600;
constexpr uint16_t gpsFixBlinkOnMs = 300;
constexpr size_t gpsBufferSize = 160;
constexpr size_t nmeaLineSize = 120;

BLEUart bleuart;
uint8_t gpsBuffer[gpsBufferSize];
size_t gpsBufferLen = 0;
uint32_t lastBleFlush = 0;
char nmeaLine[nmeaLineSize];
size_t nmeaLineLen = 0;
uint32_t lastGpsData = 0;
uint32_t lastGpsFix = 0;

uint8_t nmeaChecksum(const char *payload) {
  uint8_t checksum = 0;
  while (*payload != '\0') {
    checksum ^= static_cast<uint8_t>(*payload++);
  }
  return checksum;
}

void sendGnssCommand(const char *payload) {
  char command[96];
  snprintf(command, sizeof(command), "$%s*%02X\r\n", payload, nmeaChecksum(payload));
  Serial1.write(command);
  Serial.print("GNSS command: ");
  Serial.print(command);
}

void powerGps() {
  pinMode(GPS_EN, OUTPUT);
  digitalWrite(GPS_EN, HIGH);
  delay(10);

  pinMode(GPS_VRTC_EN, OUTPUT);
  digitalWrite(GPS_VRTC_EN, HIGH);
  delay(10);

  pinMode(GPS_RESET, OUTPUT);
  digitalWrite(GPS_RESET, HIGH);
  delay(10);
  digitalWrite(GPS_RESET, LOW);

  pinMode(GPS_SLEEP_INT, OUTPUT);
  digitalWrite(GPS_SLEEP_INT, HIGH);

  pinMode(GPS_RTC_INT, OUTPUT);
  digitalWrite(GPS_RTC_INT, LOW);

  pinMode(GPS_RESETB, INPUT_PULLUP);
}

void configureGpsForCorrections() {
  for (uint8_t i = 0; i < 25; i++) {
    sendGnssCommand("PAIR382,1");
    delay(40);
  }
  sendGnssCommand("PAIR104,1");
  sendGnssCommand("PAIR066,1,1,1,1,1,1");
  sendGnssCommand("PAIR410,1");
  sendGnssCommand("PAIR050,1000");
}

void advertise() {
  Bluefruit.Advertising.stop();
  Bluefruit.Advertising.addFlags(BLE_GAP_ADV_FLAGS_LE_ONLY_GENERAL_DISC_MODE);
  Bluefruit.Advertising.addTxPower();
  Bluefruit.Advertising.addService(bleuart);
  Bluefruit.ScanResponse.addName();
  Bluefruit.Advertising.restartOnDisconnect(true);
  Bluefruit.Advertising.setInterval(32, 244);
  Bluefruit.Advertising.setFastTimeout(30);
  Bluefruit.Advertising.start(0);
}

void flushGpsToBle() {
  if (gpsBufferLen == 0 || !Bluefruit.connected()) {
    gpsBufferLen = 0;
    return;
  }

  bleuart.write(gpsBuffer, gpsBufferLen);
  gpsBufferLen = 0;
  lastBleFlush = millis();
}

int parseGgaFixQuality(const char *line) {
  if (line[0] != '$' || strstr(line, "GGA,") == nullptr) {
    return 0;
  }

  uint8_t field = 0;
  const char *fieldStart = line;
  for (const char *cursor = line; *cursor != '\0'; cursor++) {
    if (*cursor != ',' && *cursor != '*') {
      continue;
    }

    if (field == 6) {
      return atoi(fieldStart);
    }

    if (*cursor == '*') {
      return 0;
    }

    field++;
    fieldStart = cursor + 1;
  }

  return 0;
}

void processNmeaLine() {
  nmeaLine[nmeaLineLen] = '\0';
  const int fixQuality = parseGgaFixQuality(nmeaLine);
  if (fixQuality > 0) {
    lastGpsFix = millis();
  }
}

void captureNmeaByte(char byte) {
  if (byte == '\r') {
    return;
  }

  if (byte == '\n') {
    if (nmeaLineLen > 0) {
      processNmeaLine();
      nmeaLineLen = 0;
    }
    return;
  }

  if (nmeaLineLen >= nmeaLineSize - 1) {
    nmeaLineLen = 0;
  }

  nmeaLine[nmeaLineLen++] = byte;
}

void updateLed() {
  const uint32_t now = millis();
  const bool hasGpsFix = now - lastGpsFix < gpsFixWindowMs;
  const bool hasGpsData = now - lastGpsData < gpsDataWindowMs;

  if (hasGpsFix) {
    digitalWrite(LED_PIN, now % gpsFixBlinkPeriodMs < gpsFixBlinkOnMs ? HIGH : LOW);
    return;
  }

  if (hasGpsData) {
    digitalWrite(LED_PIN, now % gpsDataBlinkPeriodMs < gpsDataBlinkOnMs ? HIGH : LOW);
    return;
  }

  digitalWrite(LED_PIN, Bluefruit.connected() ? HIGH : LOW);
}

void onBleRx(uint16_t connHandle) {
  (void)connHandle;

  uint8_t correctionBuffer[64];
  while (bleuart.available()) {
    const size_t len = bleuart.read(correctionBuffer, sizeof(correctionBuffer));
    if (len > 0) {
      Serial1.write(correctionBuffer, len);
    }
  }
}
}

void setup() {
  Serial.begin(115200);

  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  powerGps();
  Serial1.begin(gpsBaud);
  delay(500);
  configureGpsForCorrections();

  Bluefruit.configPrphBandwidth(BANDWIDTH_MAX);
  Bluefruit.begin();
  Bluefruit.setTxPower(0);
  Bluefruit.setName("Gozdar-RTK");

  bleuart.begin();
  bleuart.setRxCallback(onBleRx);
  advertise();

  Serial.println("Gozdar T1000-E RTK bridge ready");
}

void loop() {
  while (Serial1.available()) {
    const uint8_t byte = static_cast<uint8_t>(Serial1.read());
    gpsBuffer[gpsBufferLen++] = byte;
    lastGpsData = millis();
    captureNmeaByte(static_cast<char>(byte));

    if (gpsBufferLen == gpsBufferSize || gpsBuffer[gpsBufferLen - 1] == '\n') {
      flushGpsToBle();
    }
  }

  if (gpsBufferLen > 0 && millis() - lastBleFlush >= bleFlushIntervalMs) {
    flushGpsToBle();
  }

  updateLed();
}
