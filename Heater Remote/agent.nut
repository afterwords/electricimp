#require "Dweetio.class.nut:1.0.0"
client <- DweetIO();
local url = "https://agent.electricimp.com/ #Add agent ID to url"
local headers = { "Content-Type" : "application/json" }

function limitpot (value) {
  local adjusted = (value / 4) + 55;
  return adjusted;
}

device.on("update", function(data) {
  data.pot = limitpot(data.pot);
  client.dweet("gelhannah", data);
  local body = http.jsonencode(data);
  server.log(body);
  local request = http.post(url, headers, body);
  local response = request.sendsync();
});

function requestHandler(request, response) {
  if (request.headers["x-forwarded-proto"] != "https") {
    response.send(401, "Insecure access forbidden");
    server.log("Insecure access attempt");
    return;
  }
  try {
    server.log(request.body);
    local data = http.jsondecode(request.body);
    device.send("updateRemote",data);
    response.send(200, null);
  } catch (error) {
    response.send(500, error);
  }
}

http.onrequest(requestHandler);
