local i2c = hardware.i2c89;
i2c.configure(CLOCK_SPEED_100_KHZ);
relay1 <- hardware.pin5; // Enable Pin 5 for Relay
relay1.configure(DIGITAL_OUT);
// relay2 <- hardware.pin7; // Enable Pin 7 for Relay
// relay2.configure(DIGITAL_OUT);

currentState <- {
  "relay1":0,
  "relay2":0,
}
// Relay Switch Functions
function switchRelay1(state) {
  server.log(state);
  switch (state) {
    case 0:
      {
        relay1.write(0);
        currentState.relay1 = 1;
      }
    case 1:
      {
        relay1.write(1);
        currentState.relay1 = 0;
      }
  }
  agent.send("updateRemote", currentState);
}

switchRelay1(currentState.relay1);
agent.send("updateRemote", currentState);
agent.on("switchRelay1", switchRelay1);
