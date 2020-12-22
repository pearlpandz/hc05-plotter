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
                      // Flexible(child: chartWidget)
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

  void _onDataReceived(data) {
    _binary += data;
    if (_binary.length >= 32) {
      // START
      print('Iteration: ${ascii.decode([
        _binary[0],
        _binary[1],
        _binary[2],
        _binary[3],
        _binary[4]
      ])}');

      // TEMPERATURE
      var temp1 =
          _binary[5].toString().length == 1 ? '0${_binary[5]}' : _binary[5];
      var temp2 =
          _binary[6].toString().length == 1 ? '0${_binary[6]}' : _binary[6];
      var temp3 =
          _binary[7].toString().length == 1 ? '0${_binary[7]}' : _binary[7];
      var temp4 =
          _binary[8].toString().length == 1 ? '0${_binary[8]}' : _binary[8];
      var temperature = int.parse('$temp1$temp2$temp3$temp4', radix: 16) / 100;
      print('temperature: $temperature C');

      // PRESSUER
      var pres1 =
          _binary[9].toString().length == 1 ? '0${_binary[9]}' : _binary[9];
      var pres2 =
          _binary[10].toString().length == 1 ? '0${_binary[10]}' : _binary[10];
      var pres3 =
          _binary[11].toString().length == 1 ? '0${_binary[11]}' : _binary[11];
      var pres4 =
          _binary[12].toString().length == 1 ? '0${_binary[12]}' : _binary[12];
      var pressuer = int.parse('$pres1$pres2$pres3$pres4', radix: 16) / 100;
      print('pressuer: $pressuer hpa');

      // VOC value
      var voc1 = (_binary[13] - 13) * (1000 / 229);
      print('VOC Value: $voc1 ppb');

      // Co2 value
      var co = (_binary[14] - 13) * (1600 / 229) + 400;
      print('Co2 Value: $co ppm');

      // Coil Current value
      var ccv1 =
          _binary[20].toString().length == 1 ? '0${_binary[20]}' : _binary[20];
      var ccv2 =
          _binary[21].toString().length == 1 ? '0${_binary[21]}' : _binary[21];
      var ccv3 =
          _binary[22].toString().length == 1 ? '0${_binary[22]}' : _binary[22];
      var ccv4 =
          _binary[23].toString().length == 1 ? '0${_binary[23]}' : _binary[23];
      var ccv = int.parse('$ccv1$ccv2$ccv3$ccv4', radix: 16);
      print('Coil Current Value: $ccv');

      // O2 sense value
      var o1 =
          _binary[24].toString().length == 1 ? '0${_binary[24]}' : _binary[24];
      var o2 =
          _binary[25].toString().length == 1 ? '0${_binary[25]}' : _binary[25];
      var o3 =
          _binary[26].toString().length == 1 ? '0${_binary[26]}' : _binary[26];
      var o4 =
          _binary[27].toString().length == 1 ? '0${_binary[27]}' : _binary[27];
      var o = int.parse('$o1$o2$o3$o4', radix: 16);
      print('O2 Sense Value: $o');

      // Battery voltage
      var bv1 =
          _binary[28].toString().length == 1 ? '0${_binary[28]}' : _binary[28];
      var bv2 =
          _binary[29].toString().length == 1 ? '0${_binary[29]}' : _binary[29];
      var bv3 =
          _binary[30].toString().length == 1 ? '0${_binary[30]}' : _binary[30];
      var bv4 =
          _binary[31].toString().length == 1 ? '0${_binary[31]}' : _binary[31];
      var bv = ((3.125 / 1024) * int.parse('$bv1$bv2$bv3$bv4', radix: 16)) * 2;
      print('Battery voltage: $bv V');

      // DateTime now = new DateTime.now();
      // var converted = int.parse(ascii.decode([_binary[1]])) * 100 +
      //     int.parse(ascii.decode([_binary[2]])) * 10 +
      //     int.parse(ascii.decode([_binary[3]])) * 1;

      // o2_data[now.toString()] = O2Series(converted, seconds);

      // setState(() {
      //   _binary = _binary;
      //   o2_data = o2_data;
      // });

      // REMOVE THE ENITER ITERATION
      _binary.removeRange(0, 32);
      print('-------------------------');
    }
  }
}

/// Sample linear data type.
class O2Series {
  final int value;
  final int num;

  O2Series(this.value, this.num);
}
