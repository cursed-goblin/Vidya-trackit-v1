import 'package:flutter/material.dart';

import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'role_select_screen.dart';

/// Transport-office screen.
///
/// Tab 1 "Riders": add / delete riders and filter students vs teachers.
/// Tab 2 "On bus": live counts of who boarded the current trip.
///
/// Drivers get the same screen in read/tick-only mode ([canManage] = false) so
/// they can mark boardings without being able to add or delete anyone.
class AdminScreen extends StatefulWidget {
  final String busId;
  final bool canManage;
  const AdminScreen({super.key, required this.busId, this.canManage = true});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<RosterEntry> _all = const [];
  List<BusStop> _stops = const [];
  String _filter = 'all'; // all | student | teacher
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final roster = await AdminService.instance.roster(widget.busId);
      final stops = await AdminService.instance.stopsForBus(widget.busId);
      if (!mounted) return;
      setState(() {
        _all = roster;
        _stops = stops;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  List<RosterEntry> get _visible => _filter == 'all'
      ? _all
      : _all.where((r) => r.riderType == _filter).toList();

  Future<void> _toggleOnBus(RosterEntry r, bool value) async {
    try {
      await AdminService.instance.setOnBus(r.profileId, value);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: kRed, content: Text('$e')),
      );
    }
  }

  Future<void> _confirmDelete(RosterEntry r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Remove rider?'),
        content: Text('${r.name} will lose access and be removed from this '
            'bus. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Remove', style: TextStyle(color: kRed))),
        ],
      ),
    );
    if (ok != true) return;
    final err = await AdminService.instance.deleteRider(r.profileId);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(backgroundColor: kRed, content: Text(err)));
      return;
    }
    await _load();
  }

  Future<void> _addRider() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddRiderSheet(busId: widget.busId, stops: _stops),
    );
    if (added == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final onBus = _all.where((r) => r.onBus).length;
    final students = _all.where((r) => !r.isTeacher).length;
    final teachers = _all.length - students;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: kAppBg,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          title: Text(widget.canManage ? 'Admin - ${widget.busId}' : 'Roster',
              style: const TextStyle(
                  color: kHeading, fontWeight: FontWeight.w700)),
          actions: [
            IconButton(
                tooltip: 'Refresh',
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, color: kSub)),
            IconButton(
              tooltip: 'Logout',
              onPressed: () async {
                await AuthService.instance.logout();
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const RoleSelectScreen()),
                  (r) => false,
                );
              },
              icon: const Icon(Icons.logout_rounded, color: kSub),
            ),
          ],
          bottom: const TabBar(
            labelColor: kPurple,
            unselectedLabelColor: kSub,
            indicatorColor: kPurple,
            tabs: [Tab(text: 'Riders'), Tab(text: 'On bus')],
          ),
        ),
        floatingActionButton: widget.canManage
            ? FloatingActionButton.extended(
                backgroundColor: kPurple,
                foregroundColor: Colors.white,
                onPressed: _addRider,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Add rider'),
              )
            : null,
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorState(message: _error!, onRetry: _load)
                : TabBarView(
                    children: [
                      _ridersTab(students, teachers),
                      _onBusTab(onBus),
                    ],
                  ),
      ),
    );
  }

  Widget _ridersTab(int students, int teachers) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Row(
            children: [
              _chip('All (${_all.length})', 'all'),
              const SizedBox(width: 8),
              _chip('Students ($students)', 'student'),
              const SizedBox(width: 8),
              _chip('Teachers ($teachers)', 'teacher'),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: _visible.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final r = _visible[i];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: kBorder),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: (r.isTeacher ? kAmber : kPurple)
                            .withValues(alpha: 0.12),
                        child: Icon(
                            r.isTeacher
                                ? Icons.co_present_rounded
                                : Icons.school_rounded,
                            size: 20,
                            color: r.isTeacher ? kAmber : kPurple),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.name,
                                style: const TextStyle(
                                    color: kHeading,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text('${r.rollNo} - ${r.stopName}',
                                style: const TextStyle(
                                    color: kSub, fontSize: 12.5)),
                          ],
                        ),
                      ),
                      StatusPill(
                        text: r.onBus ? 'On bus' : 'Not on bus',
                        color: r.onBus ? kGreen : kSub,
                      ),
                      if (widget.canManage)
                        IconButton(
                          tooltip: 'Remove',
                          onPressed: () => _confirmDelete(r),
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: kRed),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _onBusTab(int onBus) {
    final notOnBus = _all.length - onBus;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(child: _kpi('On bus', '$onBus', kGreen)),
              const SizedBox(width: 12),
              Expanded(child: _kpi('Not on bus', '$notOnBus', kSub)),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            itemCount: _all.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final r = _all[i];
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kBorder),
                ),
                child: SwitchListTile(
                  activeThumbColor: kGreen,
                  value: r.onBus,
                  onChanged: (v) => _toggleOnBus(r, v),
                  title: Text(r.name,
                      style: const TextStyle(
                          color: kHeading, fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      '${r.isTeacher ? 'Teacher' : 'Student'} - ${r.stopName}',
                      style: const TextStyle(color: kSub, fontSize: 12.5)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _chip(String label, String value) {
    final sel = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: sel ? kPurple : kPurple.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label,
            style: TextStyle(
                color: sel ? Colors.white : kPurpleDark,
                fontSize: 12.5,
                fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _kpi(String label, String value, Color color) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 30, fontWeight: FontWeight.w800)),
            const Text(label_placeholder_unused,
                style: TextStyle(color: kSub, fontSize: 12.5)),
          ],
        ),
      );
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, color: kSub, size: 42),
              const SizedBox(height: 12),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: kSub, fontSize: 13)),
              const SizedBox(height: 18),
              TextButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ),
        ),
      );
}

class _AddRiderSheet extends StatefulWidget {
  final String busId;
  final List<BusStop> stops;
  const _AddRiderSheet({required this.busId, required this.stops});
  @override
  State<_AddRiderSheet> createState() => _AddRiderSheetState();
}

class _AddRiderSheetState extends State<_AddRiderSheet> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _roll = TextEditingController();
  String _type = 'student';
  String? _stopId;
  int _lead = 2;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _roll.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty ||
        _email.text.trim().isEmpty ||
        _password.text.length < 6) {
      setState(() => _error =
          'Name, email and a password of at least 6 characters are required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final err = await AdminService.instance.addRider(
      email: _email.text.trim(),
      password: _password.text,
      fullName: _name.text.trim(),
      riderType: _type,
      busId: widget.busId,
      rollNo: _roll.text.trim().isEmpty ? null : _roll.text.trim(),
      stopId: _stopId,
      leadStops: _lead,
    );
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _saving = false;
        _error = err;
      });
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                      color: kBorder, borderRadius: BorderRadius.circular(3)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Add rider',
                  style: TextStyle(
                      color: kHeading,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text(
                  'Students and teachers use the same app; the type below is '
                  'only used for admin filters and counts.',
                  style: TextStyle(color: kSub, fontSize: 12.5)),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'student', label: Text('Student')),
                  ButtonSegment(value: 'teacher', label: Text('Teacher')),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
              const SizedBox(height: 14),
              _field(_name, 'Full name', Icons.person_outline_rounded),
              const SizedBox(height: 10),
              _field(_email, 'Login email', Icons.mail_outline_rounded),
              const SizedBox(height: 10),
              _field(_password, 'Temporary password',
                  Icons.lock_outline_rounded),
              const SizedBox(height: 10),
              _field(_roll, 'Roll no / staff id (optional)',
                  Icons.badge_outlined),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _stopId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Boarding stop',
                  border: OutlineInputBorder(),
                ),
                items: widget.stops
                    .map((s) => DropdownMenuItem(
                        value: s.id, child: Text('${s.seq}. ${s.name}')))
                    .toList(),
                onChanged: (v) => setState(() => _stopId = v),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Expanded(
                    child: Text('Alarm this many stops early',
                        style: TextStyle(color: kSub, fontSize: 13)),
                  ),
                  DropdownButton<int>(
                    value: _lead,
                    items: const [1, 2, 3]
                        .map((n) =>
                            DropdownMenuItem(value: n, child: Text('$n')))
                        .toList(),
                    onChanged: (v) => setState(() => _lead = v ?? 2),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!,
                    style: const TextStyle(
                        color: kRed,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 18),
              GradientButton(
                  label: 'Add rider', loading: _saving, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon) =>
      TextField(
        controller: c,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          border: const OutlineInputBorder(),
        ),
      );
}
