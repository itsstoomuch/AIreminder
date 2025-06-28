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
  LatLng? _selectedPosition;
  final TextEditingController _nameController = TextEditingController();
  Set<Marker> _markers = {};
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _loadSavedMarkers();
  }

  Future<void> _loadSavedMarkers() async {
    final box = Hive.box<SavedLocation>('saved_locations');
    final locations = box.values.toList();

    setState(() {
      _markers = locations.map((loc) {
        return Marker(
          markerId: MarkerId(loc.name),
          position: LatLng(loc.latitude, loc.longitude),
          infoWindow: InfoWindow(
            title: loc.name,
            onTap: () => _showLocationOptions(loc),
          ),
        );
      }).toSet();
    });
  }

  void _showLocationOptions(SavedLocation loc) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text("Use '${loc.name}'"),
            onTap: () {
              Navigator.pop(context); // Close bottom sheet
              Navigator.pop(context, {
                'position': LatLng(loc.latitude, loc.longitude),
                'name': loc.name,
              });
            },
          ),
          ListTile(
            title: const Text("Rename"),
            onTap: () {
              Navigator.pop(context);
              _renameLocation(loc);
            },
          ),
          ListTile(
            title: const Text("Delete"),
            onTap: () async {
              Navigator.pop(context);
              await Hive.box<SavedLocation>('saved_locations').delete(loc.key);
              _loadSavedMarkers();
            },
          ),
        ],
      ),
    );
  }

  void _renameLocation(SavedLocation loc) {
    final controller = TextEditingController(text: loc.name);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Rename Location"),
        content: TextField(controller: controller),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                loc.name = newName;
                await loc.save();
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

  void _showNameDialog() {
    _nameController.clear();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Name this location"),
        content: TextField(
          controller: _nameController,
          decoration: const InputDecoration(hintText: "e.g. College Gate"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // Close dialog
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: _saveNewLocation,
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _saveNewLocation() async {
    final name = _nameController.text.trim();
    if (_selectedPosition != null && name.isNotEmpty) {
      final box = Hive.box<SavedLocation>('saved_locations');
      final newLoc = SavedLocation(
        name: name,
        latitude: _selectedPosition!.latitude,
        longitude: _selectedPosition!.longitude,
      );
      await box.add(newLoc);
      Navigator.pop(context); // Close dialog
      Navigator.pop(context, {
        'position': _selectedPosition,
        'name': name,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pick Location"),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              Navigator.pop(context, null); // Cancel → return null
            },
          ),
        ],
      ),
      body: GoogleMap(
        onMapCreated: (controller) => _mapController = controller,
        initialCameraPosition: const CameraPosition(
          target: LatLng(19.0760, 72.8777), // Mumbai
          zoom: 14,
        ),
        markers: _markers,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        onTap: (pos) {
          setState(() {
            _selectedPosition = pos;
            _markers.add(
              Marker(
                markerId: const MarkerId("new"),
                position: pos,
              ),
            );
          });
          _showNameDialog();
        },
      ),
    );
  }
}
