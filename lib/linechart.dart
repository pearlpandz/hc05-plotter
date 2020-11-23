/// Example of a simple line chart.
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/material.dart';

import 'led.dart';

class SimpleLineChart extends StatelessWidget {
  final List<charts.Series> seriesList;
  final bool animate;

  SimpleLineChart(this.seriesList, {this.animate});

  /// Creates a [LineChart] with sample data and no transition.
  factory SimpleLineChart.withSampleData() {
    return new SimpleLineChart(
      _createSampleData(),
      animate: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return new charts.LineChart(seriesList, animate: animate);
  }

  /// Create one series with sample hard coded data.
  static List<charts.Series<O2Series, int>> _createSampleData() {
    // final data = seriesList.map((data) {
    //   print(data);
    //   return new O2Series(0,10);
    // });

     final data = [
      new O2Series(0, 5),
      new O2Series(1, 25),
      new O2Series(2, 100),
      new O2Series(3, 75),
    ];
  
    return [
      new charts.Series<O2Series, int>(
        id: 'O2 Analysis',
        colorFn: (_, __) => charts.MaterialPalette.blue.shadeDefault,
        domainFn: (O2Series sales, _) => sales.value.toInt(),
        measureFn: (O2Series sales, _) => sales.num,
        data: data,
      )
    ];
  }
}
