function drawGraph(graph_container_id, error_container_id, auth_token) {
  var graph = new google.visualization.BarChart(document.getElementById(graph_container_id));

  var data = new google.visualization.DataTable();
  var maxAge = 100;   /* days */
  var outstandingRequests = maxAge;

  data.addColumn('string');
  data.addColumn('number', "Page Views");

  data.addRows(maxAge);

  var addError = function(error_text) {
    $("#" + error_container_id).append(
      "<p> An error occurred: " + error_text + "</p>");
  };

  var makeResponseHandler = function(age) {
    return function(responseText, textStatus, xhr) {
      pageViews = parseInt(responseText, 10);

      data.setValue(age - 1, 0, new Number(age).toString() + " days");
      data.setValue(age - 1, 1, pageViews);

      outstandingRequests--;
    };
  };

  var drawIfDone = function() {
    if (outstandingRequests == 0) {
      graph.draw(data,
                 {width: 800, height: maxAge * 25, title: 'User Activity by Age',
                  vAxis: {title: 'User Age', titleTextStyle: {color: 'red'}},
                 });
    }
  };

  var handleError = function(jqxhr, textStatus, errorThrown) {
    addError(errorThrown);
  };

  for (var i = 1; i <= maxAge; i++) {
    $.ajax({
      url: "/count/activity-" + i + "-days/days/7?auth_token=" + auth_token,
      statusCode: {
        200: [makeResponseHandler(i), drawIfDone],
        403: handleError,
        404: handleError,
        500: handleError,
      },
      error: handleError,
    });
  }
}
