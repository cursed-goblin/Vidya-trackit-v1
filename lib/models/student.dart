/// A passenger (student) profile. In the demo these values are hard-coded in
/// AuthService; in production they'd be loaded from the `students` table.
class Student {
  final String id; // college / TL id
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
  });
}
