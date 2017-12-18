// HTTP request handler - This code is blocking - requests processed in order
const API_KEY = "1234567890";  //Make up a secure code, and enter it here and in the app
local DTemp = 0;
local ZRelay = 0;
local GRelay = 0;
local ZaTemp = 0;
local GaTemp = 0;
local ZsTemp = 0;
local ZgTemp = 0;
local GsTemp = 0;
local GgTemp = 0;

http.onrequest(function (req, resp) {
    try {
        //local data = http.jsondecode(req.body);                   //Decode the request body to JSON
        //server.log("Received: " + req.body);                       //Log the request body undecoded
        if ("apikey" in req.headers && req.headers["apikey"] == API_KEY) {
            //server.log(req.headers["apikey"]);                     //Log the recieved API-Key
            local json = "{\"zerocoat\": {\"lightStatus\": "+ZRelay+",\"lightOnMinutes\": 0,\"ambientTemp\": "+ZaTemp+",\"surfaceTemp\": "+ZsTemp+",\"surfaceTempAverage\": 0,\"gapTemp\": "+ZgTemp+",\"gapTempAverage\": 0},\"generic\": {\"lightStatus\": "+GRelay+",\"lightOnMinutes\": 0,\"ambientTemp\": "+GaTemp+",\"surfaceTemp\": "+GsTemp+",\"surfaceTempAverage\": 0,\"gapTemp\": "+GgTemp+",\"gapTempAverage\": 0}}";
            resp.send(200, json);
        }
        else {
            resp.send(401, "Error");
        }
    }
    catch (ex) {
    resp.send(500, "Internal Server Error: " + ex);
  };
});

device.on("DTemp", function(data){
  DTemp = data;
});
device.on("ZRelay", function(data){
  ZRelay = data;
});
device.on("GRelay", function(data){
  GRelay = data;
});
device.on("ZaTemp", function(data){
  ZaTemp = data;
});
device.on("GaTemp", function(data){
  GaTemp = data;
});
device.on("ZsTemp", function(data){
  ZsTemp = data;
});
device.on("GsTemp", function(data){
  GsTemp = data;
});
device.on("ZgTemp", function(data){
  ZgTemp = data;
});
device.on("GgTemp", function(data){
  GgTemp = data;
});
