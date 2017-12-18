#require "Dweetio.class.nut:1.0.0"
client <- DweetIO();
dweetMessage <- {
  "temp":0,
  "pot":0,
  "led":0,
}
color <- {
  "red":0,
  "green":0,
  "blue":0,
}
device.on("dweetTemp", function(temp) {
  dweetMessage.temp = temp;
  dweetAll(dweetMessage);
});
device.on("dweetPot", function(pot) {
  dweetMessage.pot = pot;
  dweetAll(dweetMessage);
});
device.on("dweetLED", function(state){
  dweetMessage.led = state;
  dweetAll(dweetMessage);
});
function dweetAll(dweetMessage){
  client.dweet("gelhannah", dweetMessage);
  server.log("Dweet updated")
}
function updatePage(){
  page <- @"<!DOCTYPE html>
  <html>
  <head>
    <link rel=""stylesheet"" href=""//code.jquery.com/ui/1.11.4/themes/smoothness/jquery-ui.css"">
    <script src=""//code.jquery.com/jquery-1.10.2.js""></script>
    <script src=""//code.jquery.com/ui/1.11.4/jquery-ui.js""></script>
    <script>
      function refreshSwatch() {
        var red = $( ""#red"" ).slider( ""value"" ),
          green = $( ""#green"" ).slider( ""value"" ),
          blue = $( ""#blue"" ).slider( ""value"" )
        $( ""#swatch"" ).css( ""background-color"", ""rgb("" + red + "","" + green + "","" + blue + "")"" );
      }
      $(function() {
        $( ""button"" )
          .button()
          .click(function( event ) {
            event.preventDefault();
              var colorData = {};
              colorData['r'] = $( ""#red"" ).slider( ""value"" );
              colorData['g'] = $( ""#green"" ).slider( ""value"" );
              colorData['b'] = $( ""#blue"" ).slider( ""value"" );
              $.ajax({
                type: 'PUT',
                dataType: 'json',
                data: colorData,
              });
          });
      });
      $(function() {
        $( ""#red, #green, #blue"" ).slider({
          orientation: ""horizontal"",
          range: ""min"",
          max: 255,
          value: 0,
          slide: refreshSwatch,
          change: refreshSwatch
        });
        $( ""#red"" ).slider( ""value"", 0 );
        $( ""#green"" ).slider( ""value"", 0 );
        $( ""#blue"" ).slider( ""value"", 0 );
      });
    </script>
    <style>
    #red, #green, #blue {
      float: left;
      width: 120px;
      margin: 15px;
      clear: left;
    }
    #red .ui-slider-range { background: red; }
    #red .ui-slider-handle { border-color: red; }
    #green .ui-slider-range { background: lime; }
    #green .ui-slider-handle { border-color: lime; }
    #blue .ui-slider-range { background: blue; }
    #blue .ui-slider-handle { border-color: blue; }
    #swatch {
      width: 30px;
      height: 30px;
      -moz-border-radius:15px;
      -webkit-border-radius:15px;
      border-radius:15px;
      margin-top: 10px;
      background-image: none;
      float: left;
      margin-left: 57px;
    }
    #submit {
      margin-top: 10px;
      float: left;
      clear: left;
    }
    </style>
  </head>
  <body>
    <div id=""swatch""></div>
    <div id=""red""></div>
    <div id=""green""></div>
    <div id=""blue""></div>
    <button id=""submit"">Update LED</button>
  </body>
  </html>"
}

http.onrequest(function(request, response) {
  try {
    local method = request.method.toupper()
    if (method == "GET") {
      updatePage();
      response.send(200, page);
    }
    if (method == "PUT") {
      local data = http.urldecode(request.body);
      device.send("updateLED", data);
      response.send(200, null);
    }
  }
  catch(error) {
    response.send(500, error)
  }
})
