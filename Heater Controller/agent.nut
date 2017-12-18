local url = "https://agent.electricimp.com/ #ADD AGENT ID TO URL"
local headers = { "Content-Type" : "application/json" }

function switchRelay1(state) {
  device.send("switchRelay1", state);
}

device.on("updateRemote", function(data) {
  server.log(data.relay1);
  local body = http.jsonencode(data);
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
    local data = http.jsondecode(request.body);
    switchRelay1(data.relay1);
    response.send(200, null);
  } catch (error) {
    response.send(500, error);
  }
}

http.onrequest(requestHandler);
