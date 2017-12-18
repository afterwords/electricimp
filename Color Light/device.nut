#require "LIS3DH.class.nut:1.0.2"
//I2C Addresses Rev3
const i2c_ioexp = 0x7C;
const i2c_temp = 0x92;
const i2c_als = 0xE8;
const i2c_accel = 0x30;

//----------------------------------------
//-- Configure I2C
//----------------------------------------
// Create and enable the sensor
i2c <- hardware.i2c89;
i2c.configure(CLOCK_SPEED_400_KHZ);
accel <- LIS3DH(i2c, i2c_accel);
accel.setDataRate(100);

//----------------------------------------
//-- Constants
//----------------------------------------
local led_r = 0;
local led_g = 0;
local led_b = 0;

local currMode = "offMode";
const brightness = 1;

//----------------------------------------
//-- IO Expander Functions
//----------------------------------------
local function ioexp_read(addr) {
 local result = i2c.read(i2c_ioexp, format("%c", addr), 1);
 if (result == null) {
 server.log("i2c read fail");
 return -1;
 } else return result[0];
}

local function ioexp_write(addr, data) {
 i2c.write(i2c_ioexp, format("%c%c",addr, data));
}

local function ioexp_writebit(addr, bitn, level) {
 // read modify write
 local reg = ioexp_read(addr);
 reg = (level==0)?(reg&~(1<<bitn)) : (reg | (1<<bitn));
 ioexp_write(addr, reg)
}

local function ioexp_modify_write(addr, data, mask) {
 local reg = ioexp_read(addr);
 reg = (reg & ~mask) | (data & mask);
 ioexp_write(addr, reg);
}

local function ioexp_setpin(gpio, level) {
 ioexp_writebit(gpio>=8?0x10:0x11, gpio&7, level?1:0);
}

local function ioexp_setdir(gpio, output) {
 ioexp_writebit(gpio>=8?0x0e:0x0f, gpio&7, output?0:1);
}

local function ioexp_setpullup(gpio, enable) {
 ioexp_writebit(gpio>=8?0x06:0x07, gpio&7, enable);
}

local function ioexp_setirqmask(gpio, enable) {
 ioexp_writebit(gpio>=8?0x12:0x13, gpio&7, enable);
}

local function ioexp_setirqedge(gpio, rising, falling) {
 local addr = 0x17 - (gpio>>2);
 local mask = 0x03 << ((gpio&3)<<1);
 local data = (2*falling + rising) << ((gpio&3)<<1);
 ioexp_modify_write(addr, data, mask);
}

local function ioexp_clearirq(gpio) {
 ioexp_writebit(gpio>=8?0x18:0x19, gpio&7, 1);
}

local function ioexp_readpin(gpio) {
 return (ioexp_read(gpio>=8?0x10:0x11)&(1<<(gpio&7)))?1:0;
}

local function ioexp_setled(gpio, led) {
 ioexp_writebit(gpio>=8?0x20:0x21, gpio&7, led);
}

local function ioexp_update_leds(r,g,b) {
 if(r != null)
 led_r = r;
 if(g != null)
 led_g = g;
 if(b != null)
 led_b = b;
 ioexp_write(0x3b, led_g);
 ioexp_write(0x40, led_b);
 ioexp_write(0x45, led_r);
}

//----------------------------------------
//-- Main App
//----------------------------------------
function getTemperature() {
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
    local t = ((result[0] << 4) + (result[1] >> 4)) * 0.0625;
    if (t > 128) t -= 256;
    return t;
}

function switchMode(button, currMode) {
  ioexp_update_leds(0,0,0);
  switch (currMode) {
    case "accelMode":
      {
        return "potMode";
        break;
      }
    case "potMode":
      {
        return "tempMode";
        break;
      }
    case "tempMode":
      {
        return "offMode";
        break;
      }
    case "offMode":
      {
        return "accelMode";
        break;
      }
  }
}

function accelLED(brightness) {
  //local mag = (hardware.pin2.read());
  local val = accel.getAccel()
  //server.log(format("Acceleration (G): (%0.2f, %0.2f, %0.2f)", val.x, val.y, val.z));/*
  led_r = math.abs(val.x)*10*brightness;
  led_g = math.abs(val.y)*10*brightness;
  led_b = math.abs(val.z-1)*10*brightness;
  ioexp_update_leds(led_r,led_g,led_b);
}

function potLED(brightness) {
  local pot = (hardware.pin2.read()/65535.0);
  pot = pot * 10;
  local low = 10 - pot;
  low = low * brightness;
  local high = pot;
  high = high * brightness;
  led_r = low;
  led_g = high;
  ioexp_update_leds(led_r,led_g,led_b);
}

function tempLED(brightness) {
  local temp = getTemperature();
  temp = ((temp - 24) / 8) * 10;
  local low = 10 - temp;
  low = low * brightness;
  local high = temp;
  high = high * brightness;
  led_b = low;
  led_r = high;
  ioexp_update_leds(led_r,led_g,led_b);
}

function colorlighton() {
  //Clear all interrupts
  i2c.write(i2c_ioexp, "\x18\xFF");
  i2c.write(i2c_ioexp, "\x19\xFF");

  if (!ioexp_readpin(0)) {
    currMode = switchMode(2, currMode);
    imp.sleep(0.5);
  }

  if (currMode == "accelMode") {
    accelLED(brightness);
  }

  if (currMode == "potMode") {
    potLED(brightness);
  }

  if (currMode == "tempMode") {
    tempLED(brightness);
  }

  if (currMode == "offMode") {

  }

  imp.wakeup(0.01, colorlighton);
}

//LED Driver Enable
ioexp_modify_write(0x01, 0xE0, 0xFF);
ioexp_modify_write(0x0f, 0xE0, 0x00);
ioexp_modify_write(0x0b, 0xE0, 0xFF);
ioexp_modify_write(0x21, 0xE0, 0xFF);
ioexp_write(0x1e, 0x50);
ioexp_write(0x1f, 0x10);
ioexp_update_leds(0,0,0);
ioexp_setpin(5, 0);
ioexp_setpin(6, 0);
ioexp_setpin(7, 0);

// Enable Servo Power Off
ioexp_setdir(10, 1);
ioexp_setpin(10, 0);

// Enable Button 1
ioexp_setpullup(0, 1);
ioexp_setirqmask(0, 0);
ioexp_setirqedge(0, 1, 1); // Set for rising and falling

// Enable Button 2
ioexp_setpullup(1, 1);
ioexp_setirqmask(1, 0);
ioexp_setirqedge(1, 1, 1); // Set for rising and falling

// Enable Hall Switch
ioexp_setpullup(2,1);
ioexp_setirqmask(2, 0);
ioexp_setirqedge(2, 1, 1); // Set for rising and falling

// Enable Potentiometer
ioexp_setpin(8, 0);
ioexp_setdir(8, 1);
hardware.pin2.configure(ANALOG_IN);

//Configure Interrupt Pin
hardware.pin1.configure(DIGITAL_IN);

colorlighton();
