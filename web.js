// web.js
//
var express = require("express");
var logfmt = require("logfmt");
var os = require("os");
var app = express();

if ( process.env.CONTEXT_ROOT ) {
	var contextroot =   '/' + process.env.CONTEXT_ROOT
} else {
	var contextroot = ''
}


app.use(logfmt.requestLogger());
app.use(contextroot + '/', express.static(__dirname + '/public'));

var port = Number(process.env.VCAP_APP_PORT || 5000);

app.get(contextroot + '/status', function(req, res) {
  var result = {};
  result["key"] = os.hostname() + ":" + port;
  result["release"] = process.env.RELEASE;
  result["message"] = "Hello World from " + process.env.RELEASE;

  res.set('Content-Type', 'application/json');
  res.send(JSON.stringify(result));
});

app.get(contextroot + '/environment', function(req, res) {
  res.set('Content-Type', 'application/json');
  res.send(JSON.stringify(process.env));
});

app.get(contextroot + '/headers', function(req, res) {
  res.set('Content-Type', 'application/json');
  res.send(JSON.stringify(req.headers));
});


app.listen(port, function() {
  console.log("Listening on " + port);
});
