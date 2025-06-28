// lib/map_picker_preview.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hive/hive.dart';
import 'models/saved_location.dart';

class MapPickerPreview extends StatefulWidget {
  final Function(LatLng, String) onLocationSelected;

  const MapPickerPreview({super.key, required this.onLocationSelected});

  @override
  State<MapPickerPreview> createState() => _MapPickerPreviewState();
}

class _MapPickerPreviewState extends State<MapPickerPreview> {
  Set<Marker> _markers = {};
  late GoogleMapController _mapController;

  @override
  void initState() {
    super.initState();
    _loadMarkers();
  }

  Future<void> _loadMarkers() async {
    final box = Hive.box<SavedLocation>('saved_locations');
    final saved = box.values.toList();
    setState(() {
      _markers = saved.map((loc) {
        return Marker(
          markerId: MarkerId(loc.name),
          position: LatLng(loc.latitude, loc.longitude),
          infoWindow: InfoWindow(
            title: loc.name,
            onTap: () {
              widget.onLocationSelected(
                LatLng(loc.latitude, loc.longitude),
                loc.name,
              );
            },
          ),
        );
      }).toSet();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      onMapCreated: (controller) => _mapController = controller,
      initialCameraPosition: const CameraPosition(
        target: LatLng(19.0760, 72.8777), // Mumbai
        zoom: 14,
      ),
      markers: _markers,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
    );
  }
}
