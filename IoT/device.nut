const ERR_NO_DEVICE = "The device at I2C address 0x%02x is disabled.";
const ERR_I2C_READ = "I2C Read Failure. Device: 0x%02x Register: 0x%02x";
const ERR_BAD_TIMER = "You have to start %s with an interval and callback";
const ERR_WRONG_DEVICE = "The device at I2C address 0x%02x is not a %s.";
class SX1509 {
    _i2c       = null;
    _addr      = null;
    _callbacks = null;
    _int_pin   = null;
    static BANK_A = {   REGDATA    = 0x11,
                        REGDIR     = 0x0F,
                        REGPULLUP  = 0x07,
                        REGPULLDN  = 0x09,
                        REGINTMASK = 0x13,
                        REGSNSHI   = 0x16,
                        REGSNSLO   = 0x17,
                        REGINTSRC  = 0x19,
                        REGINPDIS  = 0x01,
                        REGOPENDRN = 0x0B,
                        REGLEDDRV  = 0x21,
                        REGCLOCK   = 0x1E,
                        REGMISC    = 0x1F,
                        REGRESET   = 0x7D}
    static BANK_B = {   REGDATA    = 0x10,
                        REGDIR     = 0x0E,
                        REGPULLUP  = 0x06,
                        REGPULLDN  = 0x08,
                        REGINTMASK = 0x12,
                        REGSNSHI   = 0x14,
                        REGSNSLO   = 0x15,
                        REGINTSRC  = 0x18,
                        REGINPDIS  = 0x00,
                        REGOPENDRN = 0x0A,
                        REGLEDDRV  = 0x20,
                        REGCLOCK   = 0x1E,
                        REGMISC    = 0x1F,
                        REGRESET   = 0x7D}

    constructor(i2c, address, int_pin){
        _i2c  = i2c;
        _addr = address;
        _callbacks = [];
        _callbacks.resize(16, null);
        _int_pin = int_pin;

        reset();
        clearAllIrqs();
    }
    function readReg(register) {
        local data = _i2c.read(_addr, format("%c", register), 1);
        if (data == null) {
            server.error(format(ERR_I2C_READ, _addr, register));
            return -1;
        }
        return data[0];
    }
    function writeReg(register, data) {
        _i2c.write(_addr, format("%c%c", register, data));
        // server.log(format("Setting device 0x%02X register 0x%02X to 0x%02X", _addr, register, data));
    }
    function writeBit(register, bitn, level) {
        local value = readReg(register);
        value = (level == 0)?(value & ~(1<<bitn)):(value | (1<<bitn));
        writeReg(register, value);
    }
    function writeMasked(register, data, mask) {
        local value = readReg(register);
        value = (value & ~mask) | (data & mask);
        writeReg(register, value);
    }
    function setPin(gpio, level) {
        writeBit(bank(gpio).REGDATA, gpio % 8, level ? 1 : 0);
    }
    function setDir(gpio, output) {
        writeBit(bank(gpio).REGDIR, gpio % 8, output ? 0 : 1);
    }
    function setInputBuffer(gpio, enable) {
        writeBit(bank(gpio).REGINPDIS, gpio % 8, enable ? 0 : 1);
    }
    function setOpenDrain(gpio, enable) {
        writeBit(bank(gpio).REGOPENDRN, gpio % 8, enable ? 1 : 0);
    }
    function setPullUp(gpio, enable) {
        writeBit(bank(gpio).REGPULLUP, gpio % 8, enable ? 1 : 0);
    }
    function setPullDn(gpio, enable) {
        writeBit(bank(gpio).REGPULLDN, gpio % 8, enable ? 1 : 0);
    }
    function setIrqMask(gpio, enable) {
        writeBit(bank(gpio).REGINTMASK, gpio % 8, enable ? 0 : 1);
    }
    function clearIrq(gpio) {
        writeBit(bank(gpio).REGINTMASK, gpio % 8, 1);
    }
    function getPin(gpio) {
        return ((readReg(bank(gpio).REGDATA) & (1<<(gpio%8))) ? 1 : 0);
    }
    function reboot() {
        writeReg(bank(0).REGRESET, 0x12);
        writeReg(bank(0).REGRESET, 0x34);
    }
    function setCallback(gpio, _callback) {
        _callbacks[gpio] = _callback;
        hardware.pin1.configure(DIGITAL_IN_PULLUP, fire_callback.bindenv(this));
    }
    function fire_callback() {
        local irq = getIrq();
        clearAllIrqs();
        for (local i = 0; i < 16; i++){
            if ( (irq & (1 << i)) && (typeof _callbacks[i] == "function")){
                _callbacks[i](getPin(i));
            }
        }
    }
    function reset(){
        writeReg(BANK_A.REGDIR, 0xFF);
        writeReg(BANK_A.REGDATA, 0xFF);
        writeReg(BANK_A.REGPULLUP, 0x00);
        writeReg(BANK_A.REGPULLDN, 0x00);
        writeReg(BANK_A.REGINTMASK, 0xFF);
        writeReg(BANK_A.REGSNSHI, 0x00);
        writeReg(BANK_A.REGSNSLO, 0x00);
        writeReg(BANK_B.REGDIR, 0xFF);
        writeReg(BANK_B.REGDATA, 0xFF);
        writeReg(BANK_B.REGPULLUP, 0x00);
        writeReg(BANK_B.REGPULLDN, 0x00);
        writeReg(BANK_A.REGINTMASK, 0xFF);
        writeReg(BANK_B.REGSNSHI, 0x00);
        writeReg(BANK_B.REGSNSLO, 0x00);
    }
    function bank(gpio){
        return (gpio > 7) ? BANK_B : BANK_A;
    }
    function setIrqEdges( gpio, rising, falling) {
        local bank = bank(gpio);
        gpio = gpio % 8;
        local mask = 0x03 << ((gpio & 3) << 1);
        local data = (2*falling + rising) << ((gpio & 3) << 1);
        writeMasked(gpio >= 4 ? bank.REGSNSHI : bank.REGSNSLO, data, mask);
    }
    function clearAllIrqs() {
        writeReg(BANK_A.REGINTSRC,0xff);
        writeReg(BANK_B.REGINTSRC,0xff);
    }
    function getIrq(){
        return ((readReg(BANK_B.REGINTSRC) & 0xFF) << 8) | (readReg(BANK_A.REGINTSRC) & 0xFF);
    }
    function setClock(gpio, enable) {
        writeReg(bank(gpio).REGCLOCK, enable ? 0x50 : 0x00); // 2mhz internal oscillator
    }
    function setLEDDriver(gpio, enable) {
        writeBit(bank(gpio).REGLEDDRV, gpio & 7, enable ? 1 : 0);
        writeReg(bank(gpio).REGMISC, 0x70); // Set clock to 2mhz / (2 ^ (1-1)) = 2mhz, use linear fading
    }
    function setTimeOn(gpio, value) {
        writeReg(gpio<4 ? 0x29+gpio*3 : 0x35+(gpio-4)*5, value)
    }
    function setIntensityOn(gpio, value) {
        writeReg(gpio<4 ? 0x2A+gpio*3 : 0x36+(gpio-4)*5, value)
    }
    function setOff(gpio, value) {
        writeReg(gpio<4 ? 0x2B+gpio*3 : 0x37+(gpio-4)*5, value)
    }
    function setRiseTime(gpio, value) {
        if (gpio % 8 < 4) return; // Can't do all pins
        writeReg(gpio<12 ? 0x38+(gpio-4)*5 : 0x58+(gpio-12)*5, value)
    }
    function setFallTime(gpio, value) {
        if (gpio % 8 < 4) return; // Can't do all pins
        writeReg(gpio<12 ? 0x39+(gpio-4)*5 : 0x59+(gpio-12)*5, value)
    }
}
class ExpGPIO {
    _expander = null;  //Instance of an Expander class
    _gpio     = null;  //Pin number of this GPIO pin
    _mode     = null;  //The mode configured for this pin
    static LED_OUT = 1000001;
    constructor(expander, gpio) {
        _expander = expander;
        _gpio     = gpio;
    }
    function configure(mode, param = null) {
        _mode = mode;
        if (mode == DIGITAL_OUT) {
            _expander.setDir(_gpio,1);
            _expander.setPullUp(_gpio,0);
            if(param != null) {
                _expander.setPin(_gpio, param);
            } else {
                _expander.setPin(_gpio, 0);
            }
            return this;
        } else if (mode == ExpGPIO.LED_OUT) {
            _expander.setPullUp(_gpio, 0);
            _expander.setInputBuffer(_gpio, 0);
            _expander.setOpenDrain(_gpio, 1);
            _expander.setDir(_gpio, 1);
            _expander.setClock(_gpio, 1);
            _expander.setLEDDriver(_gpio, 1);
            _expander.setTimeOn(_gpio, 0);
            _expander.setOff(_gpio, 0);
            _expander.setRiseTime(_gpio, 0);
            _expander.setFallTime(_gpio, 0);
            _expander.setIntensityOn(_gpio, param > 0 ? param : 0);
            _expander.setPin(_gpio, param > 0 ? 0 : 1);
            return this;
        } else if (mode == DIGITAL_IN) {
            _expander.setDir(_gpio,0);
            _expander.setPullUp(_gpio,0);
        } else if (mode == DIGITAL_IN_PULLUP) {
            _expander.setDir(_gpio,0);
            _expander.setPullUp(_gpio,1);
        }
        if (typeof param == "function") {
            _expander.setIrqMask(_gpio,1);
            _expander.setIrqEdges(_gpio,1,1);
            _expander.setCallback(_gpio, param);
        } else {
            _expander.setIrqMask(_gpio,0);
            _expander.setIrqEdges(_gpio,0,0);
            _expander.setCallback(_gpio,null);
        }
        return this;
    }
    function read() {
        return _expander.getPin(_gpio);
    }
    function write(state) {
        _expander.setPin(_gpio,state);
    }
    function setIntensity(intensity) {
        _expander.setIntensityOn(_gpio,intensity);
    }
    function blink(rampup, rampdown, intensityon, intensityoff = 0, fade=true) {
        rampup = (rampup > 0x1F ? 0x1F : rampup);
        rampdown = (rampdown > 0x1F ? 0x1F : rampdown);
        intensityon = intensityon & 0xFF;
        intensityoff = (intensityoff > 0x07 ? 0x07 : intensityoff);
        _expander.setTimeOn(_gpio, rampup);
        _expander.setOff(_gpio, rampdown << 3 | intensityoff);
        _expander.setRiseTime(_gpio, fade?5:0);
        _expander.setFallTime(_gpio, fade?5:0);
        _expander.setIntensityOn(_gpio, intensityon);
        _expander.setPin(_gpio, intensityon>0 ? 0 : 1)
    }
    function fade(on, risetime = 5, falltime = 5) {
        _expander.setRiseTime(_gpio, on ? risetime : 0);
        _expander.setFallTime(_gpio, on ? falltime : 0);
    }
}
class RGBLED {
    _expander = null;
    ledR = null;
    ledG = null;
    ledB = null;
    constructor(expander, gpioRed, gpioGreen, gpioBlue) {
        _expander = expander;
        ledR = ExpGPIO(_expander, gpioRed).configure(ExpGPIO.LED_OUT);
        ledG = ExpGPIO(_expander, gpioGreen).configure(ExpGPIO.LED_OUT);
        ledB = ExpGPIO(_expander, gpioBlue).configure(ExpGPIO.LED_OUT);
    }
    function read() {
        return {r = (256 - ledR.read() * 256).tointeger(),
                g = (256 - ledG.read() * 256).tointeger(),
                b = (256 - ledB.read() * 256).tointeger()};
    }
    function set(r, g, b, fade=false) {
        ledR.blink(0, 0, r.tointeger(), 0, fade);
        ledG.blink(0, 0, g.tointeger(), 0, fade);
        ledB.blink(0, 0, b.tointeger(), 0, fade);
    }
    function blink(r, g, b, fade=true, timeon=1, timeoff=1) {
        ledR.write(1); ledG.write(1); ledB.write(1);
        ledR.blink(timeon.tointeger(), timeoff.tointeger(), r.tointeger(), 0, fade);
        ledG.blink(timeon.tointeger(), timeoff.tointeger(), g.tointeger(), 0, fade);
        ledB.blink(timeon.tointeger(), timeoff.tointeger(), b.tointeger(), 0, fade);
    }
    function test(r, g, b, fade=true, timeon=1, timeoff=1) {
        ledR.write(1); ledG.write(1); ledB.write(1);
        ledR.blink(timeon, timeoff, r.tointeger(), 0, fade);
        ledG.blink(timeon, timeoff, g.tointeger(), 0, fade);
        ledB.blink(timeon, timeoff, b.tointeger(), 0, fade);
    }
}
enum CAP_COLOUR { RED, GREEN, BLUE, CLEAR };
class RGBSensor {
    _i2c  = null;
    _addr = null;
    _expander = null;
    _sleep = null;
    _poll_callback = null;
    _poll_interval = null;
    _poll_timer = null;
    static MIN_CAP_COUNT = 0x0; // Min capacitor count
    static MAX_CAP_COUNT = 0xF; // Max capacitor count
    static REG_CAPS = [0x06, 0x07, 0x08, 0x09];
    static MIN_INTEGRATION_SLOTS = 0x000;   // Min integration slots
    static MAX_INTEGRATION_SLOTS = 0xFFF;   // Max integration slots
    static REG_INT_SLOTS         = [0x0a, 0x0c, 0x0e, 0x10];
    static REG_CTRL        = 0x00
    static REG_READ_COLOUR = 0x01;
    static REG_LOW         = [0x40, 0x42, 0x44, 0x46];
    static REG_HI          = [0x41, 0x43, 0x45, 0x47];
    constructor(i2c, address, expander, gpioSleep) {
        _i2c  = i2c;
        _addr = address;
        _expander = expander;
        _sleep = ExpGPIO(_expander, gpioSleep).configure(DIGITAL_OUT, 0);
        initialise();
    }
    function wake() {
        _sleep.write(0);
    }
    function sleep() {
        _sleep.write(1);
    }
    function initialise(caps = 0x0F, timeslots = 0xFF) {
        wake();
        local result1 = _i2c.write(_addr, format("%c%c", REG_CTRL, 0));
        imp.sleep(0.01);
        local result2 = _setRGBCapacitorCounts(caps);
        local result3 = _setRGBIntegrationTimeSlots(timeslots);
        sleep();
        return (result1 == 0) && result2 && result3;
    }
    function _setRGBCapacitorCounts(count)
    {
        for (local capIndex = CAP_COLOUR.RED; capIndex <= CAP_COLOUR.CLEAR; ++capIndex) {
            local thecount = (typeof count == "array") ? count[capIndex] : count;
            if (!_setCapacitorCount(REG_CAPS[capIndex], thecount)) {
                return false;
            }
        }
        return true;
    }
    function _setCapacitorCount(address, count) {
        if (count < MIN_CAP_COUNT) {
            count = MIN_CAP_COUNT;
        } else if (count > MAX_CAP_COUNT) {
            count = MAX_CAP_COUNT;
        }
        return _i2c.write(_addr, format("%c%c", address, count)) == 0;
    }
    function _setRGBIntegrationTimeSlots(value) {
        for (local intIndex = CAP_COLOUR.RED; intIndex <= CAP_COLOUR.CLEAR; ++intIndex) {
            local thevalue = (typeof value == "array") ? value[intIndex] : value;
            if (!_setIntegrationTimeSlot(REG_INT_SLOTS[intIndex], thevalue & 0xff)) {
                return false;
            }
            if (!_setIntegrationTimeSlot(REG_INT_SLOTS[intIndex] + 1, thevalue >> 8)) {
                return false;
            }
        }
        return true;
    }
    function _setIntegrationTimeSlot(address, value) {
        if (value < MIN_INTEGRATION_SLOTS) {
            value = MIN_INTEGRATION_SLOTS;
        } else if (value > MAX_INTEGRATION_SLOTS) {
            value = MAX_INTEGRATION_SLOTS;
        }
        return _i2c.write(_addr, format("%c%c", address, value)) == 0;
    }
    function read() {
        local rgbc = [0, 0, 0 ,0];
        wake();
        if (_i2c.write(_addr, format("%c%c", REG_CTRL, REG_READ_COLOUR)) == 0) {
            local count = 0;
            while (_i2c.read(_addr, format("%c", REG_CTRL), 1)[0] != 0) {
                count++;
            }
            for (local colIndex = CAP_COLOUR.RED; colIndex <= CAP_COLOUR.CLEAR; ++colIndex) {
                rgbc[colIndex] = _i2c.read(_addr,  format("%c", REG_LOW[colIndex]), 1)[0];
            }
            for (local colIndex = CAP_COLOUR.RED; colIndex <= CAP_COLOUR.CLEAR; ++colIndex) {
                rgbc[colIndex] += _i2c.read(_addr,  format("%c", REG_HI[colIndex]), 1)[0] << 8;
            }
        } else {
            server.error("RGBSensor:REG_READ_COLOUR reading failed.")
        }
        sleep();
        return { r = rgbc[0], g = rgbc[1], b = rgbc[2], c = rgbc[3] };
    }
    function poll(interval = null, callback = null) {
        if (interval != null && callback != null) {
            _poll_callback = callback;
            _poll_interval = interval;
            if (_poll_timer) imp.cancelwakeup(_poll_timer);
        } else if (_poll_interval == null || _poll_callback == null) {
            server.error(format(ERR_BAD_TIMER, RGBSensor::poll()))
        }
        _poll_timer = imp.wakeup(_poll_interval, poll.bindenv(this));
        _poll_callback(read())
    }
    function stop() {
        if (_poll_timer) imp.cancelwakeup(_poll_timer);
        _poll_timer = null;
        _poll_interval = null;
        _poll_callback = null;
    }
}
class TempSensor {
    _i2c  = null;
    _addr = null;
    _expander = null;
    _alert = null;
    _alert_callback = null;
    _poll_callback = null;
    _poll_interval = null;
    _poll_timer = null;
    _last_temp = null;
    _running = false;
    _disabled = false;
    static REG_TEMP      = "\x00";
    static REG_CONF      = "\x01";
    static REG_T_LOW     = "\x02";
    static REG_T_HIGH    = "\x03";
    constructor(i2c, address, expander, gpioAlert) {
        _i2c  = i2c;
        _addr = address;
        _expander = expander;
        local id = _i2c.read(_addr, REG_TEMP, 1);
        if (id == null) {
            server.error(format(ERR_WRONG_DEVICE, _addr, "TMP112 temperature sensor"))
            _disabled = true;
        } else {
            _alert = ExpGPIO(_expander, gpioAlert).configure(DIGITAL_IN_PULLUP, _interruptHandler.bindenv(this));
            local conf = _i2c.read(_addr, REG_CONF, 2);
            _i2c.write(_addr, REG_CONF + format("%c%c", conf[0] | 0x01, conf[1]));
        }
    }
    function _interruptHandler(state) {
        if (_alert_callback && state == 0) _alert_callback(read());
    }
    function poll(interval = null, callback = null) {
        if (_disabled) return server.error(format(ERR_NO_DEVICE, _addr));
        if (interval && callback) {
            _poll_interval = interval;
            _poll_callback = callback;
            if (_poll_timer) imp.cancelwakeup(_poll_timer);
        } else if (!_poll_interval || !_poll_callback) {
            server.error(format(ERR_BAD_TIMER, "TempSensor_rev2::poll()"))
            return false;
        }
        local temp = read();
        _poll_timer = imp.wakeup(_poll_interval, poll.bindenv(this))
        if (temp != _last_temp) {
            _poll_callback(temp);
            _last_temp = temp;
        }
    }
    function alert(lo, hi, callback = null) {
        if (_disabled) return server.error(format(ERR_NO_DEVICE, _addr));
        callback = callback ? callback : _poll_callback;
        stop();
        _alert_callback = callback;
        local tlo = deg2int(lo, 0.0625, 12);
        local thi = deg2int(hi, 0.0625, 12);
        _i2c.write(_addr, REG_T_LOW + format("%c%c", (tlo >> 8) & 0xFF, (tlo & 0xFF)));
        _i2c.write(_addr, REG_T_HIGH + format("%c%c", (thi >> 8) & 0xFF, (thi & 0xFF)));
        _i2c.write(_addr, REG_CONF + "\x62\x80"); // Run continuously
        _running = true;
    }
    function stop() {
        if (_disabled) return server.error(format(ERR_NO_DEVICE, _addr));
        if (_poll_timer) imp.cancelwakeup(_poll_timer);
        _poll_timer = null;
        _poll_interval = null;
        _poll_callback = null;
        _alert_callback = null;
        _running = false;
        local conf = _i2c.read(_addr, REG_CONF, 2);
        _i2c.write(_addr, REG_CONF + format("%c%c", conf[0] | 0x01, conf[1]));
    }
    function read() {
        if (_disabled) return server.error(format(ERR_NO_DEVICE, _addr));
        if (!_running) {
            local conf = _i2c.read(_addr, REG_CONF, 2);
            _i2c.write(_addr, REG_CONF + format("%c%c", conf[0] | 0x80, conf[1]));
            while ((_i2c.read(_addr, REG_CONF, 1)[0] & 0x80) == 0x80);
        }
        local result = _i2c.read(_addr, REG_TEMP, 2);
        local temp = (result[0] << 8) + result[1];
        local tempC = int2deg(temp, 0.0625, 12);
        return c2f(tempC,-3);
    }
}
class Potentiometer {
    _expander = null;
    _gpioEnable = null;
    _pinRead = null;
    _poll_callback = null;
    _poll_interval = 0.2;
    _poll_timer = null;
    _last_pot_value = null;
    _min = 0.0;
    _max = 1.0;
    _integer_only = false;
    constructor(expander, gpioEnable, pinRead) {
        _expander = expander;
        _pinRead = pinRead;
        _pinRead.configure(ANALOG_IN);
        _gpioEnable = ExpGPIO(_expander, gpioEnable).configure(DIGITAL_OUT);
    }
    function poll(interval = null, callback = null) {
        if (interval && callback) {
            _poll_interval = interval;
            _poll_callback = callback;
            if (_poll_timer) imp.cancelwakeup(_poll_timer);
        } else if (!_poll_interval || !_poll_callback) {
            server.error(format(ERR_BAD_TIMER, "TempSensor_rev2::poll()"))
            return false;
        }
        _poll_timer = imp.wakeup(_poll_interval, poll.bindenv(this))
        local new_pot_value = read();
        if (_last_pot_value != new_pot_value) {
            _last_pot_value = new_pot_value;
            _poll_callback(new_pot_value);
        }
    }
    function stop() {
        if (_poll_timer) imp.cancelwakeup(_poll_timer);
        _poll_timer = null;
        _poll_interval = null;
        _poll_callback = null;
    }
    function setenabled(enable = true) {
        _gpioEnable.write(enable ? 0 : 1);
        if (_checkpot_timer) {
            imp.cancelwakeup(_checkpot_timer);
        }
        if (enable && _callback) {
            _checkpot_timer = imp.wakeup(0, checkpot.bindenv(this));
        }
    }
    function enabled() {
        return _gpioEnable.read() == 0;
    }
    function scale(min, max, integer_only = false) {
        _min = min;
        _max = max;
        _integer_only = integer_only;
    }
    function read() {
        local f = 0.0 + _min + (_pinRead.read() * (_max - _min) / 65423.0);
        if (_integer_only) return f.tointeger();
        else               return format("%0.03f", f).tofloat();
    }
}
class Servo {
    _expander = null;
    _gpioEnable = null;
    _pinWrite = null;
    _last_write = 0.0;
    _min = 0.0;
    _max = 1.0;
    constructor(expander, gpioEnable, pinWrite, period=0.02, dutycycle=0.5) {
        _expander = expander;
        _pinWrite = pinWrite;
        _pinWrite.configure(PWM_OUT, period, dutycycle);
        _last_write = dutycycle;
        if (gpioEnable != null) {
            _gpioEnable = ExpGPIO(_expander, gpioEnable).configure(DIGITAL_OUT, 1);
        }
    }
    function setenabled(enable = true) {
        if (_gpioEnable) _gpioEnable.write(enable ? 1 : 0);
    }
    function enabled() {
        return _gpioEnable ? (_gpioEnable.read() == 1) : false;
    }
    function scale(min, max) {
        _min = min;
        _max = max;
    }
    function read() {
        return format("%0.03f", _last_write).tofloat();
    }
    function write(val) {
        if (val <= 0.0) val = 0.0;
        else if (val >= 1.0) val = 1.0;
        _last_write = val.tofloat();

        local f = 0.0 + _min + (_last_write.tofloat() * (_max - _min));
        return _pinWrite.write(f);
    }
}
class Hannah {
    i2c = null;
    ioexp = null;
    pot = null;
    btn1 = null;
    btn2 = null;
    hall = null;
    srv1 = null;
    srv2 = null;
    acc = null;
    led = null;
    light = null;
    temp = null;
    on_pot_changed = null;
    on_btn1_changed = null;
    on_btn2_changed = null;
    on_hall_changed = null;
    on_acc_changed = null;
    on_light_changed = null;
    on_temp_changed = null;
    constructor() {
        i2c = hardware.i2c89;
        i2c.configure(CLOCK_SPEED_400_KHZ);
        ioexp = SX1509(i2c, 0x7C, hardware.pin1);
        pot = Potentiometer(ioexp, 8, hardware.pin2);
        pot.scale(0,100,true);
        pot.poll(0.5, call_callback("on_pot_changed"));
        btn1 = ExpGPIO(ioexp, 0).configure(DIGITAL_IN_PULLUP, call_callback("on_btn1_changed"));
        btn2 = ExpGPIO(ioexp, 1).configure(DIGITAL_IN_PULLUP, call_callback("on_btn2_changed"));
        //hall = ExpGPIO(ioexp, 2).configure(DIGITAL_IN_PULLUP, call_callback("on_hall_changed"));
        light = RGBSensor(i2c, 0xE8, ioexp, 9);
        //light.poll(1, call_callback("on_light_changed"));
        //acc = Accelerometer(i2c, 0x30, ioexp, 3);
        //acc.alert(call_callback("on_acc_changed"));*/
        temp = TempSensor(i2c, 0x92, ioexp, 4);
        temp.poll(5, call_callback("on_temp_changed"));
        srv1 = Servo(ioexp, 10, hardware.pin5);
        srv2 = Servo(ioexp, 10, hardware.pin7);
        led = RGBLED(ioexp, 7, 5, 6);
    }
    function call_callback(callback_name) {
        return function(a=null, b=null, c=null) {
            if ((callback_name in this) && (typeof this[callback_name] == "function")) {
                if (a == null) {
                    this[callback_name]();
                } else if (b == null) {
                    this[callback_name](a);
                } else if (c == null) {
                    this[callback_name](a, b);
                } else {
                    this[callback_name](a, b, c);
                }
            }
        }.bindenv(this)
    }
}
function deg2int(temp, stepsize = 0.0625, left_align_bits = 12) {
    temp = (temp / stepsize.tofloat()).tointeger();
    local mask1 = (0xFFFF << (16 - left_align_bits)) & 0xFFFF;
    local mask2 = mask1 >> (16 - left_align_bits + 1);
    if (temp < 0) temp = -((~temp & mask2) + 1);
    return (temp << (16 - left_align_bits)) & mask1;
}
function int2deg(temp, stepsize = 0.0625, left_align_bits = 12) {
    temp = temp >> (16 - left_align_bits);
    local mask1 = (1 << (left_align_bits - 1));
    local mask2 = 0xFFFF >> (16 - left_align_bits + 1);
    if (temp & mask1) temp = -((~temp & mask2) + 1);
    return temp.tofloat() * stepsize.tofloat();
}
function c2f(temp,adjust,decimal = false){
    local tempC = temp + adjust.tofloat();
    local tempF = (tempC * 1.8) + 32;
    if (decimal) {
      return format("%0.1f",tempF).tofloat();
    } else {
      return tempF.tointeger();
    }
}
hannah <- Hannah();
agent.send("dweetTemp", hannah.temp.read());
hannah.on_temp_changed = function(state) {
  agent.send("dweetTemp", state);
}
servo1_min <- 0.03
servo2_min <- 0.03
servo1_max <- 0.12
servo2_max <- 0.13
hannah.srv1.scale(servo1_min,servo1_max);
hannah.srv2.scale(servo2_min,servo2_max);
agent.send("dweetPot", hannah.pot.read());
hannah.on_pot_changed = function(state) {
  agent.send("dweetPot", state);
  hannah.srv1.write(state.tofloat() / 100);
  hannah.srv2.write(state.tofloat() / 100);
}
hannah.on_btn1_changed = function(state) {
  if (state) {
    if (!hannah.srv1.enabled()){
      hannah.srv1.setenabled(true);
      hannah.srv2.setenabled(true);
      server.log("Servo enabled");
      hannah.led.set(0,10,0);
    } else {
      hannah.srv1.setenabled(false);
      hannah.srv2.setenabled(false);
      server.log("Servo disabled");
      hannah.led.set(0,0,0);
    }
  }
}
hannah.on_btn2_changed = function(state) {
  if (state) {
    local ledcolor = hannah.led.read();
    if (ledcolor["r"] || ledcolor["g"] || ledcolor["b"]){
      hannah.led.set(0,0,0);
      agent.send("dweetLED", 0);
    } else {
      hannah.led.set(10,0,0);
      agent.send("dweetLED", 1);
    }
  }
}
agent.on("updateLED", function(data){
  server.log("LED Color updated");
  hannah.led.set(data["r"],data["g"],data["b"]);
  if (data["r"] == "0" && data["g"] == "0" && data["b"] == "0"){
    agent.send("dweetLED", 0);
  } else {
    agent.send("dweetLED", 1);
  }
});
