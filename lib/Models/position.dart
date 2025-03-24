import 'package:geotypes/src/geojson.dart' as geo;

class Position {
  final double longitude;
  final double latitude;

  Position(this.longitude, this.latitude);

  // For map representation
  Map<String, double> toMap() {
    return {
      'longitude': longitude,
      'latitude': latitude,
    };
  }

  // Create a Position from a map
  factory Position.fromMap(Map<String, dynamic> map) {
    return Position(
      map['longitude'] as double,
      map['latitude'] as double,
    );
  }
}