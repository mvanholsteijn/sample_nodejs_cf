function MonitorController($scope, $interval, $http) {
    var monitor;
    $scope.error_count = 0;
    $scope.responses = [];
    $scope.count = {};
    $scope.last_status = "";

    $scope.startMonitor =  function() {
      // Don't start a new monitor if one is already active
      if ( angular.isDefined(monitor) ) return;
 
      monitor = $interval(function() {
            $scope.callService();
        }, 250);
      };

    $scope.stopMonitor = function() {
      if ( angular.isDefined(monitor) )  {
	$interval.cancel(monitor);
	monitor = undefined;
      }
    }

    $scope.$on('$destroy', function() {
      // Make sure that the monitor is destroyed too
      $scope.stopMonitor();
    });

    $scope.callService = function() {
	    $http.get('http://' + document.location.host + '/status').
		success(function(response) {
		    var key = response.key;
		    $scope.msg = key;
		    if($scope.count.hasOwnProperty(key)) {
			    $scope.count[key] += 1;
		    } else {
			    $scope.count[key] = 1;
			    $scope.responses.push(response);
		    }
		}).
		error(function(data, status, headers, config) {
			console.log(data);
			console.log(status);
			console.log(headers);
			console.log(config);
			$scope.error_count++;
			$scope.last_status = "" + status + ", " + data;
			console.log("error calling " + config.url + ", " + $scope.last_status);
			if($scope.error_count % 250 == 0) {
				$scope.stopMonitor();
				console.log("more than 250 errors, stopped monitoring.");
			}
		});
   }
}
