// HTTP request handler - This code is blocking - requests processed in order
const API_KEY = "1234567890";  //Make up a secure code, and enter it here and in the app
http.onrequest(function (req, resp) {
    try {
        local data = http.jsondecode(req.body);                             //Decode the request body to JSON
        server.log("Received: " + req.body);                                //Log the request body undecoded
        if ("api-key" in req.headers && req.headers["api-key"] == API_KEY) {
            server.log(req.headers["api-key"]);                             //Log the recieved API-Key
            if ("button1" in data) {                                        //Start checking the JSON for Keys
                device.send("button1", data.button1);
                device.on("button1", function(d) {
                    local json = "{ \"status\" : { \"button1\" : \"" + d + "\" }}";
                    resp.send(200,json);
                });
            }
            else if ("button2" in data) {
                device.send("button2", data.button2);
                device.on("button2", function(d) {
                    local json = "{ \"status\" : { \"button2\" : \"" + d + "\" }}";
                    resp.send(200,json);
                });
            }
            else if ("button3" in data) {
                device.send("button3", data.button3);
                device.on("button3", function(d) {
                    local json = "{ \"status\" : { \"button3\" : \"" + d + "\" }}";
                    resp.send(200,json);
                });
            }
            else if ("button4" in data) {
                device.send("button4", data.button4);
                device.on("button4", function(d) {
                    local json = "{ \"status\" : { \"button4\" : \"" + d + "\" }}";
                    resp.send(200,json);
                });
            }
            else if ("button5" in data) {
                device.send("button5", data.button5);
                device.on("button5", function(d) {
                    local json = "{ \"status\" : { \"button5\" : \"" + d + "\" }}";
                    resp.send(200,json);
                });
            }
            else if ("button6" in data) {
                device.send("button6", data.button6);
                device.on("button6", function(d) {
                    local json = "{ \"status\" : { \"button6\" : \"" + d + "\" }}";
                    resp.send(200,json);
                });
            }
            else if ("button7" in data) {
                device.send("button7", data.button7);
                device.on("button7", function(d) {
                    local json = "{ \"status\" : { \"button7\" : \"" + d + "\" }}";
                    resp.send(200,json);
                });
            }
            else if ("button8" in data) {
                device.send("button8", data.button8);
                device.on("button8", function(d) {
                    local json = "{ \"status\" : { \"button8\" : \"" + d + "\" }}";
                    resp.send(200,json);
                });
            }
            else if ("button9" in data) {
                device.send("button9", data.button9);
                device.on("button9", function(d) {
                    local json = "{ \"status\" : { \"button9\" : \"" + d + "\" }}";
                    resp.send(200,json);
                });
            }
            else if ("switch1" in data) {
                device.send("switch1", data.switch1);
                device.on("switch1", function(d) {
                    local json = "{ \"status\" : { \"switch1\" : \"" + d + "\" }}";
                    resp.send(200,json);
                });
            }
            else if ("switch2" in data) {
                device.send("switch2", data.switch2);
                device.on("switch2", function(d) {
                    local json = "{ \"status\" : { \"switch2\" : \"" + d + "\" }}";
                    resp.send(200,json);
                });
            }
            else if ("slider1" in data) {
                device.send("slider1", data.slider1);
                device.on("slider1", function(d) {
                    local json = "{ \"status\" : { \"slider1\" : \"" + d + "\" }}";
                    resp.send(200,json);
                });
            }
            else if ("slider2" in data) {
                device.send("slider2", data.slider2);
                device.on("slider2", function(d) {
                    local json = "{ \"status\" : { \"slider2\" : \"" + d + "\" }}";
                    resp.send(200,json);
                });
            }
        }
        else {
            local json = "{ \"status\" : { \"auth\" : \"no\" }}";
            resp.send(401, json);
        }
    }
    catch (ex) {
    resp.send(500, "Internal Server Error: " + ex);
  }
});
