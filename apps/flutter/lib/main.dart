import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'receipt_file.dart';

const accent = Color(0xFF5B48C8);
const ink = Color(0xFF202520);
const muted = Color(0xFF626960);
const pageBackground = Color(0xFFF8F9F7);
const positive = Color(0xFF287454);
const attention = Color(0xFFA95416);
const danger = Color(0xFFB63838);

void main() => runApp(const SrcSchoolApp());

class SrcSchoolApp extends StatelessWidget {
  const SrcSchoolApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme =
        ColorScheme.fromSeed(seedColor: accent, brightness: Brightness.light);
    return MaterialApp(
      title: 'SRC SCHOOL',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: pageBackground,
        fontFamily: 'Arial',
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
              color: ink, fontWeight: FontWeight.w700, letterSpacing: -0.8),
          titleLarge: TextStyle(color: ink, fontWeight: FontWeight.w700),
          bodyLarge: TextStyle(color: ink),
          bodyMedium: TextStyle(color: muted),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE3E6E0))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE3E6E0))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: accent, width: 1.5)),
        ),
      ),
      home: const LoginPage(),
    );
  }
}

class Api {
  final storage = const FlutterSecureStorage();
  final base = const String.fromEnvironment('API_URL',
      defaultValue: 'http://127.0.0.1:8010/api/v1');

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(Uri.parse('$base/auth/login'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'email': email.trim(), 'password': password}));
    if (response.statusCode >= 300) throw Exception('Identifiants incorrects.');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    await storage.write(
        key: 'access_token', value: data['access_token'] as String?);
    return data;
  }

  Future<dynamic> get(String path) async {
    final token = await storage.read(key: 'access_token');
    final response = await http.get(Uri.parse('$base$path'),
        headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode >= 300)
      throw Exception('Impossible de charger ces données.');
    return jsonDecode(response.body);
  }

  Future<dynamic> post(String path, Map<String, dynamic> body,
      {String? idempotencyKey}) async {
    final token = await storage.read(key: 'access_token');
    final headers = <String, String>{
      'Authorization': 'Bearer $token',
      'content-type': 'application/json',
    };
    if (idempotencyKey != null) headers['Idempotency-Key'] = idempotencyKey;
    final response = await http.post(Uri.parse('$base$path'),
        headers: headers, body: jsonEncode(body));
    if (response.statusCode >= 300) {
      final decoded = jsonDecode(response.body);
      throw Exception(decoded['error']?['message'] ?? 'Opération refusée.');
    }
    return jsonDecode(response.body);
  }

  Future<dynamic> put(String path, Map<String, dynamic> body) async {
    final token = await storage.read(key: 'access_token');
    final response = await http.put(Uri.parse('$base$path'),
        headers: {
          'Authorization': 'Bearer $token',
          'content-type': 'application/json',
        },
        body: jsonEncode(body));
    if (response.statusCode >= 300) {
      final decoded = jsonDecode(response.body);
      throw Exception(decoded['error']?['message'] ?? 'Opération refusée.');
    }
    return jsonDecode(response.body);
  }

  Future<dynamic> patch(String path, Map<String, dynamic> body) async {
    final token = await storage.read(key: 'access_token');
    final response = await http.patch(Uri.parse('$base$path'),
        headers: {
          'Authorization': 'Bearer $token',
          'content-type': 'application/json',
        },
        body: jsonEncode(body));
    if (response.statusCode >= 300) {
      final decoded = jsonDecode(response.body);
      throw Exception(decoded['error']?['message'] ?? 'Opération refusée.');
    }
    return jsonDecode(response.body);
  }

  Future<List<int>> download(String path) async {
    final token = await storage.read(key: 'access_token');
    final response = await http.get(Uri.parse('$base$path'),
        headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode >= 300) {
      throw Exception('Impossible de télécharger le reçu.');
    }
    return response.bodyBytes;
  }

  Future<void> logout() async {
    final token = await storage.read(key: 'access_token');
    await http.post(Uri.parse('$base/auth/logout'),
        headers: {'Authorization': 'Bearer $token'});
    await storage.delete(key: 'access_token');
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final api = Api();
  final email = TextEditingController(text: 'admin@src.demo');
  final password = TextEditingController();
  String? error;
  bool busy = false;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final data = await api.login(email.text, password.text);
      final memberships = data['memberships'] as List<dynamic>? ?? [];
      final membership = memberships.isNotEmpty
          ? memberships.first as Map<String, dynamic>
          : const <String, dynamic>{};
      if (mounted)
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => HomePage(
                    user: data['user'] as Map<String, dynamic>,
                    schoolName: membership['school_name'] as String? ??
                        'Établissement')));
    } catch (exception) {
      if (mounted)
        setState(
            () => error = exception.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              elevation: 0,
              margin: const EdgeInsets.all(24),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: Color(0xFFE3E6E0))),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: AutofillGroup(
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('SRC SCHOOL',
                            style: TextStyle(
                                color: accent,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2)),
                        const SizedBox(height: 8),
                        Text('Votre espace scolaire',
                            style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 8),
                        const Text(
                            'Connectez-vous pour gérer votre établissement.',
                            style: TextStyle(color: muted)),
                        const SizedBox(height: 28),
                        TextField(
                            controller: email,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.username],
                            decoration:
                                const InputDecoration(labelText: 'Email')),
                        const SizedBox(height: 14),
                        TextField(
                            controller: password,
                            obscureText: true,
                            autofillHints: const [AutofillHints.password],
                            onSubmitted: (_) => submit(),
                            decoration: const InputDecoration(
                                labelText: 'Mot de passe')),
                        if (error != null) ...[
                          const SizedBox(height: 14),
                          Text(error!, style: const TextStyle(color: danger))
                        ],
                        const SizedBox(height: 24),
                        FilledButton(
                            onPressed: busy ? null : submit,
                            style: FilledButton.styleFrom(
                                backgroundColor: ink,
                                minimumSize: const Size.fromHeight(48)),
                            child: busy
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Text('Se connecter')),
                      ]),
                ),
              ),
            ),
          ),
        ),
      );
}

class NavItem {
  const NavItem(this.label, this.icon, this.kind);
  final String label;
  final IconData icon;
  final String kind;
}

class HomePage extends StatefulWidget {
  const HomePage(
      {super.key, required this.user, this.schoolName = 'Établissement'});
  final Map<String, dynamic> user;
  final String schoolName;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final api = Api();
  int index = 0;
  bool get teacher => widget.user['role'] == 'teacher';
  String get schoolId => widget.user['school_id'] as String? ?? '';

  List<NavItem> get items {
    if (teacher)
      return const [
        NavItem('Aujourd’hui', Icons.today_outlined, 'today'),
        NavItem('Classes', Icons.class_outlined, 'classes'),
        NavItem('Présences', Icons.fact_check_outlined, 'attendance'),
        NavItem('Notes', Icons.school_outlined, 'assessments'),
        NavItem('Devoirs', Icons.assignment_outlined, 'assignments'),
        NavItem('Notifications', Icons.notifications_none, 'notifications')
      ];
    final result = [
      const NavItem('Tableau de bord', Icons.dashboard_outlined, 'dashboard'),
      const NavItem('Élèves', Icons.people_outline, 'students'),
      const NavItem('Classes', Icons.class_outlined, 'classes'),
      const NavItem('Équipe', Icons.badge_outlined, 'teachers'),
      const NavItem(
          'Affectations', Icons.account_tree_outlined, 'assignments-admin'),
      const NavItem('Présences', Icons.fact_check_outlined, 'attendance'),
      const NavItem(
          'Notes et évaluations', Icons.school_outlined, 'assessments'),
      const NavItem('Bulletins', Icons.description_outlined, 'report-cards'),
      const NavItem('Communications', Icons.forum_outlined, 'communications'),
      const NavItem('Paramètres', Icons.settings_outlined, 'settings')
    ];
    if (widget.user['role'] == 'admin' || widget.user['role'] == 'accountant')
      result.add(const NavItem(
          'Finances', Icons.account_balance_wallet_outlined, 'finance'));
    return result;
  }

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 800;
        final current = items[index.clamp(0, items.length - 1)];
        final content = _page(current);
        if (!desktop)
          return Scaffold(
              appBar: AppBar(title: Text(current.label)),
              body: Padding(padding: const EdgeInsets.all(20), child: content),
              bottomNavigationBar: NavigationBar(
                  selectedIndex: index.clamp(0, 3),
                  onDestinationSelected: (value) =>
                      setState(() => index = value),
                  destinations: items
                      .take(4)
                      .map((item) => NavigationDestination(
                          icon: Icon(item.icon), label: item.label))
                      .toList()));
        return Scaffold(
            body: Row(children: [
          _Sidebar(
              user: widget.user,
              items: items,
              selected: index,
              onSelected: (value) => setState(() => index = value),
              onLogout: _logout),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(
              child: Column(children: [
            _TopBar(title: current.label, schoolName: widget.schoolName),
            Expanded(
                child: Padding(
                    padding: const EdgeInsets.fromLTRB(32, 28, 32, 32),
                    child: content))
          ]))
        ]));
      });

  Widget _page(NavItem item) {
    switch (item.kind) {
      case 'dashboard':
        return DashboardPage(api: api, schoolId: schoolId, user: widget.user);
      case 'finance':
        return FinancePage(api: api, schoolId: schoolId);
      case 'today':
        return TodayPage(user: widget.user);
      case 'assignments-admin':
        return TeachingAssignmentsPage(api: api, schoolId: schoolId);
      case 'attendance':
        return AttendancePage(api: api, schoolId: schoolId);
      case 'assessments':
        return AssessmentsPage(
            api: api,
            schoolId: schoolId,
            role: widget.user['role'] as String? ?? 'teacher');
      case 'report-cards':
        return ReportCardsPage(
            api: api,
            schoolId: schoolId,
            role: widget.user['role'] as String? ?? 'teacher');
      case 'communications':
        return CommunicationsPage(api: api, schoolId: schoolId);
      case 'settings':
        return SettingsPage(
            api: api,
            schoolId: schoolId,
            canEdit: widget.user['role'] == 'admin');
      default:
        return RecordsPage(
            api: api,
            schoolId: schoolId,
            kind: item.kind,
            title: item.label,
            role: widget.user['role'] as String? ?? 'teacher');
    }
  }

  Future<void> _logout() async {
    await api.logout();
    if (mounted)
      Navigator.pushAndRemoveUntil(context,
          MaterialPageRoute(builder: (_) => const LoginPage()), (_) => false);
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar(
      {required this.user,
      required this.items,
      required this.selected,
      required this.onSelected,
      required this.onLogout});
  final Map<String, dynamic> user;
  final List<NavItem> items;
  final int selected;
  final ValueChanged<int> onSelected;
  final VoidCallback onLogout;
  @override
  Widget build(BuildContext context) => SizedBox(
      width: 248,
      child: ColoredBox(
          color: Colors.white,
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 28),
                        child: Text('SRC SCHOOL',
                            style: TextStyle(
                                color: accent,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1))),
                    Expanded(
                        child: ListView.separated(
                            itemCount: items.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 4),
                            itemBuilder: (context, i) {
                              final item = items[i];
                              final active = selected == i;
                              return Semantics(
                                  button: true,
                                  selected: active,
                                  label: item.label,
                                  child: ListTile(
                                      leading: Icon(item.icon,
                                          color: active ? accent : muted),
                                      title: Text(item.label,
                                          style: TextStyle(
                                              color: active ? ink : muted,
                                              fontWeight: active
                                                  ? FontWeight.w600
                                                  : FontWeight.w400)),
                                      selected: active,
                                      selectedTileColor:
                                          const Color(0xFFF0ECFF),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      onTap: () => onSelected(i)));
                            })),
                    const Divider(height: 32),
                    ListTile(
                        leading: const Icon(Icons.logout, color: muted),
                        title: const Text('Se déconnecter'),
                        onTap: onLogout),
                    const SizedBox(height: 12),
                    ListTile(
                        leading: CircleAvatar(
                            backgroundColor: const Color(0xFFF0ECFF),
                            child: Text(
                                ((user['name'] as String? ?? 'S')
                                        .substring(0, 1))
                                    .toUpperCase(),
                                style: const TextStyle(
                                    color: accent,
                                    fontWeight: FontWeight.bold))),
                        title: Text(user['name'] as String? ?? 'Utilisateur',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                            _roleLabel(user['role'] as String? ?? ''),
                            style:
                                const TextStyle(color: muted, fontSize: 12))),
                  ]))));
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.schoolName});
  final String title;
  final String schoolName;
  @override
  Widget build(BuildContext context) => Container(
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: 32),
        decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE3E6E0)))),
        child: Row(children: [
          Text(schoolName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: muted)),
          const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Icon(Icons.chevron_right, size: 18, color: muted)),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          const Text('2026–2027', style: TextStyle(color: muted)),
          const SizedBox(width: 24),
          IconButton(
              tooltip: 'Notifications',
              onPressed: () {},
              icon: const Icon(Icons.notifications_none, color: muted)),
        ]),
      );
}

class DashboardPage extends StatelessWidget {
  const DashboardPage(
      {super.key,
      required this.api,
      required this.schoolId,
      required this.user});
  final Api api;
  final String schoolId;
  final Map<String, dynamic> user;
  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
      future: api
          .get('/schools/$schoolId/dashboard')
          .then((data) => data as Map<String, dynamic>),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const LoadingState();
        if (snapshot.hasError)
          return ErrorState(message: snapshot.error.toString());
        final data = snapshot.data!;
        final admin = user['role'] == 'admin' || user['role'] == 'accountant';
        return ListView(children: [
          PageIntro(
              eyebrow: data['demonstration'] == true
                  ? 'DÉMONSTRATION'
                  : 'ESPACE ÉCOLE',
              title:
                  'Bonjour, ${(user['name'] as String? ?? 'équipe').split(' ').first}',
              subtitle:
                  data['school']?['name'] as String? ?? 'Votre établissement'),
          const SizedBox(height: 28),
          Wrap(spacing: 16, runSpacing: 16, children: [
            MetricCard(
                label: 'Élèves inscrits',
                value: '${data['students'] ?? 0}',
                icon: Icons.people_outline,
                color: accent),
            MetricCard(
                label: 'Classes',
                value: '${data['classes'] ?? 0}',
                icon: Icons.class_outlined,
                color: positive),
            MetricCard(
                label: 'Présences',
                value: '${data['attendance_count'] ?? 0}',
                icon: Icons.fact_check_outlined,
                color: attention),
            if (admin)
              MetricCard(
                  label: 'Encaissé',
                  value: '${_money(data['paid'])} FCFA',
                  icon: Icons.payments_outlined,
                  color: positive)
          ]),
          const SizedBox(height: 24),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: AppCard(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                  const SectionTitle(
                      title: 'Aujourd’hui', action: 'Voir les présences'),
                  const SizedBox(height: 24),
                  const EmptyLine(
                      icon: Icons.calendar_today_outlined,
                      title: 'Aucune séance planifiée',
                      subtitle: 'Les activités de la journée apparaîtront ici.')
                ]))),
            const SizedBox(width: 20),
            SizedBox(
                width: 300,
                child: AppCard(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const SectionTitle(title: 'À surveiller'),
                      const SizedBox(height: 20),
                      StatusLine(
                          label: 'Élèves actifs',
                          value: '${data['students'] ?? 0}',
                          color: positive),
                      StatusLine(
                          label: 'Solde restant',
                          value: '${_money(data['outstanding'])} FCFA',
                          color: attention),
                      StatusLine(
                          label: 'École',
                          value:
                              data['demonstration'] == true ? 'Démo' : 'Active',
                          color: accent)
                    ])))
          ]),
        ]);
      });
}

class TodayPage extends StatelessWidget {
  const TodayPage({super.key, required this.user});
  final Map<String, dynamic> user;
  @override
  Widget build(BuildContext context) => ListView(children: [
        PageIntro(
            eyebrow: 'ENSEIGNEMENT',
            title:
                'Bonjour, ${(user['name'] as String? ?? 'enseignant').split(' ').first}',
            subtitle: 'Retrouvez votre journée et vos classes.'),
        const SizedBox(height: 24),
        const AppCard(
            child: EmptyLine(
                icon: Icons.calendar_today_outlined,
                title: 'Votre journée est prête',
                subtitle: 'Les cours et présences affectés apparaîtront ici.'))
      ]);
}

class FinancePage extends StatefulWidget {
  const FinancePage({super.key, required this.api, required this.schoolId});
  final Api api;
  final String schoolId;

  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  late Future<Map<String, dynamic>> financeFuture;
  late Future<List<dynamic>> studentsFuture;
  late Future<List<dynamic>> paymentsFuture;
  late Future<List<dynamic>> chargesFuture;
  Future<Map<String, dynamic>>? accountFuture;
  final amountController = TextEditingController();
  final chargeAmountController = TextEditingController();
  final chargeNameController = TextEditingController(text: 'Scolarité');
  final chargeDueDateController = TextEditingController();
  String? selectedStudent;
  String method = 'cash';
  String? feedback;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    financeFuture = widget.api
        .get('/schools/${widget.schoolId}/finance/dashboard')
        .then((data) => data as Map<String, dynamic>);
    studentsFuture = widget.api
        .get('/schools/${widget.schoolId}/students')
        .then((data) =>
            (data as Map<String, dynamic>)['items'] as List<dynamic>? ?? []);
    paymentsFuture = widget.api
        .get('/schools/${widget.schoolId}/payments')
        .then((data) =>
            (data as Map<String, dynamic>)['items'] as List<dynamic>? ?? []);
    chargesFuture = widget.api.get('/schools/${widget.schoolId}/charges').then(
        (data) =>
            (data as Map<String, dynamic>)['items'] as List<dynamic>? ?? []);
  }

  @override
  void dispose() {
    amountController.dispose();
    chargeAmountController.dispose();
    chargeNameController.dispose();
    chargeDueDateController.dispose();
    super.dispose();
  }

  Future<void> _submitCharge() async {
    final amount = int.tryParse(chargeAmountController.text.trim());
    if (selectedStudent == null) {
      setState(() => feedback = 'Sélectionnez un élève pour créer les frais.');
      return;
    }
    if (amount == null || amount <= 0) {
      setState(() => feedback = 'Le montant des frais doit être positif.');
      return;
    }
    setState(() {
      busy = true;
      feedback = null;
    });
    try {
      await widget.api.post('/schools/${widget.schoolId}/charges', {
        'student_id': selectedStudent,
        'amount': amount,
        'name': chargeNameController.text.trim().isEmpty
            ? 'Frais scolaires'
            : chargeNameController.text.trim(),
        if (chargeDueDateController.text.trim().isNotEmpty)
          'due_date': chargeDueDateController.text.trim(),
      });
      if (!mounted) return;
      setState(() {
        feedback = 'Frais ajoutés au compte de l’élève.';
        chargeAmountController.clear();
        chargesFuture = widget.api
            .get('/schools/${widget.schoolId}/charges')
            .then((data) =>
                (data as Map<String, dynamic>)['items'] as List<dynamic>? ??
                []);
        financeFuture = widget.api
            .get('/schools/${widget.schoolId}/finance/dashboard')
            .then((data) => data as Map<String, dynamic>);
      });
    } catch (exception) {
      if (mounted)
        setState(() =>
            feedback = exception.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _submitPayment() async {
    final amount = int.tryParse(amountController.text.trim());
    if (selectedStudent == null) {
      setState(() => feedback = 'Sélectionnez un élève.');
      return;
    }
    if (amount == null || amount <= 0) {
      setState(
          () => feedback = 'Le montant doit être un entier positif en FCFA.');
      return;
    }
    setState(() {
      busy = true;
      feedback = null;
    });
    try {
      final result = await widget.api.post(
        '/schools/${widget.schoolId}/payments',
        {
          'student_id': selectedStudent,
          'amount': amount,
          'currency': 'XOF',
          'method': method,
        },
        idempotencyKey: 'desktop-${DateTime.now().microsecondsSinceEpoch}',
      );
      if (!mounted) return;
      setState(() {
        feedback = 'Paiement confirmé · reçu ${result['receipt_number'] ?? ''}';
        amountController.clear();
        financeFuture = widget.api
            .get('/schools/${widget.schoolId}/finance/dashboard')
            .then((data) => data as Map<String, dynamic>);
        paymentsFuture = widget.api
            .get('/schools/${widget.schoolId}/payments')
            .then((data) =>
                (data as Map<String, dynamic>)['items'] as List<dynamic>? ??
                []);
        chargesFuture = widget.api
            .get('/schools/${widget.schoolId}/charges')
            .then((data) =>
                (data as Map<String, dynamic>)['items'] as List<dynamic>? ??
                []);
      });
    } catch (exception) {
      if (mounted)
        setState(() =>
            feedback = exception.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _reversePayment(Map<String, dynamic> payment) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler le paiement ?'),
        content: TextField(
          controller: reasonController,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
              labelText: 'Motif obligatoire', hintText: 'Ex. erreur de caisse'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Retour')),
          FilledButton(
              onPressed: () => Navigator.pop(context, reasonController.text),
              style: FilledButton.styleFrom(backgroundColor: danger),
              child: const Text('Annuler le paiement')),
        ],
      ),
    );
    reasonController.dispose();
    if (reason == null || reason.trim().isEmpty) return;
    setState(() {
      busy = true;
      feedback = null;
    });
    try {
      await widget.api.post(
        '/schools/${widget.schoolId}/payments/${payment['id']}/reverse',
        {'reason': reason.trim()},
        idempotencyKey:
            'reverse-${payment['id']}-${DateTime.now().microsecondsSinceEpoch}',
      );
      if (mounted) {
        setState(() {
          feedback = 'Paiement annulé et conservé dans l’historique.';
          _reload();
        });
      }
    } catch (exception) {
      if (mounted)
        setState(() =>
            feedback = exception.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _openReceipt(Map<String, dynamic> payment) async {
    final receiptId = payment['receipt_id'] as String?;
    if (receiptId == null || receiptId.isEmpty) {
      setState(() => feedback = 'Reçu indisponible pour ce paiement.');
      return;
    }
    setState(() {
      busy = true;
      feedback = null;
    });
    try {
      final bytes = await widget.api
          .download('/schools/${widget.schoolId}/receipts/$receiptId/download');
      await saveAndOpenReceipt(bytes,
          'src-school-recu-${payment['receipt_number'] ?? payment['id']}.pdf');
      if (mounted)
        setState(() => feedback = 'Reçu ouvert depuis Téléchargements.');
    } catch (exception) {
      if (mounted) {
        setState(() =>
            feedback = exception.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
      future: financeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const LoadingState();
        if (snapshot.hasError)
          return ErrorState(message: snapshot.error.toString());
        final data = snapshot.data!;
        return ListView(children: [
          PageIntro(
              eyebrow: 'GESTION',
              title: 'Finances',
              subtitle: 'Suivi des encaissements et des soldes en FCFA.'),
          const SizedBox(height: 28),
          Wrap(spacing: 16, runSpacing: 16, children: [
            MetricCard(
                label: 'Total facturé',
                value: '${_money(data['charged'])} FCFA',
                icon: Icons.receipt_long_outlined,
                color: accent),
            MetricCard(
                label: 'Encaissé',
                value: '${_money(data['paid'])} FCFA',
                icon: Icons.payments_outlined,
                color: positive),
            MetricCard(
                label: 'Reste à recouvrer',
                value: '${_money(data['outstanding'])} FCFA',
                icon: Icons.schedule_outlined,
                color: attention),
            MetricCard(
                label: 'Recouvrement',
                value: '${data['collection_rate'] ?? 0} %',
                icon: Icons.trending_up,
                color: positive)
          ]),
          const SizedBox(height: 24),
          FutureBuilder<List<dynamic>>(
              future: studentsFuture,
              builder: (context, studentsSnapshot) {
                if (studentsSnapshot.connectionState != ConnectionState.done) {
                  return const AppCard(child: LoadingState());
                }
                if (studentsSnapshot.hasError) {
                  return ErrorState(message: studentsSnapshot.error.toString());
                }
                final students = studentsSnapshot.data ?? [];
                return AppCard(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const SectionTitle(title: 'Enregistrer un paiement'),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        initialValue: selectedStudent,
                        decoration: const InputDecoration(labelText: 'Élève'),
                        items: students.map((raw) {
                          final student = raw as Map<String, dynamic>;
                          return DropdownMenuItem<String>(
                              value: student['id'] as String,
                              child: Text(
                                  '${student['first_name'] ?? ''} ${student['last_name'] ?? ''}'));
                        }).toList(),
                        onChanged: busy
                            ? null
                            : (value) =>
                                setState(() => selectedStudent = value),
                      ),
                      const SizedBox(height: 14),
                      Row(children: [
                        Expanded(
                            child: TextField(
                                controller: amountController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    labelText: 'Montant', suffixText: 'FCFA'))),
                        const SizedBox(width: 14),
                        Expanded(
                            child: DropdownButtonFormField<String>(
                                initialValue: method,
                                decoration:
                                    const InputDecoration(labelText: 'Moyen'),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'cash', child: Text('Espèces')),
                                  DropdownMenuItem(
                                      value: 'bank_transfer',
                                      child: Text('Virement')),
                                  DropdownMenuItem(
                                      value: 'mobile_money',
                                      child: Text('Mobile Money')),
                                  DropdownMenuItem(
                                      value: 'other', child: Text('Autre'))
                                ],
                                onChanged: busy
                                    ? null
                                    : (value) => setState(
                                        () => method = value ?? 'cash'))),
                      ]),
                      if (feedback != null) ...[
                        const SizedBox(height: 14),
                        Text(feedback!,
                            style: TextStyle(
                                color: feedback!.startsWith('Paiement')
                                    ? positive
                                    : danger,
                                fontWeight: FontWeight.w600))
                      ],
                      const SizedBox(height: 18),
                      Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                              onPressed: busy || students.isEmpty
                                  ? null
                                  : _submitPayment,
                              icon: busy
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.check, size: 18),
                              label: const Text('Confirmer le paiement'),
                              style: FilledButton.styleFrom(
                                  backgroundColor: ink))),
                    ]));
              }),
          const SizedBox(height: 24),
          FutureBuilder<List<dynamic>>(
              future: studentsFuture,
              builder: (context, studentsSnapshot) {
                if (studentsSnapshot.connectionState != ConnectionState.done) {
                  return const AppCard(child: LoadingState());
                }
                if (studentsSnapshot.hasError) {
                  return ErrorState(message: studentsSnapshot.error.toString());
                }
                final students = studentsSnapshot.data ?? [];
                return AppCard(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const SectionTitle(title: 'Ajouter des frais scolaires'),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                          initialValue: selectedStudent,
                          decoration: const InputDecoration(labelText: 'Élève'),
                          items: students.map((raw) {
                            final student = raw as Map<String, dynamic>;
                            return DropdownMenuItem<String>(
                                value: student['id'] as String,
                                child: Text(
                                    '${student['first_name'] ?? ''} ${student['last_name'] ?? ''}'));
                          }).toList(),
                          onChanged: busy
                              ? null
                              : (value) => setState(() {
                                    selectedStudent = value;
                                    accountFuture = value == null
                                        ? null
                                        : widget.api
                                            .get(
                                                '/schools/${widget.schoolId}/students/$value/account')
                                            .then((data) =>
                                                data as Map<String, dynamic>);
                                  })),
                      const SizedBox(height: 14),
                      Row(children: [
                        Expanded(
                            child: TextField(
                                controller: chargeNameController,
                                decoration: const InputDecoration(
                                    labelText: 'Libellé'))),
                        const SizedBox(width: 14),
                        Expanded(
                            child: TextField(
                                controller: chargeAmountController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    labelText: 'Montant', suffixText: 'FCFA'))),
                      ]),
                      const SizedBox(height: 14),
                      TextField(
                          controller: chargeDueDateController,
                          decoration: const InputDecoration(
                              labelText: 'Échéance', hintText: 'AAAA-MM-JJ')),
                      const SizedBox(height: 18),
                      Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                              onPressed: busy || students.isEmpty
                                  ? null
                                  : _submitCharge,
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Créer les frais'))),
                    ]));
              }),
          const SizedBox(height: 24),
          FutureBuilder<List<dynamic>>(
              future: paymentsFuture,
              builder: (context, paymentsSnapshot) {
                if (paymentsSnapshot.connectionState != ConnectionState.done) {
                  return const AppCard(child: LoadingState());
                }
                if (paymentsSnapshot.hasError) {
                  return ErrorState(message: paymentsSnapshot.error.toString());
                }
                final payments = paymentsSnapshot.data ?? [];
                return AppCard(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const SectionTitle(title: 'Historique des paiements'),
                      const SizedBox(height: 16),
                      if (feedback != null)
                        Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(feedback!,
                                style: TextStyle(
                                    color: feedback!.startsWith('Paiement')
                                        ? positive
                                        : danger,
                                    fontWeight: FontWeight.w600))),
                      if (payments.isEmpty)
                        const EmptyLine(
                            icon: Icons.receipt_long_outlined,
                            title: 'Aucun paiement enregistré',
                            subtitle: 'Les reçus confirmés apparaîtront ici.')
                      else
                        ...payments.map((raw) {
                          final payment = raw as Map<String, dynamic>;
                          final reversed = payment['status'] == 'reversed';
                          return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                  backgroundColor:
                                      (reversed ? danger : positive)
                                          .withValues(alpha: .1),
                                  child: Icon(
                                      reversed
                                          ? Icons.undo_outlined
                                          : Icons.check,
                                      color: reversed ? danger : positive)),
                              title: Text(
                                  '${_money(payment['amount'])} FCFA · reçu ${payment['receipt_number'] ?? '—'}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                  '${payment['method'] ?? 'cash'} · ${reversed ? 'Annulé' : 'Confirmé'}'),
                              trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                        tooltip: 'Ouvrir le reçu PDF',
                                        onPressed: busy
                                            ? null
                                            : () => _openReceipt(payment),
                                        icon: const Icon(
                                            Icons.picture_as_pdf_outlined,
                                            color: accent)),
                                    if (reversed)
                                      const Text('Annulé',
                                          style: TextStyle(color: danger))
                                    else
                                      TextButton(
                                          onPressed: busy
                                              ? null
                                              : () => _reversePayment(payment),
                                          child: const Text('Annuler')),
                                  ]));
                        })
                    ]));
              }),
          const SizedBox(height: 24),
          FutureBuilder<List<dynamic>>(
              future: chargesFuture,
              builder: (context, chargesSnapshot) {
                if (chargesSnapshot.connectionState != ConnectionState.done) {
                  return const AppCard(child: LoadingState());
                }
                if (chargesSnapshot.hasError) {
                  return ErrorState(message: chargesSnapshot.error.toString());
                }
                final charges = chargesSnapshot.data ?? [];
                return AppCard(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const SectionTitle(title: 'Frais et soldes'),
                      const SizedBox(height: 16),
                      if (charges.isEmpty)
                        const EmptyLine(
                            icon: Icons.receipt_long_outlined,
                            title: 'Aucun frais créé',
                            subtitle: 'Les charges scolaires apparaîtront ici.')
                      else
                        ...charges.map((raw) {
                          final charge = raw as Map<String, dynamic>;
                          final remaining = charge['remaining_balance'];
                          return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const CircleAvatar(
                                  backgroundColor: Color(0xFFFFF1E5),
                                  child: Icon(Icons.receipt_long_outlined,
                                      color: attention)),
                              title: Text(charge['name']?.toString() ?? 'Frais',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                  'Montant : ${_money(charge['amount'])} FCFA · échéance ${charge['due_date'] ?? 'non définie'}'),
                              trailing: Text(
                                  '${_money(remaining)} FCFA restant',
                                  style: TextStyle(
                                      color:
                                          (remaining is num && remaining <= 0)
                                              ? positive
                                              : attention,
                                      fontWeight: FontWeight.w600)));
                        })
                    ]));
              }),
          if (accountFuture != null) ...[
            const SizedBox(height: 24),
            FutureBuilder<Map<String, dynamic>>(
                future: accountFuture,
                builder: (context, accountSnapshot) {
                  if (accountSnapshot.connectionState != ConnectionState.done) {
                    return const AppCard(child: LoadingState());
                  }
                  if (accountSnapshot.hasError) {
                    return ErrorState(
                        message: accountSnapshot.error.toString());
                  }
                  final account = accountSnapshot.data!;
                  final charges = account['charges'] as List<dynamic>? ?? [];
                  final payments = account['payments'] as List<dynamic>? ?? [];
                  return AppCard(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const SectionTitle(
                            title: 'Compte de l’élève sélectionné'),
                        const SizedBox(height: 18),
                        Row(children: [
                          Expanded(
                              child: Text('Solde restant',
                                  style:
                                      Theme.of(context).textTheme.titleMedium)),
                          Text('${_money(account['balance'])} FCFA',
                              style: TextStyle(
                                  color: (account['balance'] is num &&
                                          account['balance'] <= 0)
                                      ? positive
                                      : attention,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700)),
                        ]),
                        const Divider(height: 28),
                        Text(
                            '${charges.length} frais · ${payments.length} paiement(s)',
                            style: const TextStyle(color: muted)),
                        const SizedBox(height: 12),
                        if (charges.isEmpty && payments.isEmpty)
                          const EmptyLine(
                              icon: Icons.account_balance_wallet_outlined,
                              title: 'Compte vide',
                              subtitle:
                                  'Aucun mouvement financier pour cet élève.')
                        else ...[
                          ...charges.map((raw) {
                            final charge = raw as Map<String, dynamic>;
                            return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.receipt_long_outlined,
                                    color: attention),
                                title:
                                    Text(charge['name']?.toString() ?? 'Frais'),
                                trailing: Text(
                                    '${_money(charge['remaining_balance'])} FCFA',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)));
                          }),
                          ...payments.map((raw) {
                            final payment = raw as Map<String, dynamic>;
                            return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.payments_outlined,
                                    color: positive),
                                title: Text(
                                    'Paiement ${payment['receipt_number'] ?? ''}'),
                                trailing: Text(
                                    '${_money(payment['amount'])} FCFA',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)));
                          }),
                        ],
                      ]));
                })
          ]
        ]);
      });
}

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key, required this.api, required this.schoolId});
  final Api api;
  final String schoolId;

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  late Future<Map<String, List<dynamic>>> dataFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    dataFuture = Future.wait([
      widget.api.get('/schools/${widget.schoolId}/attendance-sessions'),
      widget.api.get('/schools/${widget.schoolId}/classes'),
    ]).then((responses) => {
          'sessions': _items(responses[0]),
          'classes': _items(responses[1]),
        });
  }

  static List<dynamic> _items(dynamic response) =>
      (response as Map<String, dynamic>)['items'] as List<dynamic>? ?? [];

  String _className(List<dynamic> classes, dynamic classId) {
    final match = classes.where((item) => item['id'] == classId);
    return match.isEmpty
        ? 'Classe'
        : match.first['name'] as String? ?? 'Classe';
  }

  Future<void> _createSession() async {
    final created = await showDialog<bool>(
        context: context,
        builder: (_) => AttendanceSessionDialog(
            api: widget.api, schoolId: widget.schoolId));
    if (created == true && mounted) setState(_reload);
  }

  Future<void> _openSession(Map<String, dynamic> session) async {
    final saved = await showDialog<bool>(
        context: context,
        builder: (_) => AttendanceRecordsDialog(
            api: widget.api, schoolId: widget.schoolId, session: session));
    if (saved == true && mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<
          Map<String, List<dynamic>>>(
      future: dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const LoadingState();
        if (snapshot.hasError)
          return ErrorState(message: snapshot.error.toString());
        final data = snapshot.data!;
        final sessions = data['sessions']!;
        final classes = data['classes']!;
        return ListView(children: [
          PageIntro(
              eyebrow: 'SCOLARITÉ',
              title: 'Présences',
              subtitle: 'Organisez les séances d’appel et suivez les statuts.',
              action: 'Nouvelle séance',
              onAction: _createSession),
          const SizedBox(height: 24),
          AppCard(
              child: sessions.isEmpty
                  ? const EmptyLine(
                      icon: Icons.fact_check_outlined,
                      title: 'Aucune séance d’appel',
                      subtitle:
                          'Créez une séance pour commencer la saisie des présences.')
                  : Column(
                      children: sessions.map((item) {
                      final session = item as Map<String, dynamic>;
                      return ListTile(
                          leading: const CircleAvatar(
                              backgroundColor: Color(0xFFEAF7EF),
                              child: Icon(Icons.fact_check_outlined,
                                  color: positive)),
                          title: Text(_className(classes, session['class_id'])),
                          subtitle: Text(
                              '${session['date'] ?? 'Date inconnue'} · ${session['slot'] ?? 'Journée'}'),
                          trailing: FilledButton(
                              onPressed: () => _openSession(session),
                              style:
                                  FilledButton.styleFrom(backgroundColor: ink),
                              child: const Text('Faire l’appel')),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 4));
                    }).toList()))
        ]);
      });
}

class AttendanceSessionDialog extends StatefulWidget {
  const AttendanceSessionDialog(
      {super.key, required this.api, required this.schoolId});
  final Api api;
  final String schoolId;

  @override
  State<AttendanceSessionDialog> createState() =>
      _AttendanceSessionDialogState();
}

class _AttendanceSessionDialogState extends State<AttendanceSessionDialog> {
  late Future<List<dynamic>> classesFuture;
  final date = TextEditingController(text: _todayDate());
  String? classId;
  String? error;
  bool busy = false;

  static String _todayDate() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    classesFuture = widget.api.get('/schools/${widget.schoolId}/classes').then(
        (data) =>
            (data as Map<String, dynamic>)['items'] as List<dynamic>? ?? []);
  }

  @override
  void dispose() {
    date.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (classId == null) {
      setState(() => error = 'Sélectionnez une classe.');
      return;
    }
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date.text.trim())) {
      setState(() => error = 'La date doit être au format AAAA-MM-JJ.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.post('/schools/${widget.schoolId}/attendance-sessions', {
        'class_id': classId,
        'date': date.text.trim(),
        'slot': 'day',
      });
      if (mounted) Navigator.pop(context, true);
    } catch (exception) {
      if (mounted)
        setState(
            () => error = exception.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Nouvelle séance d’appel'),
        content: SizedBox(
          width: 420,
          child: FutureBuilder<List<dynamic>>(
              future: classesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done)
                  return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: LinearProgressIndicator());
                if (snapshot.hasError)
                  return const Text('Impossible de charger les classes.',
                      style: TextStyle(color: danger));
                final classes = snapshot.data ?? [];
                return Column(mainAxisSize: MainAxisSize.min, children: [
                  DropdownButtonFormField<String>(
                      value: classId,
                      decoration: const InputDecoration(labelText: 'Classe'),
                      items: classes
                          .map((item) => DropdownMenuItem<String>(
                              value: item['id'] as String,
                              child: Text(item['name'] as String? ?? 'Classe')))
                          .toList(),
                      onChanged: busy
                          ? null
                          : (value) => setState(() => classId = value)),
                  const SizedBox(height: 14),
                  TextField(
                      controller: date,
                      decoration: const InputDecoration(
                          labelText: 'Date', hintText: 'AAAA-MM-JJ')),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Align(
                        alignment: Alignment.centerLeft,
                        child:
                            Text(error!, style: const TextStyle(color: danger)))
                  ]
                ]);
              }),
        ),
        actions: [
          TextButton(
              onPressed: busy ? null : () => Navigator.pop(context),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: busy ? null : _save,
              style: FilledButton.styleFrom(backgroundColor: ink),
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Enregistrer'))
        ],
      );
}

class AttendanceRecordsDialog extends StatefulWidget {
  const AttendanceRecordsDialog(
      {super.key,
      required this.api,
      required this.schoolId,
      required this.session});
  final Api api;
  final String schoolId;
  final Map<String, dynamic> session;

  @override
  State<AttendanceRecordsDialog> createState() =>
      _AttendanceRecordsDialogState();
}

class _AttendanceRecordsDialogState extends State<AttendanceRecordsDialog> {
  late Future<List<dynamic>> studentsFuture;
  final statuses = <String, String>{};
  String? error;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    studentsFuture = Future.wait([
      widget.api.get('/schools/${widget.schoolId}/students'),
      widget.api.get('/schools/${widget.schoolId}/enrollments'),
    ]).then((responses) {
      final students =
          (responses[0] as Map<String, dynamic>)['items'] as List<dynamic>? ??
              [];
      final enrollments =
          (responses[1] as Map<String, dynamic>)['items'] as List<dynamic>? ??
              [];
      final studentIds = enrollments
          .where((item) => item['class_id'] == widget.session['class_id'])
          .map((item) => item['student_id'])
          .toSet();
      return students.where((item) => studentIds.contains(item['id'])).toList();
    });
  }

  Future<void> _save(List<dynamic> students) async {
    if (students.isEmpty) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final enrollments =
          await widget.api.get('/schools/${widget.schoolId}/enrollments')
              as Map<String, dynamic>;
      final records = (enrollments['items'] as List<dynamic>? ?? [])
          .where((item) => item['class_id'] == widget.session['class_id'])
          .where((item) =>
              students.any((student) => student['id'] == item['student_id']))
          .map((item) => {
                'enrollment_id': item['id'],
                'status': statuses[item['student_id']] ?? 'present',
              })
          .toList();
      await widget.api.put(
          '/schools/${widget.schoolId}/attendance-sessions/${widget.session['id']}/records',
          {
            'expected_version': widget.session['version'] ?? 1,
            'records': records
          });
      if (mounted) Navigator.pop(context, true);
    } catch (exception) {
      if (mounted)
        setState(
            () => error = exception.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Appel · ${widget.session['date'] ?? ''}'),
        content: SizedBox(
          width: 520,
          child: FutureBuilder<List<dynamic>>(
              future: studentsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done)
                  return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: LinearProgressIndicator());
                if (snapshot.hasError)
                  return const Text('Impossible de charger les élèves.',
                      style: TextStyle(color: danger));
                final students = snapshot.data ?? [];
                if (students.isEmpty)
                  return const EmptyLine(
                      icon: Icons.people_outline,
                      title: 'Aucun élève inscrit',
                      subtitle:
                          'Inscrivez des élèves dans cette classe avant l’appel.');
                return SingleChildScrollView(
                    child: Column(children: [
                  ...students.map((student) {
                    final id = student['id'] as String;
                    final current = statuses[id] ?? 'present';
                    return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                            '${student['first_name'] ?? ''} ${student['last_name'] ?? ''}'),
                        trailing: DropdownButton<String>(
                            value: current,
                            items: const [
                              DropdownMenuItem(
                                  value: 'present', child: Text('Présent')),
                              DropdownMenuItem(
                                  value: 'absent', child: Text('Absent')),
                              DropdownMenuItem(
                                  value: 'late', child: Text('En retard')),
                              DropdownMenuItem(
                                  value: 'excused', child: Text('Excusé'))
                            ],
                            onChanged: busy
                                ? null
                                : (value) =>
                                    setState(() => statuses[id] = value!)));
                  }),
                  if (error != null)
                    Align(
                        alignment: Alignment.centerLeft,
                        child:
                            Text(error!, style: const TextStyle(color: danger)))
                ]));
              }),
        ),
        actions: [
          TextButton(
              onPressed: busy ? null : () => Navigator.pop(context),
              child: const Text('Annuler')),
          FutureBuilder<List<dynamic>>(
              future: studentsFuture,
              builder: (context, snapshot) => FilledButton(
                  onPressed: busy || !snapshot.hasData
                      ? null
                      : () => _save(snapshot.data!),
                  style: FilledButton.styleFrom(backgroundColor: ink),
                  child: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Enregistrer')))
        ],
      );
}

class SettingsPage extends StatefulWidget {
  const SettingsPage(
      {super.key,
      required this.api,
      required this.schoolId,
      required this.canEdit});
  final Api api;
  final String schoolId;
  final bool canEdit;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late Future<Map<String, dynamic>> settingsFuture;
  final name = TextEditingController();
  String currency = 'XOF';
  bool demonstration = false;
  bool initialized = false;
  bool busy = false;
  String? feedback;

  @override
  void initState() {
    super.initState();
    settingsFuture = widget.api
        .get('/schools/${widget.schoolId}/settings')
        .then((data) => data as Map<String, dynamic>);
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  void _hydrate(Map<String, dynamic> data) {
    if (initialized) return;
    name.text = data['name'] as String? ?? '';
    currency = data['currency'] as String? ?? 'XOF';
    demonstration = data['demonstration'] == true;
    initialized = true;
  }

  Future<void> _save() async {
    if (name.text.trim().isEmpty) {
      setState(() => feedback = 'Le nom de l’établissement est obligatoire.');
      return;
    }
    setState(() {
      busy = true;
      feedback = null;
    });
    try {
      final data = await widget.api.patch(
          '/schools/${widget.schoolId}/settings', {
        'name': name.text.trim(),
        'currency': currency,
        'demonstration': demonstration
      });
      _hydrate(data as Map<String, dynamic>);
      if (mounted) setState(() => feedback = 'Paramètres enregistrés.');
    } catch (exception) {
      if (mounted)
        setState(() =>
            feedback = exception.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
      future: settingsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const LoadingState();
        if (snapshot.hasError)
          return ErrorState(message: snapshot.error.toString());
        _hydrate(snapshot.data!);
        return ListView(children: [
          PageIntro(
              eyebrow: 'CONFIGURATION',
              title: 'Paramètres',
              subtitle:
                  'Les informations de votre établissement et ses règles.',
              action: widget.canEdit ? 'Enregistrer' : null,
              onAction: widget.canEdit ? _save : null),
          const SizedBox(height: 24),
          AppCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Établissement',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                const Text(
                    'Ces informations sont utilisées dans les écrans et documents.',
                    style: TextStyle(color: muted)),
                const SizedBox(height: 20),
                TextField(
                    controller: name,
                    enabled: widget.canEdit && !busy,
                    decoration: const InputDecoration(
                        labelText: 'Nom de l’établissement')),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                    value: currency,
                    decoration: const InputDecoration(labelText: 'Devise'),
                    items: const [
                      DropdownMenuItem(value: 'XOF', child: Text('FCFA (XOF)')),
                      DropdownMenuItem(value: 'EUR', child: Text('Euro (EUR)')),
                      DropdownMenuItem(
                          value: 'USD', child: Text('Dollar (USD)'))
                    ],
                    onChanged: widget.canEdit && !busy
                        ? (value) => setState(() => currency = value ?? 'XOF')
                        : null),
                SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Mode démonstration'),
                    subtitle: const Text(
                        'Identifie clairement les données de démonstration.'),
                    value: demonstration,
                    onChanged: widget.canEdit && !busy
                        ? (value) => setState(() => demonstration = value)
                        : null),
                if (feedback != null)
                  Text(feedback!,
                      style: TextStyle(
                          color: feedback == 'Paramètres enregistrés.'
                              ? positive
                              : danger))
              ])),
          if (!widget.canEdit) ...[
            const SizedBox(height: 12),
            const Text('Lecture seule pour votre rôle.',
                style: TextStyle(color: muted))
          ]
        ]);
      });
}

class CommunicationsPage extends StatefulWidget {
  const CommunicationsPage(
      {super.key, required this.api, required this.schoolId});
  final Api api;
  final String schoolId;

  @override
  State<CommunicationsPage> createState() => _CommunicationsPageState();
}

class _CommunicationsPageState extends State<CommunicationsPage> {
  late Future<Map<String, List<dynamic>>> dataFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    dataFuture = Future.wait([
      widget.api.get('/schools/${widget.schoolId}/announcements'),
      widget.api.get('/schools/${widget.schoolId}/messages'),
    ]).then((responses) => {
          'announcements': _items(responses[0]),
          'messages': _items(responses[1]),
        });
  }

  static List<dynamic> _items(dynamic response) =>
      (response as Map<String, dynamic>)['items'] as List<dynamic>? ?? [];

  Future<void> _create() async {
    final created = await showDialog<bool>(
        context: context,
        builder: (_) =>
            AnnouncementDialog(api: widget.api, schoolId: widget.schoolId));
    if (created == true && mounted) setState(_reload);
  }

  Future<void> _send(Map<String, dynamic> announcement) async {
    try {
      await widget.api.post(
          '/schools/${widget.schoolId}/announcements/${announcement['id']}/send',
          {},
          idempotencyKey:
              'announcement-send-${announcement['id']}-${DateTime.now().microsecondsSinceEpoch}');
      if (mounted) setState(_reload);
    } catch (exception) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(exception.toString().replaceFirst('Exception: ', ''))));
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<
          Map<String, List<dynamic>>>(
      future: dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const LoadingState();
        if (snapshot.hasError)
          return ErrorState(message: snapshot.error.toString());
        final data = snapshot.data!;
        final announcements = data['announcements']!;
        final messages = data['messages']!;
        return ListView(children: [
          PageIntro(
              eyebrow: 'GESTION',
              title: 'Communications',
              subtitle: 'Préparez les messages destinés aux parents.',
              action: 'Nouvelle annonce',
              onAction: _create),
          const SizedBox(height: 16),
          AppCard(
              child: Row(children: [
            const Icon(Icons.info_outline, color: accent),
            const SizedBox(width: 12),
            const Expanded(
                child: Text(
                    'Mode simulation actif : aucun message WhatsApp réel ne sera envoyé.')),
            Chip(
                label: const Text('SIMULATED'),
                backgroundColor: const Color(0xFFF0ECFF))
          ])),
          const SizedBox(height: 20),
          Text('Annonces', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          AppCard(
              child: announcements.isEmpty
                  ? const EmptyLine(
                      icon: Icons.forum_outlined,
                      title: 'Aucune annonce',
                      subtitle:
                          'Les communications préparées apparaîtront ici.')
                  : Column(
                      children: announcements.map((item) {
                      final announcement = item as Map<String, dynamic>;
                      final sent = announcement['published'] == true;
                      return ListTile(
                          leading: const CircleAvatar(
                              backgroundColor: Color(0xFFF0ECFF),
                              child: Icon(Icons.forum_outlined, color: accent)),
                          title: Text(
                              announcement['title'] as String? ?? 'Annonce'),
                          subtitle: Text(announcement['body'] as String? ??
                              'Message sans contenu'),
                          trailing: sent
                              ? const Chip(
                                  label: Text('Simulé'),
                                  backgroundColor: Color(0xFFEAF7EF))
                              : FilledButton(
                                  onPressed: () => _send(announcement),
                                  style: FilledButton.styleFrom(
                                      backgroundColor: ink),
                                  child: const Text('Simuler l’envoi')),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 4));
                    }).toList())),
          const SizedBox(height: 20),
          Text('Journal des messages',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          AppCard(
              child: messages.isEmpty
                  ? const EmptyLine(
                      icon: Icons.receipt_long_outlined,
                      title: 'Aucun message journalisé',
                      subtitle:
                          'Les simulations apparaîtront après une annonce.')
                  : Column(
                      children: messages.map((item) {
                      final message = item as Map<String, dynamic>;
                      return ListTile(
                          leading: const Icon(Icons.check_circle_outline,
                              color: positive),
                          title: Text(message['recipient'] as String? ??
                              'Destinataire masqué'),
                          subtitle: Text(
                              message['detail'] as String? ?? 'Message simulé'),
                          trailing: const Chip(
                              label: Text('simulated'),
                              backgroundColor: Color(0xFFF0ECFF)));
                    }).toList()))
        ]);
      });
}

class AnnouncementDialog extends StatefulWidget {
  const AnnouncementDialog(
      {super.key, required this.api, required this.schoolId});
  final Api api;
  final String schoolId;

  @override
  State<AnnouncementDialog> createState() => _AnnouncementDialogState();
}

class _AnnouncementDialogState extends State<AnnouncementDialog> {
  late Future<List<dynamic>> classesFuture;
  final title = TextEditingController();
  final body = TextEditingController();
  String? classId;
  String? error;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    classesFuture = widget.api.get('/schools/${widget.schoolId}/classes').then(
        (data) =>
            (data as Map<String, dynamic>)['items'] as List<dynamic>? ?? []);
  }

  @override
  void dispose() {
    title.dispose();
    body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (title.text.trim().isEmpty || body.text.trim().isEmpty) {
      setState(() => error = 'Le titre et le message sont obligatoires.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final payload = <String, dynamic>{
        'title': title.text.trim(),
        'body': body.text.trim(),
      };
      if (classId != null) payload['class_id'] = classId;
      await widget.api
          .post('/schools/${widget.schoolId}/announcements', payload);
      if (mounted) Navigator.pop(context, true);
    } catch (exception) {
      if (mounted)
        setState(
            () => error = exception.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Nouvelle annonce'),
        content: SizedBox(
          width: 480,
          child: FutureBuilder<List<dynamic>>(
              future: classesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done)
                  return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: LinearProgressIndicator());
                final classes = snapshot.data ?? [];
                return Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: title,
                      autofocus: true,
                      decoration: const InputDecoration(labelText: 'Titre')),
                  const SizedBox(height: 14),
                  TextField(
                      controller: body,
                      minLines: 4,
                      maxLines: 7,
                      decoration: const InputDecoration(labelText: 'Message')),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                      value: classId,
                      decoration: const InputDecoration(
                          labelText: 'Destinataire (optionnel)'),
                      items: [
                        const DropdownMenuItem<String>(
                            value: null, child: Text('Toute l’école')),
                        ...classes.map((item) => DropdownMenuItem<String>(
                            value: item['id'] as String,
                            child: Text(item['name'] as String? ?? 'Classe')))
                      ],
                      onChanged: busy
                          ? null
                          : (value) => setState(() => classId = value)),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Align(
                        alignment: Alignment.centerLeft,
                        child:
                            Text(error!, style: const TextStyle(color: danger)))
                  ]
                ]);
              }),
        ),
        actions: [
          TextButton(
              onPressed: busy ? null : () => Navigator.pop(context),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: busy ? null : _save,
              style: FilledButton.styleFrom(backgroundColor: ink),
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Enregistrer'))
        ],
      );
}

class ReportCardsPage extends StatefulWidget {
  const ReportCardsPage(
      {super.key,
      required this.api,
      required this.schoolId,
      required this.role});
  final Api api;
  final String schoolId;
  final String role;

  @override
  State<ReportCardsPage> createState() => _ReportCardsPageState();
}

class _ReportCardsPageState extends State<ReportCardsPage> {
  late Future<List<dynamic>> reportsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    reportsFuture = widget.api
        .get('/schools/${widget.schoolId}/report-cards')
        .then((data) =>
            (data as Map<String, dynamic>)['items'] as List<dynamic>? ?? []);
  }

  Future<void> _generate() async {
    final created = await showDialog<bool>(
        context: context,
        builder: (_) => ReportCardGenerationDialog(
            api: widget.api, schoolId: widget.schoolId));
    if (created == true && mounted) setState(_reload);
  }

  Future<void> _download(Map<String, dynamic> report) async {
    try {
      final bytes = await widget.api.download(
          '/schools/${widget.schoolId}/report-cards/${report['id']}/download');
      await saveAndOpenReceipt(bytes, 'bulletin-${report['student_id']}.pdf');
    } catch (exception) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(exception.toString().replaceFirst('Exception: ', ''))));
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<dynamic>>(
      future: reportsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const LoadingState();
        if (snapshot.hasError)
          return ErrorState(message: snapshot.error.toString());
        final reports = snapshot.data!;
        return ListView(children: [
          PageIntro(
              eyebrow: 'SCOLARITÉ',
              title: 'Bulletins scolaires',
              subtitle: 'Générez, consultez et téléchargez les bulletins.',
              action: widget.role == 'admin' ? 'Générer des bulletins' : null,
              onAction: widget.role == 'admin' ? _generate : null),
          const SizedBox(height: 24),
          AppCard(
              child: reports.isEmpty
                  ? const EmptyLine(
                      icon: Icons.description_outlined,
                      title: 'Aucun bulletin généré',
                      subtitle:
                          'Complétez les notes avant de générer les bulletins.')
                  : Column(
                      children: reports.map((item) {
                      final report = item as Map<String, dynamic>;
                      final published = report['published'] == true;
                      return ListTile(
                          leading: CircleAvatar(
                              backgroundColor: published
                                  ? const Color(0xFFEAF7EF)
                                  : const Color(0xFFF0ECFF),
                              child: Icon(Icons.description_outlined,
                                  color: published ? positive : accent)),
                          title: Text(
                              report['student_name'] as String? ?? 'Élève'),
                          subtitle: Text(
                              '${report['class_name'] ?? 'Classe'} · ${report['term_name'] ?? 'Période'} · Moyenne ${report['average'] ?? '—'}/20'),
                          trailing: Wrap(spacing: 8, children: [
                            Chip(
                                label: Text(published ? 'Publié' : 'Brouillon'),
                                backgroundColor: published
                                    ? const Color(0xFFEAF7EF)
                                    : const Color(0xFFF0ECFF)),
                            OutlinedButton(
                                onPressed: () => _download(report),
                                child: const Text('PDF'))
                          ]),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 4));
                    }).toList()))
        ]);
      });
}

class ReportCardGenerationDialog extends StatefulWidget {
  const ReportCardGenerationDialog(
      {super.key, required this.api, required this.schoolId});
  final Api api;
  final String schoolId;

  @override
  State<ReportCardGenerationDialog> createState() =>
      _ReportCardGenerationDialogState();
}

class _ReportCardGenerationDialogState
    extends State<ReportCardGenerationDialog> {
  late Future<Map<String, List<dynamic>>> optionsFuture;
  String? classId;
  String? termId;
  String? error;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    optionsFuture = Future.wait([
      widget.api.get('/schools/${widget.schoolId}/classes'),
      widget.api.get('/schools/${widget.schoolId}/terms'),
    ]).then((responses) => {
          'classes': _items(responses[0]),
          'terms': _items(responses[1]),
        });
  }

  static List<dynamic> _items(dynamic response) =>
      (response as Map<String, dynamic>)['items'] as List<dynamic>? ?? [];

  Future<void> _generate() async {
    if (classId == null || termId == null) {
      setState(() => error = 'Sélectionnez une classe et une période.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.post('/schools/${widget.schoolId}/report-cards/generate',
          {'class_id': classId, 'term_id': termId});
      if (mounted) Navigator.pop(context, true);
    } catch (exception) {
      if (mounted)
        setState(
            () => error = exception.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  DropdownButtonFormField<String> _select(String label, String? value,
      List<dynamic> items, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(labelText: label),
        items: items
            .map((item) => DropdownMenuItem<String>(
                value: item['id'] as String,
                child: Text(item['name'] as String? ?? label)))
            .toList(),
        onChanged: busy ? null : onChanged);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Générer les bulletins'),
        content: SizedBox(
          width: 420,
          child: FutureBuilder<Map<String, List<dynamic>>>(
              future: optionsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done)
                  return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: LinearProgressIndicator());
                if (snapshot.hasError)
                  return const Text('Impossible de charger les options.',
                      style: TextStyle(color: danger));
                final data = snapshot.data!;
                return Column(mainAxisSize: MainAxisSize.min, children: [
                  _select('Classe', classId, data['classes']!,
                      (value) => setState(() => classId = value)),
                  const SizedBox(height: 14),
                  _select('Période', termId, data['terms']!,
                      (value) => setState(() => termId = value)),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Align(
                        alignment: Alignment.centerLeft,
                        child:
                            Text(error!, style: const TextStyle(color: danger)))
                  ]
                ]);
              }),
        ),
        actions: [
          TextButton(
              onPressed: busy ? null : () => Navigator.pop(context),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: busy ? null : _generate,
              style: FilledButton.styleFrom(backgroundColor: ink),
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Générer'))
        ],
      );
}

class AssessmentsPage extends StatefulWidget {
  const AssessmentsPage(
      {super.key,
      required this.api,
      required this.schoolId,
      required this.role});
  final Api api;
  final String schoolId;
  final String role;

  @override
  State<AssessmentsPage> createState() => _AssessmentsPageState();
}

class _AssessmentsPageState extends State<AssessmentsPage> {
  late Future<Map<String, List<dynamic>>> dataFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    dataFuture = Future.wait([
      widget.api.get('/schools/${widget.schoolId}/assessments'),
      widget.api.get('/schools/${widget.schoolId}/classes'),
      widget.api.get('/schools/${widget.schoolId}/subjects'),
      widget.api.get('/schools/${widget.schoolId}/terms'),
    ]).then((responses) => {
          'assessments': _items(responses[0]),
          'classes': _items(responses[1]),
          'subjects': _items(responses[2]),
          'terms': _items(responses[3]),
        });
  }

  static List<dynamic> _items(dynamic response) =>
      (response as Map<String, dynamic>)['items'] as List<dynamic>? ?? [];

  String _nameFor(List<dynamic> records, dynamic id, String fallback) {
    final matches = records.where((item) => item['id'] == id);
    return matches.isEmpty
        ? fallback
        : matches.first['name'] as String? ?? fallback;
  }

  Future<void> _addAssessment() async {
    final created = await showDialog<bool>(
        context: context,
        builder: (_) =>
            AssessmentFormDialog(api: widget.api, schoolId: widget.schoolId));
    if (created == true && mounted) setState(_reload);
  }

  Future<void> _enterGrades(Map<String, dynamic> assessment) async {
    final saved = await showDialog<bool>(
        context: context,
        builder: (_) => GradeEntryDialog(
            api: widget.api,
            schoolId: widget.schoolId,
            assessment: assessment));
    if (saved == true && mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<
          Map<String, List<dynamic>>>(
      future: dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const LoadingState();
        if (snapshot.hasError)
          return ErrorState(message: snapshot.error.toString());
        final data = snapshot.data!;
        final assessments = data['assessments']!;
        return ListView(children: [
          PageIntro(
              eyebrow: 'SCOLARITÉ',
              title: 'Notes et évaluations',
              subtitle: 'Créez les évaluations et saisissez les résultats.',
              action: widget.role == 'admin' ? 'Nouvelle évaluation' : null,
              onAction: widget.role == 'admin' ? _addAssessment : null),
          const SizedBox(height: 24),
          AppCard(
              child: assessments.isEmpty
                  ? const EmptyLine(
                      icon: Icons.school_outlined,
                      title: 'Aucune évaluation',
                      subtitle:
                          'Les évaluations de vos classes apparaîtront ici.')
                  : Column(
                      children: assessments.map((item) {
                      final assessment = item as Map<String, dynamic>;
                      return ListTile(
                          leading: const CircleAvatar(
                              backgroundColor: Color(0xFFF0ECFF),
                              child:
                                  Icon(Icons.school_outlined, color: accent)),
                          title: Text(
                              assessment['name'] as String? ?? 'Évaluation'),
                          subtitle: Text(
                              '${_nameFor(data['classes']!, assessment['class_id'], 'Classe')} · ${_nameFor(data['subjects']!, assessment['subject_id'], 'Matière')} · /${assessment['max_score'] ?? 20}'),
                          trailing: FilledButton(
                              onPressed: () => _enterGrades(assessment),
                              style:
                                  FilledButton.styleFrom(backgroundColor: ink),
                              child: const Text('Saisir les notes')),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 4));
                    }).toList()))
        ]);
      });
}

class AssessmentFormDialog extends StatefulWidget {
  const AssessmentFormDialog(
      {super.key, required this.api, required this.schoolId});
  final Api api;
  final String schoolId;

  @override
  State<AssessmentFormDialog> createState() => _AssessmentFormDialogState();
}

class _AssessmentFormDialogState extends State<AssessmentFormDialog> {
  late Future<Map<String, List<dynamic>>> optionsFuture;
  final name = TextEditingController();
  final maxScore = TextEditingController(text: '20');
  final coefficient = TextEditingController(text: '1');
  String? classId;
  String? subjectId;
  String? termId;
  String? error;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    optionsFuture = Future.wait([
      widget.api.get('/schools/${widget.schoolId}/classes'),
      widget.api.get('/schools/${widget.schoolId}/subjects'),
      widget.api.get('/schools/${widget.schoolId}/terms'),
    ]).then((responses) => {
          'classes': _items(responses[0]),
          'subjects': _items(responses[1]),
          'terms': _items(responses[2]),
        });
  }

  static List<dynamic> _items(dynamic response) =>
      (response as Map<String, dynamic>)['items'] as List<dynamic>? ?? [];

  @override
  void dispose() {
    name.dispose();
    maxScore.dispose();
    coefficient.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final max = num.tryParse(maxScore.text.trim());
    final weight = num.tryParse(coefficient.text.trim());
    if (name.text.trim().isEmpty ||
        classId == null ||
        subjectId == null ||
        termId == null) {
      setState(() =>
          error = 'Complétez le nom, la classe, la matière et la période.');
      return;
    }
    if (max == null || max <= 0 || weight == null || weight <= 0) {
      setState(
          () => error = 'Le barème et le coefficient doivent être positifs.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.post('/schools/${widget.schoolId}/assessments', {
        'name': name.text.trim(),
        'class_id': classId,
        'subject_id': subjectId,
        'term_id': termId,
        'max_score': max.toString(),
        'coefficient': weight.toString(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (exception) {
      if (mounted)
        setState(
            () => error = exception.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  DropdownButtonFormField<String> _select(String label, String? value,
      List<dynamic> items, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(labelText: label),
        items: items
            .map((item) => DropdownMenuItem<String>(
                value: item['id'] as String,
                child: Text(item['name'] as String? ?? label)))
            .toList(),
        onChanged: busy ? null : onChanged);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Nouvelle évaluation'),
        content: SizedBox(
          width: 460,
          child: FutureBuilder<Map<String, List<dynamic>>>(
              future: optionsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done)
                  return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: LinearProgressIndicator());
                if (snapshot.hasError)
                  return const Text('Impossible de charger les options.',
                      style: TextStyle(color: danger));
                final data = snapshot.data!;
                return Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: name,
                      autofocus: true,
                      decoration: const InputDecoration(
                          labelText: 'Nom de l’évaluation')),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(
                        child: TextField(
                            controller: maxScore,
                            keyboardType: TextInputType.number,
                            decoration:
                                const InputDecoration(labelText: 'Barème'))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: TextField(
                            controller: coefficient,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'Coefficient')))
                  ]),
                  const SizedBox(height: 14),
                  _select('Classe', classId, data['classes']!,
                      (value) => setState(() => classId = value)),
                  const SizedBox(height: 14),
                  _select('Matière', subjectId, data['subjects']!,
                      (value) => setState(() => subjectId = value)),
                  const SizedBox(height: 14),
                  _select('Période', termId, data['terms']!,
                      (value) => setState(() => termId = value)),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Align(
                        alignment: Alignment.centerLeft,
                        child:
                            Text(error!, style: const TextStyle(color: danger)))
                  ]
                ]);
              }),
        ),
        actions: [
          TextButton(
              onPressed: busy ? null : () => Navigator.pop(context),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: busy ? null : _save,
              style: FilledButton.styleFrom(backgroundColor: ink),
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Enregistrer'))
        ],
      );
}

class GradeEntryDialog extends StatefulWidget {
  const GradeEntryDialog(
      {super.key,
      required this.api,
      required this.schoolId,
      required this.assessment});
  final Api api;
  final String schoolId;
  final Map<String, dynamic> assessment;

  @override
  State<GradeEntryDialog> createState() => _GradeEntryDialogState();
}

class _GradeEntryDialogState extends State<GradeEntryDialog> {
  late Future<List<Map<String, dynamic>>> studentsFuture;
  final scores = <String, TextEditingController>{};
  final studentEnrollmentIds = <String, String>{};
  String? error;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    studentsFuture = _loadStudents();
  }

  Future<List<Map<String, dynamic>>> _loadStudents() async {
    final responses = await Future.wait([
      widget.api.get('/schools/${widget.schoolId}/students'),
      widget.api.get('/schools/${widget.schoolId}/enrollments'),
      widget.api.get('/schools/${widget.schoolId}/grades'),
    ]);
    final students =
        ((responses[0] as Map<String, dynamic>)['items'] as List<dynamic>? ??
                [])
            .cast<Map<String, dynamic>>();
    final enrollments =
        (responses[1] as Map<String, dynamic>)['items'] as List<dynamic>? ?? [];
    final grades =
        (responses[2] as Map<String, dynamic>)['items'] as List<dynamic>? ?? [];
    final byStudent = <String, dynamic>{
      for (final grade in grades)
        if (grade['parent_id'] == widget.assessment['id'])
          grade['enrollment_id'] as String: grade['score']
    };
    final ids = enrollments
        .where((item) => item['class_id'] == widget.assessment['class_id'])
        .map((item) => item['student_id'])
        .toSet();
    final selected =
        students.where((student) => ids.contains(student['id'])).toList();
    for (final student in selected) {
      final enrollment = enrollments.firstWhere(
          (item) => item['student_id'] == student['id'],
          orElse: () => <String, dynamic>{});
      final controller = TextEditingController(
          text: byStudent[enrollment['id']]?.toString() ?? '');
      scores[enrollment['id'] as String] = controller;
      studentEnrollmentIds[student['id'] as String] =
          enrollment['id'] as String;
    }
    return selected;
  }

  @override
  void dispose() {
    for (final controller in scores.values) controller.dispose();
    super.dispose();
  }

  Future<void> _save(List<Map<String, dynamic>> students) async {
    final max = num.tryParse('${widget.assessment['max_score'] ?? 20}') ?? 20;
    final records = <Map<String, dynamic>>[];
    for (final entry in scores.entries) {
      final value = entry.value.text.trim();
      if (value.isEmpty) {
        records.add({'enrollment_id': entry.key, 'score': null});
        continue;
      }
      final score = num.tryParse(value);
      if (score == null || score < 0 || score > max) {
        setState(
            () => error = 'Chaque note doit être comprise entre 0 et $max.');
        return;
      }
      records.add({'enrollment_id': entry.key, 'score': value});
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.put(
          '/schools/${widget.schoolId}/assessments/${widget.assessment['id']}/grades',
          {
            'expected_version': widget.assessment['version'] ?? 1,
            'grades': records
          });
      if (mounted) Navigator.pop(context, true);
    } catch (exception) {
      if (mounted)
        setState(
            () => error = exception.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Notes · ${widget.assessment['name'] ?? ''}'),
        content: SizedBox(
          width: 520,
          child: FutureBuilder<List<Map<String, dynamic>>>(
              future: studentsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done)
                  return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: LinearProgressIndicator());
                if (snapshot.hasError)
                  return const Text('Impossible de charger les élèves.',
                      style: TextStyle(color: danger));
                final students = snapshot.data ?? [];
                if (students.isEmpty)
                  return const EmptyLine(
                      icon: Icons.people_outline,
                      title: 'Aucun élève inscrit',
                      subtitle:
                          'Inscrivez les élèves dans cette classe avant la saisie.');
                return SingleChildScrollView(
                    child: Column(children: [
                  ...students.map((student) {
                    final enrollment =
                        studentEnrollmentIds[student['id'] as String] ?? '';
                    final controller = scores[enrollment];
                    return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(children: [
                          Expanded(
                              child: Text(
                                  '${student['first_name'] ?? ''} ${student['last_name'] ?? ''}')),
                          SizedBox(
                              width: 110,
                              child: TextField(
                                  controller: controller,
                                  enabled: !busy,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  decoration:
                                      const InputDecoration(labelText: 'Note')))
                        ]));
                  }),
                  if (error != null)
                    Align(
                        alignment: Alignment.centerLeft,
                        child:
                            Text(error!, style: const TextStyle(color: danger)))
                ]));
              }),
        ),
        actions: [
          TextButton(
              onPressed: busy ? null : () => Navigator.pop(context),
              child: const Text('Annuler')),
          FutureBuilder<List<Map<String, dynamic>>>(
              future: studentsFuture,
              builder: (context, snapshot) => FilledButton(
                  onPressed: busy || !snapshot.hasData
                      ? null
                      : () => _save(snapshot.data!),
                  style: FilledButton.styleFrom(backgroundColor: ink),
                  child: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Enregistrer')))
        ],
      );
}

class TeachingAssignmentsPage extends StatefulWidget {
  const TeachingAssignmentsPage(
      {super.key, required this.api, required this.schoolId});
  final Api api;
  final String schoolId;

  @override
  State<TeachingAssignmentsPage> createState() =>
      _TeachingAssignmentsPageState();
}

class _TeachingAssignmentsPageState extends State<TeachingAssignmentsPage> {
  late Future<Map<String, List<dynamic>>> dataFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    dataFuture = Future.wait([
      widget.api.get('/schools/${widget.schoolId}/teaching-assignments'),
      widget.api.get('/schools/${widget.schoolId}/teachers'),
      widget.api.get('/schools/${widget.schoolId}/classes'),
      widget.api.get('/schools/${widget.schoolId}/subjects'),
    ]).then((responses) => {
          'assignments': _items(responses[0]),
          'teachers': _items(responses[1]),
          'classes': _items(responses[2]),
          'subjects': _items(responses[3]),
        });
  }

  static List<dynamic> _items(dynamic response) =>
      (response as Map<String, dynamic>)['items'] as List<dynamic>? ?? [];

  Future<void> _addAssignment() async {
    final created = await showDialog<bool>(
        context: context,
        builder: (_) => TeachingAssignmentFormDialog(
            api: widget.api, schoolId: widget.schoolId));
    if (created == true && mounted) setState(_reload);
  }

  String _nameFor(List<dynamic> records, dynamic id, String fallback) {
    final match = records
        .cast<Map<String, dynamic>?>()
        .firstWhere((record) => record?['id'] == id, orElse: () => null);
    return match?['name'] as String? ?? fallback;
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<Map<String, List<dynamic>>>(
          future: dataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done)
              return const LoadingState();
            if (snapshot.hasError)
              return ErrorState(message: snapshot.error.toString());
            final data = snapshot.data!;
            final assignments = data['assignments']!;
            final teachers = data['teachers']!;
            final classes = data['classes']!;
            final subjects = data['subjects']!;
            return ListView(children: [
              PageIntro(
                  eyebrow: 'SCOLARITÉ',
                  title: 'Affectations',
                  subtitle:
                      'Reliez les enseignants, les classes et les matières.',
                  action: 'Ajouter',
                  onAction: _addAssignment),
              const SizedBox(height: 24),
              AppCard(
                  child: assignments.isEmpty
                      ? const EmptyLine(
                          icon: Icons.account_tree_outlined,
                          title: 'Aucune affectation',
                          subtitle:
                              'Les affectations pédagogiques apparaîtront ici.')
                      : Column(
                          children: assignments.map((item) {
                          final assignment = item as Map<String, dynamic>;
                          return ListTile(
                              leading: const CircleAvatar(
                                  backgroundColor: Color(0xFFF0ECFF),
                                  child: Icon(Icons.school_outlined,
                                      color: accent)),
                              title: Text(_nameFor(teachers,
                                  assignment['teacher_id'], 'Enseignant')),
                              subtitle: Text(
                                  '${_nameFor(classes, assignment['class_id'], 'Classe')} · ${_nameFor(subjects, assignment['subject_id'], 'Matière')}'),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 4));
                        }).toList()))
            ]);
          });
}

class TeachingAssignmentFormDialog extends StatefulWidget {
  const TeachingAssignmentFormDialog(
      {super.key, required this.api, required this.schoolId});
  final Api api;
  final String schoolId;

  @override
  State<TeachingAssignmentFormDialog> createState() =>
      _TeachingAssignmentFormDialogState();
}

class _TeachingAssignmentFormDialogState
    extends State<TeachingAssignmentFormDialog> {
  late Future<Map<String, List<dynamic>>> optionsFuture;
  String? teacherId;
  String? classId;
  String? subjectId;
  String? error;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    optionsFuture = Future.wait([
      widget.api.get('/schools/${widget.schoolId}/teachers'),
      widget.api.get('/schools/${widget.schoolId}/classes'),
      widget.api.get('/schools/${widget.schoolId}/subjects'),
    ]).then((responses) => {
          'teachers': _items(responses[0]),
          'classes': _items(responses[1]),
          'subjects': _items(responses[2]),
        });
  }

  static List<dynamic> _items(dynamic response) =>
      (response as Map<String, dynamic>)['items'] as List<dynamic>? ?? [];

  Future<void> _save() async {
    if (teacherId == null || classId == null || subjectId == null) {
      setState(() =>
          error = 'Sélectionnez un enseignant, une classe et une matière.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api
          .post('/schools/${widget.schoolId}/teaching-assignments', {
        'teacher_id': teacherId,
        'class_id': classId,
        'subject_id': subjectId,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (exception) {
      if (mounted)
        setState(
            () => error = exception.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  DropdownButtonFormField<String> _select(
      {required String label,
      required String? value,
      required List<dynamic> items,
      required ValueChanged<String?> onChanged}) {
    return DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(labelText: label),
        items: items
            .map((item) => DropdownMenuItem<String>(
                value: item['id'] as String,
                child: Text(item['name'] as String? ?? label)))
            .toList(),
        onChanged: busy ? null : onChanged);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Ajouter une affectation'),
        content: SizedBox(
          width: 440,
          child: FutureBuilder<Map<String, List<dynamic>>>(
              future: optionsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done)
                  return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: LinearProgressIndicator());
                if (snapshot.hasError)
                  return const Text('Impossible de charger les options.',
                      style: TextStyle(color: danger));
                final data = snapshot.data!;
                return Column(mainAxisSize: MainAxisSize.min, children: [
                  _select(
                      label: 'Enseignant',
                      value: teacherId,
                      items: data['teachers']!,
                      onChanged: (value) => setState(() => teacherId = value)),
                  const SizedBox(height: 14),
                  _select(
                      label: 'Classe',
                      value: classId,
                      items: data['classes']!,
                      onChanged: (value) => setState(() => classId = value)),
                  const SizedBox(height: 14),
                  _select(
                      label: 'Matière',
                      value: subjectId,
                      items: data['subjects']!,
                      onChanged: (value) => setState(() => subjectId = value)),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Align(
                        alignment: Alignment.centerLeft,
                        child:
                            Text(error!, style: const TextStyle(color: danger)))
                  ]
                ]);
              }),
        ),
        actions: [
          TextButton(
              onPressed: busy ? null : () => Navigator.pop(context),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: busy ? null : _save,
              style: FilledButton.styleFrom(backgroundColor: ink),
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Enregistrer'))
        ],
      );
}

class RecordsPage extends StatefulWidget {
  const RecordsPage(
      {super.key,
      required this.api,
      required this.schoolId,
      required this.kind,
      required this.title,
      required this.role});
  final Api api;
  final String schoolId;
  final String kind;
  final String title;
  final String role;
  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  late Future<List<dynamic>> recordsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    recordsFuture = widget.api
        .get(
            '/schools/${widget.schoolId}/${widget.kind == 'attendance' ? 'attendance-sessions' : widget.kind}')
        .then((data) =>
            (data as Map<String, dynamic>)['items'] as List<dynamic>? ?? []);
  }

  Future<void> _addStudent() async {
    final created = await showDialog<bool>(
        context: context,
        builder: (_) =>
            StudentFormDialog(api: widget.api, schoolId: widget.schoolId));
    if (created == true && mounted) setState(_reload);
  }

  Future<void> _addClass() async {
    final created = await showDialog<bool>(
        context: context,
        builder: (_) =>
            ClassFormDialog(api: widget.api, schoolId: widget.schoolId));
    if (created == true && mounted) setState(_reload);
  }

  Future<void> _addTeacher() async {
    final created = await showDialog<bool>(
        context: context,
        builder: (_) =>
            TeacherFormDialog(api: widget.api, schoolId: widget.schoolId));
    if (created == true && mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<dynamic>>(
      future: recordsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const LoadingState();
        if (snapshot.hasError)
          return ErrorState(message: snapshot.error.toString());
        final rows = snapshot.data!;
        return ListView(children: [
          PageIntro(
              eyebrow: _sectionLabel(widget.kind),
              title: widget.title,
              subtitle: _description(widget.kind),
              action: widget.role == 'admin' &&
                      (widget.kind == 'students' ||
                          widget.kind == 'classes' ||
                          widget.kind == 'teachers')
                  ? 'Ajouter'
                  : null,
              onAction: widget.kind == 'students'
                  ? _addStudent
                  : widget.kind == 'classes'
                      ? _addClass
                      : widget.kind == 'teachers'
                          ? _addTeacher
                          : null),
          const SizedBox(height: 24),
          AppCard(
              child: rows.isEmpty
                  ? EmptyLine(
                      icon: _iconFor(widget.kind),
                      title: 'Aucune donnée',
                      subtitle:
                          'Les enregistrements de ce module apparaîtront ici.')
                  : Column(
                      children: rows
                          .map((row) => _RecordRow(
                              kind: widget.kind,
                              data: row as Map<String, dynamic>,
                              onTap: widget.kind == 'students'
                                  ? () => showDialog(
                                      context: context,
                                      builder: (_) => StudentDetailDialog(
                                          api: widget.api,
                                          schoolId: widget.schoolId,
                                          student: row as Map<String, dynamic>))
                                  : null))
                          .toList()))
        ]);
      });
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({required this.kind, required this.data, this.onTap});
  final String kind;
  final Map<String, dynamic> data;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final title = kind == 'students'
        ? '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'.trim()
        : (data['name'] ?? data['title'] ?? data['date'] ?? 'Enregistrement')
            .toString();
    final subtitle = kind == 'students'
        ? 'Classe ${data['class_id'] ?? 'non affectée'}'
        : kind == 'teachers'
            ? data['email']?.toString() ?? 'Compte enseignant'
            : kind == 'attendance'
                ? 'Séance de présence'
                : data['academic_year_id']?.toString() ?? 'Donnée persistée';
    return ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 6),
        leading: CircleAvatar(
            backgroundColor: _pastelFor(kind),
            child: Icon(_iconFor(kind), color: _colorFor(kind), size: 20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right, color: muted),
        onTap: onTap);
  }
}

class StudentDetailDialog extends StatelessWidget {
  const StudentDetailDialog(
      {super.key,
      required this.api,
      required this.schoolId,
      required this.student});
  final Api api;
  final String schoolId;
  final Map<String, dynamic> student;

  @override
  Widget build(BuildContext context) {
    final name =
        '${student['first_name'] ?? ''} ${student['last_name'] ?? ''}'.trim();
    return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: Padding(
                padding: const EdgeInsets.all(28),
                child: FutureBuilder<Map<String, dynamic>>(
                    future: api
                        .get(
                            '/schools/$schoolId/students/${student['id']}/account')
                        .then((data) => data as Map<String, dynamic>),
                    builder: (context, snapshot) {
                      final account = snapshot.data;
                      final charges =
                          account?['charges'] as List<dynamic>? ?? [];
                      final payments =
                          account?['payments'] as List<dynamic>? ?? [];
                      return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              CircleAvatar(
                                  radius: 26,
                                  backgroundColor: const Color(0xFFF0ECFF),
                                  child: Text(
                                      name.isEmpty
                                          ? '?'
                                          : name[0].toUpperCase(),
                                      style: const TextStyle(
                                          color: accent,
                                          fontWeight: FontWeight.w700))),
                              const SizedBox(width: 14),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge),
                                    Text(
                                        'Classe ${student['class_id'] ?? 'non affectée'}',
                                        style: const TextStyle(color: muted)),
                                  ])),
                              IconButton(
                                  tooltip: 'Fermer',
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(Icons.close))
                            ]),
                            const Divider(height: 32),
                            _DetailLine(
                                label: 'Tuteur',
                                value: student['guardian_name']?.toString() ??
                                    'Non renseigné'),
                            _DetailLine(
                                label: 'Téléphone',
                                value: student['guardian_phone']?.toString() ??
                                    'Non renseigné'),
                            _DetailLine(
                                label: 'Consentement WhatsApp',
                                value: student['consent'] == true
                                    ? 'Accordé'
                                    : 'Non accordé'),
                            const SizedBox(height: 18),
                            if (snapshot.connectionState !=
                                ConnectionState.done)
                              const LoadingState()
                            else if (snapshot.hasError)
                              Text(snapshot.error.toString(),
                                  style: const TextStyle(color: danger))
                            else ...[
                              Row(children: [
                                const Expanded(
                                    child: Text('Solde financier',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w700))),
                                Text('${_money(account?['balance'])} FCFA',
                                    style: const TextStyle(
                                        color: attention,
                                        fontWeight: FontWeight.w700))
                              ]),
                              const SizedBox(height: 8),
                              Text(
                                  '${charges.length} frais · ${payments.length} paiement(s)',
                                  style: const TextStyle(color: muted)),
                            ],
                            const SizedBox(height: 20),
                            Align(
                                alignment: Alignment.centerRight,
                                child: FilledButton(
                                    onPressed: () => Navigator.pop(context),
                                    style: FilledButton.styleFrom(
                                        backgroundColor: ink),
                                    child: const Text('Fermer')))
                          ]);
                    }))));
  }
}

class StudentFormDialog extends StatefulWidget {
  const StudentFormDialog({
    super.key,
    required this.api,
    required this.schoolId,
  });
  final Api api;
  final String schoolId;

  @override
  State<StudentFormDialog> createState() => _StudentFormDialogState();
}

class _StudentFormDialogState extends State<StudentFormDialog> {
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final guardianName = TextEditingController();
  final guardianPhone = TextEditingController();
  String? error;
  bool consent = false;
  bool busy = false;

  @override
  void dispose() {
    firstName.dispose();
    lastName.dispose();
    guardianName.dispose();
    guardianPhone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (firstName.text.trim().isEmpty || lastName.text.trim().isEmpty) {
      setState(() => error = 'Le prénom et le nom sont obligatoires.');
      return;
    }
    if (guardianPhone.text.trim().isNotEmpty &&
        !RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(guardianPhone.text.trim())) {
      setState(() => error =
          'Le téléphone doit être au format international, par exemple +226…');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.post('/schools/${widget.schoolId}/students', {
        'first_name': firstName.text.trim(),
        'last_name': lastName.text.trim(),
        'guardian_name': guardianName.text.trim(),
        'guardian_phone': guardianPhone.text.trim(),
        'consent': consent,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (exception) {
      if (mounted) {
        setState(
            () => error = exception.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Ajouter un élève'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Expanded(
                    child: TextField(
                        controller: firstName,
                        decoration:
                            const InputDecoration(labelText: 'Prénom'))),
                const SizedBox(width: 12),
                Expanded(
                    child: TextField(
                        controller: lastName,
                        decoration: const InputDecoration(labelText: 'Nom'))),
              ]),
              const SizedBox(height: 14),
              TextField(
                  controller: guardianName,
                  decoration:
                      const InputDecoration(labelText: 'Nom du tuteur')),
              const SizedBox(height: 14),
              TextField(
                  controller: guardianPhone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                      labelText: 'Téléphone du tuteur', hintText: '+226…')),
              CheckboxListTile(
                  value: consent,
                  onChanged: busy
                      ? null
                      : (value) => setState(() => consent = value ?? false),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Autoriser les communications WhatsApp'),
                  controlAffinity: ListTileControlAffinity.leading),
              if (error != null)
                Align(
                    alignment: Alignment.centerLeft,
                    child: Text(error!, style: const TextStyle(color: danger))),
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: busy ? null : () => Navigator.pop(context),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: busy ? null : _save,
              style: FilledButton.styleFrom(backgroundColor: ink),
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Enregistrer')),
        ],
      );
}

class ClassFormDialog extends StatefulWidget {
  const ClassFormDialog({
    super.key,
    required this.api,
    required this.schoolId,
  });
  final Api api;
  final String schoolId;

  @override
  State<ClassFormDialog> createState() => _ClassFormDialogState();
}

class _ClassFormDialogState extends State<ClassFormDialog> {
  final name = TextEditingController();
  late Future<List<dynamic>> yearsFuture;
  String? academicYearId;
  String? error;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    yearsFuture = _loadYears();
  }

  Future<List<dynamic>> _loadYears() async {
    final data =
        await widget.api.get('/schools/${widget.schoolId}/academic-years')
            as Map<String, dynamic>;
    return data['items'] as List<dynamic>? ?? [];
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (name.text.trim().isEmpty) {
      setState(() => error = 'Le nom de la classe est obligatoire.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final body = <String, dynamic>{
        'name': name.text.trim(),
      };
      if (academicYearId != null) body['academic_year_id'] = academicYearId;
      await widget.api.post('/schools/${widget.schoolId}/classes', body);
      if (mounted) Navigator.pop(context, true);
    } catch (exception) {
      if (mounted) {
        setState(
            () => error = exception.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Ajouter une classe'),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: name,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  if (!busy) _save();
                },
                decoration: const InputDecoration(
                    labelText: 'Nom de la classe', hintText: 'Ex. 6e A')),
            const SizedBox(height: 14),
            FutureBuilder<List<dynamic>>(
                future: yearsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done)
                    return const Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: LinearProgressIndicator()));
                  if (snapshot.hasError)
                    return Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                            'Année scolaire indisponible pour le moment.',
                            style: const TextStyle(color: muted)));
                  final years = snapshot.data ?? [];
                  if (years.isEmpty)
                    return const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                            'Aucune année scolaire configurée. La classe pourra être rattachée plus tard.',
                            style: TextStyle(color: muted)));
                  return DropdownButtonFormField<String>(
                      value: academicYearId ?? years.first['id'] as String,
                      decoration:
                          const InputDecoration(labelText: 'Année scolaire'),
                      items: years
                          .map((year) => DropdownMenuItem<String>(
                              value: year['id'] as String,
                              child: Text(year['name'] as String? ?? 'Année')))
                          .toList(),
                      onChanged: busy
                          ? null
                          : (value) => setState(() => academicYearId = value));
                }),
            if (error != null) ...[
              const SizedBox(height: 12),
              Align(
                  alignment: Alignment.centerLeft,
                  child: Text(error!, style: const TextStyle(color: danger))),
            ],
          ]),
        ),
        actions: [
          TextButton(
              onPressed: busy ? null : () => Navigator.pop(context),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: busy ? null : _save,
              style: FilledButton.styleFrom(backgroundColor: ink),
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Enregistrer')),
        ],
      );
}

class TeacherFormDialog extends StatefulWidget {
  const TeacherFormDialog({
    super.key,
    required this.api,
    required this.schoolId,
  });
  final Api api;
  final String schoolId;

  @override
  State<TeacherFormDialog> createState() => _TeacherFormDialogState();
}

class _TeacherFormDialogState extends State<TeacherFormDialog> {
  final name = TextEditingController();
  final email = TextEditingController();
  String? error;
  bool busy = false;

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (name.text.trim().isEmpty) {
      setState(() => error = 'Le nom de l’enseignant est obligatoire.');
      return;
    }
    final address = email.text.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(address)) {
      setState(() => error = 'Saisissez une adresse email valide.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.post('/schools/${widget.schoolId}/teachers', {
        'name': name.text.trim(),
        'email': address,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (exception) {
      if (mounted) {
        setState(
            () => error = exception.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Ajouter un enseignant'),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Nom complet')),
            const SizedBox(height: 14),
            TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  if (!busy) _save();
                },
                decoration: const InputDecoration(
                    labelText: 'Email professionnel',
                    hintText: 'enseignant@ecole.bf')),
            if (error != null) ...[
              const SizedBox(height: 12),
              Align(
                  alignment: Alignment.centerLeft,
                  child: Text(error!, style: const TextStyle(color: danger))),
            ],
          ]),
        ),
        actions: [
          TextButton(
              onPressed: busy ? null : () => Navigator.pop(context),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: busy ? null : _save,
              style: FilledButton.styleFrom(backgroundColor: ink),
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Enregistrer')),
        ],
      );
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        SizedBox(
            width: 170,
            child: Text(label, style: const TextStyle(color: muted))),
        Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w600)))
      ]));
}

class PageIntro extends StatelessWidget {
  const PageIntro(
      {super.key,
      required this.eyebrow,
      required this.title,
      required this.subtitle,
      this.action,
      this.onAction});
  final String eyebrow, title, subtitle;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(eyebrow,
              style: const TextStyle(
                  color: accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: muted))
        ])),
        if (action != null)
          FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add, size: 18),
              label: Text(action!),
              style: FilledButton.styleFrom(backgroundColor: ink))
      ]);
}

class MetricCard extends StatelessWidget {
  const MetricCard(
      {super.key,
      required this.label,
      required this.value,
      required this.icon,
      required this.color});
  final String label, value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => SizedBox(
      width: 220,
      child: AppCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(
            radius: 21,
            backgroundColor: color.withValues(alpha: .1),
            child: Icon(icon, color: color)),
        const SizedBox(height: 18),
        Text(label, style: const TextStyle(color: muted, fontSize: 13)),
        const SizedBox(height: 6),
        Text(value,
            style: const TextStyle(
                color: ink, fontSize: 22, fontWeight: FontWeight.w700))
      ])));
}

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE3E6E0))),
      child: Padding(padding: const EdgeInsets.all(24), child: child));
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.title, this.action});
  final String title;
  final String? action;
  @override
  Widget build(BuildContext context) => Row(children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        if (action != null) ...[
          const Spacer(),
          Text(action!,
              style:
                  const TextStyle(color: accent, fontWeight: FontWeight.w600)),
          const Icon(Icons.chevron_right, color: accent)
        ]
      ]);
}

class StatusLine extends StatelessWidget {
  const StatusLine(
      {super.key,
      required this.label,
      required this.value,
      required this.color});
  final String label, value;
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Row(children: [
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.w700, color: ink)),
        ]),
      );
}

class EmptyLine extends StatelessWidget {
  const EmptyLine(
      {super.key,
      required this.icon,
      required this.title,
      required this.subtitle});
  final IconData icon;
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(children: [
            Icon(icon, color: muted, size: 32),
            const SizedBox(height: 12),
            Text(title,
                style:
                    const TextStyle(color: ink, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: muted))
          ])));
}

class LoadingState extends StatelessWidget {
  const LoadingState({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator(color: accent));
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Center(
          child: AppCard(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.cloud_off_outlined, color: danger, size: 32),
        const SizedBox(height: 12),
        const Text('Données indisponibles',
            style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(message,
            textAlign: TextAlign.center, style: const TextStyle(color: muted))
      ])));
}

String _roleLabel(String role) =>
    {
      'admin': 'Administrateur',
      'accountant': 'Comptable',
      'teacher': 'Enseignant',
      'super_admin': 'Super administrateur'
    }[role] ??
    role;
String _sectionLabel(String kind) =>
    kind == 'finance' ? 'GESTION' : 'SCOLARITÉ';
String _description(String kind) =>
    {
      'students': 'Le répertoire des élèves et de leurs inscriptions.',
      'classes': 'Les classes et leurs années scolaires.',
      'teachers': 'Les enseignants et leurs comptes associés.',
      'attendance': 'Les séances et le suivi des présences.'
    }[kind] ??
    'Les données de votre établissement.';
IconData _iconFor(String kind) =>
    {
      'students': Icons.person_outline,
      'classes': Icons.class_outlined,
      'teachers': Icons.badge_outlined,
      'attendance': Icons.fact_check_outlined,
      'assessments': Icons.school_outlined,
      'assignments': Icons.assignment_outlined
    }[kind] ??
    Icons.folder_outlined;
Color _colorFor(String kind) =>
    {
      'students': accent,
      'classes': positive,
      'teachers': attention,
      'attendance': positive
    }[kind] ??
    accent;
Color _pastelFor(String kind) => _colorFor(kind).withValues(alpha: .1);
String _money(dynamic value) =>
    (value is num ? value : num.tryParse('$value') ?? 0).toStringAsFixed(0);
