import '../config.dart';
import '../models/staff.dart';
import '../models/student.dart';

/// Demo authentication. Holds the currently logged-in student or staff member.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  Student? student;
  Staff? staff;

  // ----- STUDENT (passenger) demo login -----
  // DEMO ONLY: accepts any non-empty credentials so the prototype is easy to
  // show. Replace with real Firebase Auth before any deployment.
  Student loginStudentDemo() {
    student = const Student(
      id: 'TL2024CS118',
      name: 'Rahul Menon',
      rollNo: 'VEC-CS-118',
      department: 'Computer Science',
      boardingStop: 'Punkunnam',
      homeLat: kFallbackHomeLat,
      homeLng: kFallbackHomeLng,
      busId: kDemoBusId,
      busNumber: 'KL-08 AV 4412',
      routeName: 'Route 12 - Thrissur Town to Vidya Engineering College',
      guardianMasked: '+91 98****43',
    );
    return student!;
  }

  // ----- STAFF (driver) login -----
  // DEMO ONLY credential. MUST be replaced with real Firebase Auth / a secure
  // staff directory before any real deployment. Never ship a hard-coded
  // password in production.
  static const String _demoStaffId = 'driver01';
  static const String _demoStaffPass = 'pass123';

  Staff? loginStaff(String id, String password) {
    if (id.trim() == _demoStaffId && password == _demoStaffPass) {
      staff = const Staff(
        staffId: _demoStaffId,
        name: 'Suresh K',
        busId: kDemoBusId,
        busNumber: 'KL-08 AV 4412',
        routeName: 'Route 12 - Thrissur Town to Vidya Engineering College',
      );
      return staff;
    }
    return null;
  }

  void logout() {
    student = null;
    staff = null;
  }
}
