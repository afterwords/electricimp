local i2c = hardware.i2c89;
i2c.configure(CLOCK_SPEED_100_KHZ);
const i2c_ioexp = 0x7C; //SX1509 IO expander address
const i2c_temp = 0x92; //TMP102 temperature sensor address
const cal_tmp102 = -1.7 //Calibration for tmp102 in celsius
const i2c_owbus = 0x36; //DS2482 1wire bus address

zAmbientAddress <- [0x2F000005,0x5907E128];
zSurfaceAddress <- [0xCE000005,0xB420B728];
zGapAddress <- [0xA1000005,0xB304CE28];
zLightPin <- 12;
gAmbientAddress <- [0xFA000005,0x58ECA628];
gSurfaceAddress <- [0xA2000005,0xB40E3328];
gGapAddress <- [0x26000005,0xB32A4F28];
gLightPin <- 11;

local currentValues = {
  "zLight":0,
  "zAmbient":0,
  "zSurface":0,
  "zGap":0,
  "gLight":0,
  "gAmbient":0,
  "gSurface":0,
  "gGap":0,
  "impTemp":0
}

const OnTemp = 68; //Temp in Fahrenheit that Lights should turn on.
const OffTemp = 72; //Temp in Fahrenheit that Lights should turn off.

const sleepTime = 60;

owTripletDirection <- 1;
owTripletFirstBit <- 0;
owTripletSecondBit <- 0;
owLastDevice <- 0;
owLastDiscrepancy <- 0;
owDeviceAddress <- [0,0];

function loop() {
    currentValues.zAmbient = OWReadTemperature(zAmbientAddress);
    currentValues.zSurface = OWReadTemperature(zSurfaceAddress);
    currentValues.zGap = OWReadTemperature(zGapAddress);
    if ((currentValues.zAmbient < OnTemp) && (currentValues.zLight == 0)) {
        currentValues.zLight = switchRelay(zLightPin, 1);
    } else if ((currentValues.zAmbient > OffTemp) && (currentValues.zLight == 1)) {
        currentValues.zLight = switchRelay(zLightPin, 0);
    }

    currentValues.gAmbient = OWReadTemperature(gAmbientAddress);
    currentValues.gSurface = OWReadTemperature(gSurfaceAddress);
    currentValues.gGap = OWReadTemperature(gGapAddress);
    if ((currentValues.gAmbient < OnTemp) && (currentValues.gLight == 0)) {
        currentValues.gLight = switchRelay(gLightPin, 1);
    } else if ((currentValues.gAmbient > OffTemp) && (currentValues.gLight == 1)) {
        currentValues.gLight = switchRelay(gLightPin, 0);
    }

    currentValues.impTemp = impReadTemp();

    agent.send("sendValues", currentValues);

    imp.wakeup((sleepTime-7), loop);
}

// Relay Switch Function
function switchRelay(pin, state) {
  switch (state) {
    case 0:
      {
        ioexp_setpin(pin,1);
        return 0;
      }
    case 1:
      {
        ioexp_setpin(pin,0);
        return 1;
      }
  }
}

// IO Expander Functions
function ioexp_read(addr) {
 local result = i2c.read(i2c_ioexp, format("%c", addr), 1);
 if (result == null) {
 server.log("i2c read fail");
 return -1;
 } else return result[0];
}

function ioexp_write(addr, data) {
 i2c.write(i2c_ioexp, format("%c%c",addr, data));
}

function ioexp_writebit(addr, bitn, level) {
 local reg = ioexp_read(addr);
 reg = (level==0)?(reg&~(1<<bitn)) : (reg | (1<<bitn));
 ioexp_write(addr, reg)
}

function ioexp_modify_write(addr, data, mask) {
 local reg = ioexp_read(addr);
 reg = (reg & ~mask) | (data & mask);
 ioexp_write(addr, reg);
}

function ioexp_setpin(gpio, level) {
 ioexp_writebit(gpio>=8?0x10:0x11, gpio&7, level?1:0);
}

function ioexp_setdir(gpio, output) {
 ioexp_writebit(gpio>=8?0x0e:0x0f, gpio&7, output?0:1);
}

function ioexp_setpullup(gpio, enable) {
 ioexp_writebit(gpio>=8?0x06:0x07, gpio&7, enable);
}

function ioexp_setlowdrive(gpio, enable) {
 ioexp_writebit(gpio>=8?0x04:0x05, gpio&7, enable);
}

function ioexp_setirqmask(gpio, enable) {
 ioexp_writebit(gpio>=8?0x12:0x13, gpio&7, enable);
}

function ioexp_setirqedge(gpio, rising, falling) {
 local addr = 0x17 - (gpio>>2);
 local mask = 0x03 << ((gpio&3)<<1);
 local data = (2*falling + rising) << ((gpio&3)<<1);
 ioexp_modify_write(addr, data, mask);
}

function ioexp_clearirq(gpio) {
 ioexp_writebit(gpio>=8?0x18:0x19, gpio&7, 1);
}

function ioexp_readpin(gpio) {
 return (ioexp_read(gpio>=8?0x10:0x11)&(1<<(gpio&7)))?1:0;
}

// Imp Hannah Temp Sensor Function
function impReadTemp() {
    local result = i2c.read(i2c_temp, "\x00", 2);
    if (result == null) {
        server.log("I2C Read Fail: Result == Null");
        return -1;
    }else if(result[0] == null){
        server.log("I2C Read Fail: Result[0] == Null");
        return -1;
    }else if(result[1] == null){
        server.log("I2C Read Fail: Result[1] == Null");
        return -1;
    }
    local celsius = ((result[0] << 4) + (result[1] >> 4)) * 0.0625;
    if (celsius > 128) celsius -= 256;
    celsius = celsius + cal_tmp102;

    local fahrenheit = celsius * 1.8 + 32.0;
    return fahrenheit;
}

// 1wire Bus Functions
function DS2482Reset() {
    server.log(format("Function: Resetting DS2482 at %i (%#x)", i2c_owbus, i2c_owbus));
    i2c.write(i2c_owbus, "\xF0"); //reset DS2482
}

function OWGetStatus(returnVal, reset) {
    local loopcount = 0;
    while (true) {
        loopcount++;
        local data = i2c.read(i2c_owbus, "", 1);
        if(data == null) {
            server.log("I2C read status failed");
            return returnVal;
        } else {
            if (data[0] & 0x01) {
                if (loopcount > 100) {
                    server.log("1wire busy for too long");
                    return returnVal;
                }
                imp.sleep(0.001);
            } else if (reset) {
                if (data[0] & 0x04) {
                    server.log("1wire short detected");
                    return returnVal;
                }
                if (data[0] & 0x02) {
                    break;
                } else {
                    server.log("No 1wire devices found");
                    return returnVal;
                }
            } else {
                break;
            }
        }
    }
}

function OWReset() {
    local e = i2c.write(i2c_owbus, "\xB4"); //1-wire reset
    if (e != 0) { //Device failed to acknowledge reset
        server.log("I2C Reset Failed");
        return 0;
    }
    local status = OWGetStatus(0,1);
    if (status != null) {
        return status;
    }
    return 1;
}

function OWWriteByte(byte) {
    local e = i2c.write(i2c_owbus, "\xE1\xF0"); //set read pointer (E1) to the status register (F0)
    if (e != 0) { //Device failed to acknowledge
        server.log("I2C Write Failed");
        return -1;
    }
    local status = OWGetStatus(-1,0);
    if (status != null) {
        return status;
    }
    local e = i2c.write(i2c_owbus, format("%c%c", 0xA5, byte)); //set write byte command (A5) and send data (byte)
    if (e != 0) { //Device failed to acknowledge
        server.log(format("I2C Write Byte Failed. Data: %#.2X", byte));
        return -1;
    }
    local status = OWGetStatus(-1,0);
    if (status != null) {
        return status;
    }
    return 0;
}

function OWReadByte() {
    //See if the 1wire bus is idle
    //server.log("Function: Read Byte from One-Wire");
    local e = i2c.write(i2c_owbus, "\xE1\xF0"); //set read pointer (E1) to the status register (F0)
    if (e != 0) { //Device failed to acknowledge
        server.log("I2C Write Failed");
        return -1;
    }
    local status = OWGetStatus(-1,0);
    if (status != null) {
        return status;
    }

    //Send a read command, then wait for the 1wire bus to finish
    local e = i2c.write(i2c_owbus, "\x96"); //send read byte command (96)
    if (e != 0) { //Device failed to acknowledge
        server.log("I2C Write read-request Failed");
        return -1;
    }
    local status = OWGetStatus(-1,0);
    if (status != null) {
        return status;
    }

    //Go get the data byte
    local e = i2c.write(i2c_owbus, "\xE1\xE1"); //set read pointer (E1) to the read data register (E1)
    if (e != 0) { //Device failed to acknowledge
        server.log("I2C Write Failed");
        return -1;
    }
    local data = i2c.read(i2c_owbus, "", 1); //Read the data register
    if(data == null) {
        server.log("I2C Read Status Failed");
        return -1;
    } else {
        //server.log(format("Read Data Byte = %d", data[0]));
    }
    //server.log("One-Wire Read Byte complete");
    return data[0];
}

function OWTriplet() {
    if (owTripletDirection > 0) owTripletDirection = "\xFF";

    local e = i2c.write(i2c_owbus, "\x78" + owTripletDirection); //send 1-wire triplet and direction
    if (e != 0) { //Device failed to acknowledge message
        server.log("OneWire Triplet Failed");
        return 0;
    }

    local loopcount = 0;
    while (true) {
        loopcount++;
        local data = i2c.read(i2c_owbus, "", 1); //Read the status register
        if(data == null) {
            server.log("I2C Read Status Failed");
            return -1;
        } else {
            if (data[0] & 0x01) { // 1-Wire Busy bit
                if (loopcount > 100) {
                    server.log("One-Wire busy for too long");
                    return -1;
                }
                imp.sleep(0.001); //Wait, try again
            } else {
                if (data[0] & 0x20) {
                    owTripletFirstBit = 1;
                } else {
                    owTripletFirstBit = 0;
                }
                if (data[0] & 0x40) {
                    owTripletSecondBit = 1;
                } else {
                    owTripletSecondBit = 0;
                }
                if (data[0] & 0x80) {
                    owTripletDirection = 1;
                } else {
                    owTripletDirection = 0;
                }
                return 1;
            }
        }
    }
}

function OWSearch() {
    local bitNumber = 1;
    local lastZero = 0;
    local deviceAddress4ByteIndex = 1; //Fill last 4 bytes first, data from onewire comes LSB first.
    local deviceAddress4ByteMask = 1;

    if (owLastDevice) {
        owLastDevice = 0;
        owLastDiscrepancy = 0;
        owDeviceAddress[0] = 0xFFFFFFFF;
        owDeviceAddress[1] = 0xFFFFFFFF;
    }

    if (!owLastDevice) { //if the last call was not the last one
        if (!OWReset()) { //if there are no parts on 1-wire, return false
            owLastDiscrepancy = 0;
            return 0;
        }
        OWWriteByte(0xF0); //Issue the Search ROM command

        do { // loop to do the search
            if (bitNumber < owLastDiscrepancy) {
                if (owDeviceAddress[deviceAddress4ByteIndex] & deviceAddress4ByteMask) {
                    owTripletDirection = 1;
                } else {
                    owTripletDirection = 0;
                }
            } else if (bitNumber == owLastDiscrepancy) { //if equal to last pick 1, if not pick 0
                owTripletDirection = 1;
            } else {
                owTripletDirection = 0;
            }

            if (!OWTriplet()) return 0;

            if (owTripletFirstBit==0 && owTripletSecondBit==0 && owTripletDirection==0) lastZero = bitNumber;

            if (owTripletFirstBit==1 && owTripletSecondBit==1) break;

            if (owTripletDirection==1) {
                owDeviceAddress[deviceAddress4ByteIndex] = owDeviceAddress[deviceAddress4ByteIndex] | deviceAddress4ByteMask;
            } else {
                owDeviceAddress[deviceAddress4ByteIndex] = owDeviceAddress[deviceAddress4ByteIndex] & ~deviceAddress4ByteMask;
            }

            bitNumber++; //increment the byte counter bit number
            deviceAddress4ByteMask = deviceAddress4ByteMask << 1; //shift the bit mask left

            if (deviceAddress4ByteMask == 0) { //if the mask is 0 then go to other address block and reset mask to first bit
                deviceAddress4ByteIndex--;
                deviceAddress4ByteMask = 1;
            }
        } while (deviceAddress4ByteIndex > -1);

        if (bitNumber == 65) { //if the search was successful then
            owLastDiscrepancy = lastZero;
            if (owLastDiscrepancy==0) {
                owLastDevice = 1;
            } else {
                owLastDevice = 0;
            }
            if (OWCheckCRC()) {
                return 1;
            } else {
                server.log("OneWire device address CRC check failed");
                return 1;
            }

        }
    }

    server.log("No One-Wire Devices Found, Resetting Search");
    owLastDiscrepancy = 0;
    owLastDevice = 0;
    return 0;
}

function OWCheckCRC() {
    local crc = 0;
    local j;
    local da32bit = owDeviceAddress[1];
    for(j=0; j<4; j++) { //All four bytes
        crc = AddCRC(da32bit & 0xFF, crc);
        //server.log(format("CRC = %.2X", crc));
        da32bit = da32bit >> 8; //Shift right 8 bits
    }
    da32bit = owDeviceAddress[0];
    for(j=0; j<3; j++) { //only three bytes
        crc = AddCRC(da32bit & 0xFF, crc);
        //server.log(format("CRC = %.2X", crc));
        da32bit = da32bit >> 8; //Shift right 8 bits
    }
    //server.log(format("CRC = %#.2X", crc));
    //server.log(format("DA  = %#.2X", da32bit));
    if ((da32bit & 0xFF) == crc) { //last byte of address should match CRC of other 7 bytes
        //server.log("CRC Passed");
        return 1; //match
    }
    return 0; //bad CRC
}

function AddCRC(inbyte, crc) {
    local j;
    for(j=0; j<8; j++) {
        local mix = (crc ^ inbyte) & 0x01;
        crc = crc >> 1;
        if (mix) crc = crc ^ 0x8C;
        inbyte = inbyte >> 1;
    }
    return crc;
}

function OWSelect(selectAddress) {
    OWWriteByte(0x55); //Issue the Match ROM command
    local i;
    local j;
    if (selectAddress) {
        for(i=1; i>=0; i--) {
            local da32bit = selectAddress[i];
            for(j=0; j<4; j++) {
                OWWriteByte(da32bit & 0xFF); //Send lowest byte
                da32bit = da32bit >> 8; //Shift right 8 bits
            }
        }
    } else {
        for(i=1; i>=0; i--) {
            local da32bit = owDeviceAddress[i];
            for(j=0; j<4; j++) {
                OWWriteByte(da32bit & 0xFF); //Send lowest byte
                da32bit = da32bit >> 8; //Shift right 8 bits
            }
        }
    }

}

function OWReadTemperature(selectedDeviceAddress) {

    if (OWSearch()) {
        if (OWReset()) {
            OWSelect(selectedDeviceAddress);
            OWWriteByte(0x44);
            imp.sleep(1);
            if (OWReset()) {
                OWSelect(selectedDeviceAddress);
                OWWriteByte(0xBE);
            }
        }
    }

    local data = [0,0,0,0, 0];
    local i;
    for(i=0; i<5; i++) { //we only need 5 of the bytes
        data[i] = OWReadByte();
    }
    local raw = (data[1] << 8) | data[0];
    local SignBit = raw & 0x8000;  // test most significant bit
    if (SignBit) {raw = (raw ^ 0xffff) + 1;} // negative, 2's compliment
    local cfg = data[4] & 0x60;
    if (cfg == 0x60) {
        //server.log("12 bit resolution"); //750 ms conversion time
    } else if (cfg == 0x40) {
        //server.log("11 bit resolution"); //375 ms
        raw = raw << 1;
    } else if (cfg == 0x20) {
        //server.log("10 bit resolution"); //187.5 ms
        raw = raw << 2;
    } else { //if (cfg == 0x00)
        //server.log("9 bit resolution"); //93.75 ms
        raw = raw << 3;
    }
    local celsius = raw / 16.0;
    if (SignBit) {celsius *= -1;}

    local fahrenheit = celsius * 1.8 + 32.0;
    return fahrenheit;
}

function ReportRSSI() {
  local rssi = imp.rssi();
  if (rssi < -87) {
    server.log("Signal Strength: " + rssi + "dBm (0 bars)");
  }
  else if (rssi < -82) {
    server.log("Signal Strength: " + rssi + "dBm (1 bar)");
  }
  else if (rssi < -77) {
    server.log("Signal Strength: " + rssi + "dBm (2 bars)");
  }
  else if (rssi < -72) {
    server.log("Signal Strength: " + rssi + "dBm (3 bars)");
  }
  else if (rssi < -67) {
    server.log("Signal Strength: " + rssi + "dBm (4 bars)");
  }
  else {
    server.log("Signal Strength: " + rssi + "dBm (5 bars)");
  }
}

// Enable Spare 11 for Relay
ioexp_setdir(11,1);
ioexp_setlowdrive(11,1);
ioexp_setpin(11,1);

// Enable Spare 11 for Relay
ioexp_setdir(12,1);
ioexp_setlowdrive(12,1);
ioexp_setpin(12,1);

ReportRSSI();
DS2482Reset();
loop();
