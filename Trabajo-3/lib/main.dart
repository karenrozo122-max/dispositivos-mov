import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MapaPage(),
    );
  }
}

class MapaPage extends StatefulWidget {
  @override
  _MapaPageState createState() => _MapaPageState();
}

class _MapaPageState extends State<MapaPage> {
  LatLng? posicion;
  Set<Marker> markers = {};
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    iniciarApp();
  }

  Future<void> iniciarApp() async {
    try {
      Position pos = await obtenerUbicacion();
      List eventos = await obtenerEventos();

      Set<Marker> nuevosMarkers = crearMarcadores(eventos);

      setState(() {
        posicion = LatLng(pos.latitude, pos.longitude);
        markers = nuevosMarkers;
        cargando = false;
      });
    } catch (e) {
      print(e);
    }
  }

  // 📍 UBICACIÓN
  Future<Position> obtenerUbicacion() async {
    bool servicio = await Geolocator.isLocationServiceEnabled();
    if (!servicio) {
      return Future.error('GPS desactivado');
    }

    LocationPermission permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }

    return await Geolocator.getCurrentPosition();
  }

  // 🌐 API TICKETMASTER
  Future<List> obtenerEventos() async {
    final url = Uri.parse(
        'https://app.ticketmaster.com/discovery/v2/events.json?apikey=TU_API_KEY&city=Medellin');

    final response = await http.get(url);

    final data = json.decode(response.body);

    if (data['_embedded'] == null) return [];

    return data['_embedded']['events'];
  }

  // 🗺️ MARCADORES
  Set<Marker> crearMarcadores(List eventos) {
    return eventos.map<Marker>((evento) {
      final venue = evento['_embedded']['venues'][0];

      final lat = double.tryParse(venue['location']['latitude'] ?? '0') ?? 0;
      final lng = double.tryParse(venue['location']['longitude'] ?? '0') ?? 0;

      return Marker(
        markerId: MarkerId(evento['id']),
        position: LatLng(lat, lng),
        infoWindow: InfoWindow(
          title: evento['name'] ?? 'Evento',
          snippet:
              "${evento['dates']['start']['localDate']} - ${evento['dates']['status']['code']}",
        ),
      );
    }).toSet();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Eventos Cercanos")),
      body: cargando
          ? Center(child: CircularProgressIndicator())
          : GoogleMap(
              initialCameraPosition: CameraPosition(
                target: posicion!,
                zoom: 14,
              ),
              myLocationEnabled: true,
              markers: markers,
            ),
    );
  }
}
