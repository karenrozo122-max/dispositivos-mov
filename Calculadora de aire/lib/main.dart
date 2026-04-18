import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calidad del Aire',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: AirQualityPage(),
    );
  }
}

class AirQualityPage extends StatefulWidget {
  @override
  _AirQualityPageState createState() => _AirQualityPageState();
}

class _AirQualityPageState extends State<AirQualityPage> {
  String? ciudadSeleccionada;
  DateTime? fechaSeleccionada;
  TextEditingController horasController = TextEditingController();

  bool cargando = false;
  String resultado = "";

  Map<String, Map<String, double>> ciudades = {
    "Medellín": {"lat": 6.25, "lon": -75.56},
    "Bogotá": {"lat": 4.71, "lon": -74.07},
    "Cali": {"lat": 3.45, "lon": -76.53},
    "Barranquilla": {"lat": 10.98, "lon": -74.80},
  };

  Future<double> obtenerPM25Promedio(
      double lat, double lon, String fecha) async {
    final url =
        Uri.parse('https://air-quality-api.open-meteo.com/v1/air-quality'
            '?latitude=$lat&longitude=$lon'
            '&hourly=pm2_5'
            '&start_date=$fecha&end_date=$fecha');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      List pmValues = data['hourly']['pm2_5'];

      double suma = 0;
      int count = 0;

      for (var val in pmValues) {
        if (val != null) {
          suma += val;
          count++;
        }
      }

      return suma / count;
    } else {
      throw Exception('Error al consultar API');
    }
  }

  String calcularRiesgo(double pm25, double horas) {
    double indice = pm25 * horas;

    if (indice <= 50) return "Bajo 🟢";
    if (indice <= 100) return "Moderado 🟡";
    if (indice <= 200) return "Alto 🟠";
    return "Muy alto 🔴";
  }

  Future<void> consultar() async {
    if (ciudadSeleccionada == null ||
        fechaSeleccionada == null ||
        horasController.text.isEmpty) {
      setState(() {
        resultado = "⚠️ Completa todos los campos";
      });
      return;
    }

    double horas = double.tryParse(horasController.text) ?? 0;

    if (horas <= 0) {
      setState(() {
        resultado = "⚠️ Ingresa horas válidas";
      });
      return;
    }

    setState(() {
      cargando = true;
      resultado = "";
    });

    try {
      var coords = ciudades[ciudadSeleccionada]!;

      String fecha =
          "${fechaSeleccionada!.year}-${fechaSeleccionada!.month.toString().padLeft(2, '0')}-${fechaSeleccionada!.day.toString().padLeft(2, '0')}";

      double pm25 =
          await obtenerPM25Promedio(coords["lat"]!, coords["lon"]!, fecha);

      double indice = pm25 * horas;
      String riesgo = calcularRiesgo(pm25, horas);

      setState(() {
        resultado =
            "PM2.5 promedio: ${pm25.toStringAsFixed(2)}\nÍndice: ${indice.toStringAsFixed(2)}\nRiesgo: $riesgo";
      });
    } catch (e) {
      setState(() {
        resultado = "❌ Error al consultar datos";
      });
    }

    setState(() {
      cargando = false;
    });
  }

  Future<void> seleccionarFecha(BuildContext context) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        fechaSeleccionada = picked;
      });
    }
  }

  Color obtenerColorRiesgo() {
    if (resultado.contains("Bajo")) return Colors.green;
    if (resultado.contains("Moderado")) return Colors.yellow;
    if (resultado.contains("Alto")) return Colors.orange;
    if (resultado.contains("Muy alto")) return Colors.red;
    return Colors.black;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Calidad del Aire")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              hint: Text("Selecciona ciudad"),
              value: ciudadSeleccionada,
              items: ciudades.keys.map((ciudad) {
                return DropdownMenuItem(
                  value: ciudad,
                  child: Text(ciudad),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  ciudadSeleccionada = value;
                });
              },
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => seleccionarFecha(context),
              child: Text(fechaSeleccionada == null
                  ? "Seleccionar fecha"
                  : "${fechaSeleccionada!.toLocal()}".split(' ')[0]),
            ),
            SizedBox(height: 10),
            TextField(
              controller: horasController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Horas al aire libre",
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: cargando ? null : consultar,
              child: Text("Consultar"),
            ),
            SizedBox(height: 20),
            if (cargando) CircularProgressIndicator(),
            SizedBox(height: 20),
            Text(
              resultado,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: obtenerColorRiesgo(),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
