/// A driver / staff profile. Demo values are hard-coded in AuthService;
/// in production they'd come from a `staff` table keyed by staff id.
class Staff {
  final String staffId;
  final String name;
  final String busId;
  final String busNumber;
  final String routeName;

  const Staff({
    required this.staffId,
    required this.name,
    required this.busId,
    required this.busNumber,
    required this.routeName,
  });
}
