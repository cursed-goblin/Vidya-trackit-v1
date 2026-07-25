/// A rider profile (student OR teacher - they share the same app role and are
/// distinguished by [riderType], which only the admin screens act on).
/// Loaded from `public.profiles` + `public.rider_bus`.
class Student {
  final String id; // auth uid (or college id in the demo fallback)
  final String name;
  final String rollNo;
  final String department;
  final String boardingStop;
  final double homeLat;
  final double homeLng;
  final String busId;
  final String busNumber;
  final String routeName;
  final String guardianMasked;
  final String riderType; // 'student' | 'teacher'
  final String? stopId;
  final int leadStops;

  const Student({
    required this.id,
    required this.name,
    required this.rollNo,
    required this.department,
    required this.boardingStop,
    required this.homeLat,
    required this.homeLng,
    required this.busId,
    required this.busNumber,
    required this.routeName,
    required this.guardianMasked,
    this.riderType = 'student',
    this.stopId,
    this.leadStops = 2,
  });

  bool get isTeacher => riderType == 'teacher';
}
