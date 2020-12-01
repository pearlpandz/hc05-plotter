import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ChatPage extends StatefulWidget {
  final BluetoothDevice server;

  const ChatPage({this.server});

  @override
  _ChatPage createState() => new _ChatPage();
}

// ignore: unused_element
class _Message {
  int whom;
  String text;

  _Message(this.whom, this.text);
}

class _ChatPage extends State<ChatPage> {
  BluetoothConnection connection;

  bool isConnecting = true;

  bool get isConnected => connection != null && connection.isConnected;

  bool isDisconnecting = false;

  List _binary = List();

  Timer timer;

  int seconds = 0;

  // ignore: non_constant_identifier_names
  Map<String, O2Series> o2_data = {};

  final GlobalKey<State<StatefulWidget>> _printKey = GlobalKey();

  void _printScreen() {
    Printing.layoutPdf(onLayout: (PdfPageFormat format) async {
      final doc = pw.Document();

      final image = await wrapWidget(
        doc.document,
        key: _printKey,
        pixelRatio: 2.0,
      );

      doc.addPage(pw.Page(
          pageFormat: format,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Expanded(
                child: pw.Image(image),
              ),
            );
          }));

      return doc.save();
    });
  }

  @override
  void initState() {
    super.initState();

    timer = Timer.periodic(
        Duration(seconds: 1),
        (Timer t) => setState(() {
              seconds += 1;
            }));

    BluetoothConnection.toAddress(widget.server.address).then((_connection) {
      print('Connected to the device');
      connection = _connection;
      setState(() {
        isConnecting = false;
        isDisconnecting = false;
      });

      connection.input.listen(_onDataReceived).onDone(() {
        if (isDisconnecting) {
          print('Disconnecting locally!');
        } else {
          print('Disconnected remotely!');
        }
        if (this.mounted) {
          setState(() {});
        }
      });
    }).catchError((error) {
      print('Cannot connect, exception occured');
      print(error);
    });
  }

  @override
  void dispose() {
    // Avoid memory leak (`setState` after dispose) and disconnect
    if (isConnected) {
      isDisconnecting = true;
      connection.dispose();
      connection = null;
    }

    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var series = [
      new charts.Series<O2Series, int>(
          domainFn: (O2Series clickData, _) => clickData.num,
          measureFn: (O2Series clickData, _) => clickData.value,
          id: 'Clicks',
          data: o2_data.values.toList()),
    ];
    var chart = new charts.LineChart(
      series,
      animate: false,
      behaviors: [
        new charts.ChartTitle('Time(seconds)',
            behaviorPosition: charts.BehaviorPosition.bottom,
            titleOutsideJustification:
                charts.OutsideJustification.middleDrawArea),
        new charts.ChartTitle('PO2(%)',
            behaviorPosition: charts.BehaviorPosition.start,
            titleOutsideJustification:
                charts.OutsideJustification.middleDrawArea),
      ],
    );

    var chartWidget = new SizedBox(
      child: chart,
    );

    return Scaffold(
      appBar: AppBar(
          title: (isConnecting
              ? Text('Connecting to ' + widget.server.name + '...')
              : isConnected
                  ? Text('Conected with ' + widget.server.name)
                  : Text('Chat log with ' + widget.server.name))),
      body: SafeArea(
          child: RepaintBoundary(
              key: _printKey,
              child: isConnected
                  ? new Column(children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 20.0),
                        child: Text(
                          'LIDS - RV',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                              fontSize: 16),
                        ),
                      ),
                      Flexible(child: chartWidget)
                    ])
                  : new Center(
                      child: Text('connecting...'),
                    ))),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.print),
        onPressed: _printScreen,
      ),
    );
  }

  void _onDataReceived(Uint8List data) {
    _binary = data;
    // print(data);
    DateTime now = new DateTime.now();
    var converted = int.parse(ascii.decode([_binary[1]])) * 100 +
        int.parse(ascii.decode([_binary[2]])) * 10 +
        int.parse(ascii.decode([_binary[3]])) * 1;

    o2_data[now.toString()] = O2Series(converted, seconds);

    setState(() {
      _binary = _binary;
      o2_data = o2_data;
    });
  }
}

/// Sample linear data type.
class O2Series {
  final int value;
  final int num;

  O2Series(this.value, this.num);
}
