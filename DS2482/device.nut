local i2c = hardware.i2c89;
i2c.configure(CLOCK_SPEED_100_KHZ);
const I2CAddr = 0x36; //Address of DS2482 on I2C bus
owTripletDirection <- 1;
owTripletFirstBit <- 0;
owTripletSecondBit <- 0;
owLastDevice <- 0;
owLastDiscrepancy <- 0;
owDeviceAddress <- [0,0]; //These are each 32 bits long.

//http://datasheets.maximintegrated.com/en/ds/DS2482-100.pdf
//http://datasheets.maximintegrated.com/en/ds/DS18B20.pdf
//http://www.wulfden.org/downloads/datasheets/DS2482_AN3684.pdf

function loop() {
    if (OWSearch()) { //Search found something
        if ((owDeviceAddress[1] & 0xFF) == 0x28) { //Device is a DS18B20
            //server.log("Is a DS18B20");
            if (OWReset()) { //Reset was successful
                OWSelect();
                OWWriteByte(0x44); //start conversion
                imp.sleep(1); //Wait for conversion
                if (OWReset()) { //Reset was successful
                    OWSelect();
                    OWWriteByte(0xBE); //Read Scratchpad
                    OWReadTemperature();
                }
            }
        }
    }
    imp.wakeup(1, loop);
}

function DS2482Reset() {
    server.log(format("Function: Resetting DS2482 at %i (%#x)", I2CAddr, I2CAddr));
    i2c.write(I2CAddr, "\xF0"); //reset DS2482
}
function OWReset() {
    //server.log("Function: I2C Reset");
    local e = i2c.write(I2CAddr, "\xB4"); //1-wire reset
    if (e != 0) { //Device failed to acknowledge reset
        server.log("I2C Reset Failed");
        return 0;
    }
    local loopcount = 0;
    while (true) {
        loopcount++;
        local data = i2c.read(I2CAddr, "", 1); //Read the status register
        if(data == null) {
            server.log("I2C Read Status Failed");
            return 0;
        } else {
            //server.log(format("Read Status Byte = %d", data[0]));
            if (data[0] & 0x01) { // 1-Wire Busy bit
                //server.log("One-Wire bus is busy");
                if (loopcount > 100) {
                    server.log("One-Wire busy too long");
                    return 0;
                }
                imp.sleep(0.001); //Wait, try again
            } else {
                //server.log("One-Wire bus is idle");
                if (data[0] & 0x04) { //Short Detected bit
                    server.log("One-Wire Short Detected");
                    return 0;
                }
                if (data[0] & 0x02) { //Presense-Pulse Detect bit
                   //server.log("One-Wire Devices Found");
                   break;
                } else {
                    server.log("No One-Wire Devices Found");
                    return 0;
                }
            }
        }
    }
    return 1;
}
function OWWriteByte(byte) {
    //server.log("Function: Write Byte to One-Wire");
    local e = i2c.write(I2CAddr, "\xE1\xF0"); //set read pointer (E1) to the status register (F0)
    if (e != 0) { //Device failed to acknowledge
        server.log("I2C Write Failed");
        return -1;
    }
    local loopcount = 0;
    while (true) {
        loopcount++;
        local data = i2c.read(I2CAddr, "", 1); //Read the status register
        if(data == null) {
            server.log("I2C Read Status Failed");
            return -1;
        } else {
            //server.log(format("Read Status Byte = %d", data[0]));
            if (data[0] & 0x01) { // 1-Wire Busy bit
                //server.log("One-Wire bus is busy");
                if (loopcount > 100) {
                    server.log("One-Wire busy for too long");
                    return -1;
                }
                imp.sleep(0.001); //Wait, try again
            } else {
                //server.log("One-Wire bus is idle");
                break;
            }
        }
    }

    //server.log(byte);
    local e = i2c.write(I2CAddr, format("%c%c", 0xA5, byte)); //set write byte command (A5) and send data (byte)
    if (e != 0) { //Device failed to acknowledge
        server.log(format("I2C Write Byte Failed. Data: %#.2X", byte));
        return -1;
    }
    loopcount = 0;
    while (true) {
        loopcount++;
        local data = i2c.read(I2CAddr, "", 1); //Read the status register
        if(data == null) {
            server.log("I2C Read Status Failed");
            return -1;
        } else {
            //server.log(format("Read Status Byte = %d", data[0]));
            if (data[0] & 0x01) { // 1-Wire Busy bit
                //server.log("One-Wire bus is busy");
                if (loopcount > 100) {
                    server.log("One-Wire busy for too long");
                    return -1;
                }
                imp.sleep(0.001); //Wait, try again
            } else {
                //server.log("One-Wire bus is idle");
                break;
            }
        }
    }
    //server.log("One-Wire Write Byte complete");
    return 0;
}
function OWReadByte() {
    //See if the 1wire bus is idle
    //server.log("Function: Read Byte from One-Wire");
    local e = i2c.write(I2CAddr, "\xE1\xF0"); //set read pointer (E1) to the status register (F0)
    if (e != 0) { //Device failed to acknowledge
        server.log("I2C Write Failed");
        return -1;
    }
    local loopcount = 0;
    while (true) {
        loopcount++;
        local data = i2c.read(I2CAddr, "", 1); //Read the status register
        if(data == null) {
            server.log("I2C Read Status Failed");
            return -1;
        } else {
            //server.log(format("Read Status Byte = %d", data[0]));
            if (data[0] & 0x01) { // 1-Wire Busy bit
                //server.log("One-Wire bus is busy");
                if (loopcount > 100) {
                    server.log("One-Wire busy for too long");
                    return -1;
                }
                imp.sleep(0.001); //Wait, try again
            } else {
                //server.log("One-Wire bus is idle");
                break;
            }
        }
    }

    //Send a read command, then wait for the 1wire bus to finish
    local e = i2c.write(I2CAddr, "\x96"); //send read byte command (96)
    if (e != 0) { //Device failed to acknowledge
        server.log("I2C Write read-request Failed");
        return -1;
    }
    local loopcount = 0;
    while (true) {
        loopcount++;
        local data = i2c.read(I2CAddr, "", 1); //Read the status register
        if(data == null) {
            server.log("I2C Read Status Failed");
            return -1;
        } else {
            //server.log(format("Read Status Byte = %d", data[0]));
            if (data[0] & 0x01) { // 1-Wire Busy bit
                //server.log("One-Wire bus is busy");
                if (loopcount > 100) {
                    server.log("One-Wire busy for too long");
                    return -1;
                }
                imp.sleep(0.001); //Wait, try again
            } else {
                //server.log("One-Wire bus is idle");
                break;
            }
        }
    }


    //Go get the data byte
    local e = i2c.write(I2CAddr, "\xE1\xE1"); //set read pointer (E1) to the read data register (E1)
    if (e != 0) { //Device failed to acknowledge
        server.log("I2C Write Failed");
        return -1;
    }
    local data = i2c.read(I2CAddr, "", 1); //Read the data register
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
    //server.log("Function: OneWire Triplet");
    if (owTripletDirection > 0) owTripletDirection = "\xFF";

    local e = i2c.write(I2CAddr, "\x78" + owTripletDirection); //send 1-wire triplet and direction
    if (e != 0) { //Device failed to acknowledge message
        server.log("OneWire Triplet Failed");
        return 0;
    }

    local loopcount = 0;
    while (true) {
        loopcount++;
        local data = i2c.read(I2CAddr, "", 1); //Read the status register
        if(data == null) {
            server.log("I2C Read Status Failed");
            return -1;
        } else {
            //server.log(format("Read Status Byte = %d", data[0]));
            if (data[0] & 0x01) { // 1-Wire Busy bit
                //server.log("One-Wire bus is busy");
                if (loopcount > 100) {
                    server.log("One-Wire busy for too long");
                    return -1;
                }
                imp.sleep(0.001); //Wait, try again
            } else {
                //server.log("One-Wire bus is idle");
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
    //server.log("Function: OneWire Search");
    local bitNumber = 1;
    local lastZero = 0;
    local deviceAddress4ByteIndex = 1; //Fill last 4 bytes first, data from onewire comes LSB first.
    local deviceAddress4ByteMask = 1;

    if (owLastDevice) {
        server.log("OneWire Search Complete");
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

            //if 0 was picked then record its position in lastZero
            if (owTripletFirstBit==0 && owTripletSecondBit==0 && owTripletDirection==0) lastZero = bitNumber;

            //check for no devices on 1-wire
            if (owTripletFirstBit==1 && owTripletSecondBit==1) break;

            //set or clear the bit in the SerialNum byte serial_byte_number with mask
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
            //server.log(format("OneWire Device Address = %.8X%.8X", owDeviceAddress[0], owDeviceAddress[1]));
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
function OWSelect() {
    //server.log("Selecting device");
    OWWriteByte(0x55); //Issue the Match ROM command
    local i;
    local j;
    for(i=1; i>=0; i--) {
        local da32bit = owDeviceAddress[i];
        for(j=0; j<4; j++) {
            //server.log(format("Writing byte: %.2X", da32bit & 0xFF));
            OWWriteByte(da32bit & 0xFF); //Send lowest byte
            da32bit = da32bit >> 8; //Shift right 8 bits
        }
    }
}
function OWReadTemperature() {
    local data = [0,0,0,0, 0];
    local i;
    for(i=0; i<5; i++) { //we only need 5 of the bytes
        data[i] = OWReadByte();
        //server.log(format("read byte: %.2X", data[i]));
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
    //server.log(format("rawtemp= %.4X", raw));

    local celsius = raw / 16.0;
    if (SignBit) {celsius *= -1;}
    //server.log(format("Temperature = %.1f °C", celsius));

    local fahrenheit = celsius * 1.8 + 32.0;
    //server.log(format("Temperature = %.1f °F", fahrenheit));
    server.log(format("OneWire Device %.8X%.8X = %.1f °F", owDeviceAddress[0], owDeviceAddress[1], fahrenheit));
    server.show(format("%.1f °F", fahrenheit));
}

imp.configure("DS18B20-via-DS2482 Example", [], []);
DS2482Reset();
loop();
