// web.js
//
var express = require("express");
var logfmt = require("logfmt");
var os = require("os");
var app = express();

app.use(logfmt.requestLogger());
app.use('/', express.static(__dirname + '/public'));

var port = Number(process.env.VCAP_APP_PORT || 5000);

app.get('/status', function(req, res) {
  var result = {};
  result["key"] = os.hostname() + ":" + port;
  result["release"] = process.env.RELEASE;
  result["message"] = "Hello World from " + process.env.RELEASE;

  res.set('Content-Type', 'application/json');
  res.send(JSON.stringify(result));
});

app.listen(port, function() {
  console.log("Listening on " + port);
});
