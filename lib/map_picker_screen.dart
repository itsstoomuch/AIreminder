import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hive/hive.dart';
import 'models/saved_location.dart';

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  LatLng? selectedPosition;
  String? locationName;
  final Set<Marker> _markers = {};
  late Box<SavedLocation> savedLocationBox;

  @override
  void initState() {
    super.initState();
    savedLocationBox = Hive.box<SavedLocation>('saved_locations');
    _loadSavedMarkers();
  }

  void _loadSavedMarkers() {
    _markers.clear();
    for (var location in savedLocationBox.values) {
      _markers.add(
        Marker(
          markerId: MarkerId(location.name),
          position: LatLng(location.latitude, location.longitude),
          infoWindow: InfoWindow(
            title: location.name,
            onTap: () => _showRenameDeleteDialog(location),
          ),
        ),
      );
    }
    setState(() {});
  }

  void _showRenameDeleteDialog(SavedLocation location) {
    final TextEditingController _renameController =
        TextEditingController(text: location.name);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Location'),
        content: TextField(
          controller: _renameController,
          decoration: const InputDecoration(labelText: 'Rename'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              location.name = _renameController.text.trim();
              location.save();
              Navigator.pop(context);
              _loadSavedMarkers();
            },
            child: const Text('Rename'),
          ),
          TextButton(
            onPressed: () {
              location.delete();
              Navigator.pop(context);
              _loadSavedMarkers();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmLocation(LatLng position) async {
    final nameController = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Save Location"),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: 'Enter name'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                savedLocationBox.add(
                  SavedLocation(
                    name: name,
                    latitude: position.latitude,
                    longitude: position.longitude,
                  ),
                );
                Navigator.pop(context);
                _loadSavedMarkers();
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pick a Location')),
      body: GoogleMap(
        onTap: (position) {
          selectedPosition = position;
          _confirmLocation(position);
        },
        markers: _markers,
        initialCameraPosition: const CameraPosition(
          target: LatLng(19.0760, 72.8777), // Mumbai
          zoom: 12,
        ),
      ),
      floatingActionButton: selectedPosition != null
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.check),
              label: const Text("Use Selected"),
              onPressed: () {
                Navigator.pop(context, {
                  'position': selectedPosition,
                  'name': 'Unnamed Location',
                });
              },
            )
          : null,
    );
  }
}
