import 'package:latlong2/latlong.dart';

class AccommodationRecommendation {
  final String name;
  final double rating;
  final double distanceKm;
  final int vacancies;
  final String area;
  final String note;
  final List<String> facilities;
  final LatLng coords;

  const AccommodationRecommendation({
    required this.name,
    required this.rating,
    required this.distanceKm,
    required this.vacancies,
    required this.area,
    required this.note,
    required this.facilities,
    required this.coords,
  });
}

/// Curated offline recommendations. Ratings are stored editorial rankings, not
/// live availability; the UI asks travellers to verify before booking.
class AccommodationRepository {
  AccommodationRepository._();
  static final instance = AccommodationRepository._();
  AccommodationRecommendation? selectedHotel;

  List<AccommodationRecommendation> forDestination(String id) {
    switch (id) {
      case 'visakhapatnam':
        return const [
          AccommodationRecommendation(
            name: 'Simhachalam Devasthanam Choultry',
            rating: 4.8,
            distanceKm: 0.4,
            vacancies: 6,
            area: 'Simhachalam Temple area',
            note: 'Pilgrim-friendly stay close to the temple',
            facilities: ['Water', 'Hot water', 'Lockers'],
            coords: LatLng(17.7663, 83.2505),
          ),
          AccommodationRecommendation(
            name: 'Novotel Visakhapatnam Varun Beach',
            rating: 4.6,
            distanceKm: 8.7,
            vacancies: 3,
            area: 'Beach Road',
            note: 'Highly rated city hotel',
            facilities: ['Restaurant', 'Security', 'Wi-Fi'],
            coords: LatLng(17.7126, 83.3170),
          ),
          AccommodationRecommendation(
            name: 'The Gateway Hotel Beach Road',
            rating: 4.5,
            distanceKm: 7.8,
            vacancies: 8,
            area: 'Beach Road',
            note: 'Comfortable stay near the city centre',
            facilities: ['Restaurant', 'Parking', 'Wi-Fi'],
            coords: LatLng(17.7120, 83.3185),
          ),
          AccommodationRecommendation(
            name: 'Daspalla Hotel',
            rating: 4.3,
            distanceKm: 6.4,
            vacancies: 2,
            area: 'Waltair Main Road',
            note: 'Central hotel with pilgrim transport access',
            facilities: ['Restaurant', 'Parking', 'Room service'],
            coords: LatLng(17.7200, 83.3150),
          ),
          AccommodationRecommendation(
            name: 'APTDCL Haritha Beach Resort',
            rating: 4.1,
            distanceKm: 14.2,
            vacancies: 5,
            area: 'Rushikonda',
            note: 'Beach-side stay for longer visits',
            facilities: ['Sea view', 'Restaurant', 'Security'],
            coords: LatLng(17.7820, 83.3850),
          ),
        ];
      case 'vijayawada_ap':
        return const [
          AccommodationRecommendation(
            name: 'Kanaka Durga Devasthanam Guest House',
            rating: 4.8,
            distanceKm: 0.5,
            vacancies: 4,
            area: 'Kanaka Durga Temple area',
            note: 'Pilgrim stay near the temple',
            facilities: ['Water', 'Cloakroom', 'Security'],
            coords: LatLng(16.5150, 80.6110),
          ),
          AccommodationRecommendation(
            name: 'Novotel Vijayawada Varun',
            rating: 4.5,
            distanceKm: 5.2,
            vacancies: 7,
            area: 'Mangalagiri Road',
            note: 'Top-rated city stay',
            facilities: ['Restaurant', 'Pool', 'Wi-Fi'],
            coords: LatLng(16.5000, 80.6500),
          ),
        ];
      default:
        return const [];
    }
  }
}
