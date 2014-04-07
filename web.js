// web.js

String.format = function() {
    var formatString = arguments[0];
    
    // start with the second argument (i = 1)
    for (var i = 1; i < arguments.length; i++) {
        // "gm" = RegEx options for Global search (more than one instance)
        // and for Multiline search
        var regEx = new RegExp("\\{" + (i - 1) + "\\}", "gm");
        formatString = formatString.replace(regEx, arguments[i]);
    }
    
    return formatString;
}

var express = require("express");
var logfmt = require("logfmt");
var os = require("os");
var app = express();

app.use(logfmt.requestLogger());
app.use('/', express.static(__dirname + '/public'));

var port = Number(process.env.VCAP_APP_PORT || 5000);
var nics = os.networkInterfaces();
console.log(os.hostname());
console.log(nics);

app.get('/status', function(req, res) {
  var result = {};
  result["key"] = os.hostname() + ":" + port;
  result["message"] = "Hello World from " + process.env.NAME;

  res.set('Content-Type', 'application/json');
  res.send(JSON.stringify(result));
});
app.listen(port, function() {
  console.log("Listening on " + port);
});
