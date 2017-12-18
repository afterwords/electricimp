//I2C Addresses Rev3 (different from the previous Rev2!!!)
const i2c_ioexp = 0x7C;
const i2c_temp = 0x92; // this device is new in the Rev3
const i2c_als = 0xE8;
const i2c_accel = 0x30; // this device is new in the Rev3

local currState1 = 0;
local currState2 = 0;

//----------------------------------------
//-- Configure I2C
//----------------------------------------
hardware.configure(I2C_89);
local i2c = hardware.i2c89;

local led_r = 0;
local led_g = 0;
local led_b = 0;

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

local function ioexp_setlowdrive(gpio, enable) {
 ioexp_writebit(gpio>=8?0x04:0x05, gpio&7, enable);
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

function changeState1(currState1) {
  server.log("1:"+currState1);
  switch (currState1) {
    case 0:
      {
        ioexp_update_leds(0,1,0);
        ioexp_setpin(11,0);
        return 1;
        break;
      }
    case 1:
      {
        ioexp_update_leds(1,0,0);
        ioexp_setpin(11,1);
        return 0;
        break;
      }
  }
}

function changeState2(currState2) {
  server.log("2:"+currState2);
  switch (currState2) {
    case 0:
      {
        ioexp_update_leds(0,1,0);
        ioexp_setpin(12,0);
        return 1;
        break;
      }
    case 1:
      {
        ioexp_update_leds(1,0,0);
        ioexp_setpin(12,1);
        return 0;
        break;
      }
  }
}

agent.on("switch1", function(a) {
  local data = "";
  if (a == "1") {               //Pitchfork switches send 0 or 1
      currState1 = changeState1(0);           // Do something at the device
      data = "Switch 1: On";    // Response to Pitchfork
  }
  else if (a == "0") {
      currState1 = changeState1(1);          // Do something at the device
      data = "Switch 1: Off";
  }
  agent.send("switch1", data)
});

agent.on("switch2", function(a) {
  local data = "";
  if (a == "1") {               //Pitchfork switches send 0 or 1
      currState2 = changeState2(0);           // Do something at the device
      data = "Switch 2: On";    // Response to Pitchfork
  }
  else if (a == "0") {
      currState2 = changeState2(1);          // Do something at the device
      data = "Switch 2: Off";
  }
  agent.send("switch2", data)
});

function mainLoop() {
  //Clear all interrupts
  i2c.write(i2c_ioexp, "\x18\xFF");
  i2c.write(i2c_ioexp, "\x19\xFF");

  if (!ioexp_readpin(0)) {
    currState1 = changeState1(currState1);
    imp.sleep(0.5);
  }

  if (!ioexp_readpin(1)) {
    currState2 = changeState2(currState2);
    imp.sleep(0.5);
  }

  imp.wakeup(0.1, mainLoop);
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

// Enable Servo (Power Off)
ioexp_setdir(10,1);
ioexp_setpin(10,0);

// Enable Spare 11 for Relay
ioexp_setdir(11,1);
ioexp_setlowdrive(11,1);
ioexp_setpin(11,1);

// Enable Spare 11 for Relay
ioexp_setdir(12,1);
ioexp_setlowdrive(12,1);
ioexp_setpin(12,1);

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

mainLoop();
