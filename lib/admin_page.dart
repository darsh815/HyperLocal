import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'account_service.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({
    required this.accountService,
    required this.session,
    super.key,
  });

  final AccountService accountService;
  final AccountSession session;

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  static const _ink = Color(0xFF243238);
  static const _teal = Color(0xFF176B69);
  static const _mint = Color(0xFFE3F1EC);
  static const _amber = Color(0xFFE6A23C);
  static const _rose = Color(0xFFB94D55);
  static const _surface = Color(0xFFFFFCF7);
  static const _line = Color(0xFFE4D8C9);
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _usersSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _recipesSubscription;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _users = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _recipes = [];
  String? _error;
  bool _isLoading = true;
  String _userFilter = '';
  bool _isUpdatingUser = false;

  @override
  void initState() {
    super.initState();
    _listenToFirebaseAnalytics();
  }

  void _listenToFirebaseAnalytics() {
    if (!widget.accountService.usesFirebase) {
      setState(() {
        _error = 'Firebase is not configured for this app build.';
        _isLoading = false;
      });
      return;
    }
    final firestore = FirebaseFirestore.instance;
    _usersSubscription = firestore.collection('users').snapshots().listen((
      snapshot,
    ) {
      _users = snapshot.docs;
      _refreshDashboard();
    }, onError: _handleError);
    _recipesSubscription = firestore
        .collectionGroup('recipes')
        .snapshots()
        .listen((snapshot) {
          _recipes = snapshot.docs;
          _refreshDashboard();
        }, onError: _handleError);
  }

  void _refreshDashboard() {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _error = null;
    });
  }

  void _handleError(Object error) {
    if (!mounted) return;
    setState(() {
      _error = error.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _usersSubscription?.cancel();
    _recipesSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF1EAE0),
    appBar: AppBar(
      backgroundColor: _surface,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back_rounded),
        tooltip: 'Back',
      ),
      title: const Text(
        'Admin insights',
        style: TextStyle(fontWeight: FontWeight.bold, color: _ink),
      ),
      actions: const [
        Padding(
          padding: EdgeInsets.only(right: 16),
          child: Tooltip(
            message: 'Live Firebase data',
            child: Icon(Icons.wifi_tethering_rounded, color: _teal),
          ),
        ),
      ],
    ),
    body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? _buildError()
        : _buildDashboard(),
  );

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 48,
            color: Color(0xFFB94D2F),
          ),
          const SizedBox(height: 14),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          const Text(
            'Ensure this account has the Firebase custom claim admin: true.',
          ),
        ],
      ),
    ),
  );

  Widget _buildDashboard() {
    final now = DateUtils.dateOnly(DateTime.now());
    final days = List.generate(
      7,
      (index) => now.subtract(Duration(days: 6 - index)),
    );
    final recipeByDay = <DateTime, int>{for (final day in days) day: 0};
    final titles = <String, int>{};
    for (final document in _recipes) {
      final data = document.data();
      final savedAt = data['savedAt'];
      if (savedAt is Timestamp) {
        final day = DateUtils.dateOnly(savedAt.toDate());
        if (recipeByDay.containsKey(day)) {
          recipeByDay[day] = recipeByDay[day]! + 1;
        }
      }
      final title = data['title'] as String? ?? 'Untitled';
      titles[title] = (titles[title] ?? 0) + 1;
    }
    final newUsers = _users.where((document) {
      final createdAt = document.data()['createdAt'];
      return createdAt is Timestamp && !createdAt.toDate().isBefore(days.first);
    }).length;
    final recipesThisWeek = recipeByDay.values.fold(
      0,
      (total, recipeCount) => total + recipeCount,
    );
    final bannedUsers = _users
        .where((document) => document.data()['banned'] == true)
        .length;
    final popular = titles.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final daily = days
        .map(
          (day) => {
            'day': '${day.month}/${day.day}',
            'count': recipeByDay[day]!,
          },
        )
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
      children: [
        Text(
          'Live Firebase view � ${widget.session.email}',
          style: TextStyle(color: Colors.brown.shade500),
        ),
        const SizedBox(height: 6),
        const Text(
          'See what your kitchen community is making.',
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900
                ? 5
                : constraints.maxWidth >= 560
                ? 3
                : 2;
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              mainAxisExtent: 126,
              children: [
                _metric(
                  'Users',
                  _users.length,
                  Icons.people_alt_outlined,
                  const Color(0xFF2E5D50),
                ),
                _metric(
                  'Saved recipes',
                  _recipes.length,
                  Icons.bookmark_outline_rounded,
                  const Color(0xFFB94D2F),
                ),
                _metric(
                  'New this week',
                  newUsers,
                  Icons.person_add_alt_rounded,
                  const Color(0xFF6C8752),
                ),
                _metric(
                  'Recipes this week',
                  recipesThisWeek,
                  Icons.trending_up_rounded,
                  const Color(0xFFC28A29),
                ),
                _metric(
                  'Banned users',
                  bannedUsers,
                  Icons.gpp_bad_outlined,
                  const Color(0xFF8E3B46),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        _section(
          'Seven-day recipe activity',
          Icons.insights_rounded,
          _buildActivity(daily),
        ),
        const SizedBox(height: 16),
        _section(
          'Most saved recipes',
          Icons.local_fire_department_outlined,
          popular.isEmpty
              ? const Text('No saved recipes yet.')
              : Column(
                  children: popular.take(5).toList().asMap().entries.map((
                    entry,
                  ) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFE7F0E9),
                        foregroundColor: const Color(0xFF2E5D50),
                        child: Text('${entry.key + 1}'),
                      ),
                      title: Text(entry.value.key),
                      trailing: Text(
                        '${entry.value.value} saves',
                        style: TextStyle(
                          color: Colors.brown.shade500,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 16),
        _section(
          'User management',
          Icons.manage_accounts_outlined,
          _buildUserManagement(),
        ),
      ],
    );
  }

  Widget _buildUserManagement() {
    final users = _users.where((document) {
      final data = document.data();
      final email = (data['email'] as String? ?? '').toLowerCase();
      return _userFilter.isEmpty || email.contains(_userFilter.toLowerCase());
    }).toList();
    return Column(
      children: [
        TextField(
          decoration: InputDecoration(
            hintText: 'Search by email',
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            fillColor: const Color(0xFFF8F4EC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (value) => setState(() => _userFilter = value),
        ),
        const SizedBox(height: 10),
        if (users.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No matching users.'),
          )
        else
          ...users.map(_buildUserRow),
      ],
    );
  }

  Widget _buildUserRow(QueryDocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data();
    final email = data['email'] as String? ?? document.id;
    final banned = data['banned'] == true;
    final userRecipes =
        _recipes.where((recipe) {
          final parent = recipe.reference.parent.parent;
          return parent?.id == document.id;
        }).toList()..sort((a, b) {
          final aDate = a.data()['savedAt'];
          final bDate = b.data()['savedAt'];
          if (aDate is! Timestamp || bDate is! Timestamp) return 0;
          return bDate.compareTo(aDate);
        });
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAF3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        leading: CircleAvatar(
          backgroundColor: banned ? const Color(0xFFF8E3E3) : _mint,
          foregroundColor: banned ? _rose : _teal,
          child: Icon(
            banned ? Icons.block_rounded : Icons.person_outline_rounded,
            size: 20,
          ),
        ),
        title: Text(
          email,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${banned ? 'Banned' : 'Active'}  •  ${userRecipes.length} saved recipes',
          style: TextStyle(color: banned ? _rose : _teal, fontSize: 12),
        ),
        trailing: OutlinedButton.icon(
          onPressed: _isUpdatingUser
              ? null
              : () => _toggleBan(document, !banned),
          icon: Icon(
            banned ? Icons.check_circle_outline : Icons.block_outlined,
            size: 17,
          ),
          label: Text(banned ? 'Unban' : 'Ban'),
          style: OutlinedButton.styleFrom(
            foregroundColor: banned ? _teal : _rose,
          ),
        ),
        children: userRecipes.isEmpty
            ? [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('No saved recipes yet.'),
                ),
              ]
            : userRecipes.map(_buildRecipeRow).toList(),
      ),
    );
  }

  Widget _buildRecipeRow(QueryDocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data();
    final title = data['title'] as String? ?? 'Untitled recipe';
    final subtitle = data['subtitle'] as String? ?? 'Saved recipe';
    final savedAt = data['savedAt'];
    final date = savedAt is Timestamp
        ? _formatDate(savedAt.toDate())
        : 'Recently saved';
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.restaurant_menu_rounded, color: _amber),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '$subtitle\n$date',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

  Future<void> _toggleBan(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
    bool banned,
  ) async {
    setState(() => _isUpdatingUser = true);
    try {
      await widget.accountService.setUserBanned(document.id, banned);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(banned ? 'User banned.' : 'User unbanned.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not update user: $error')));
    } finally {
      if (mounted) setState(() => _isUpdatingUser = false);
    }
  }

  Widget _metric(String label, int value, IconData icon, Color color) =>
      Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 22),
            Text(
              '$value',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: _ink,
              ),
            ),
            Text(label, style: const TextStyle(color: _ink, fontSize: 12)),
          ],
        ),
      );

  Widget _section(String title, IconData icon, Widget child) => Container(
    padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: _teal, size: 19),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 13),
        child,
      ],
    ),
  );

  Widget _buildActivity(List<Map<String, Object>> daily) {
    final maxValue = daily
        .map((item) => item['count'] as int)
        .fold(1, (max, value) => value > max ? value : max);
    return SizedBox(
      height: 132,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: daily.map((item) {
          final count = item['count'] as int;
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '$count',
                style: TextStyle(fontSize: 10, color: Colors.brown.shade500),
              ),
              const SizedBox(height: 4),
              Container(
                width: 24,
                height: 16 + (count / maxValue * 64),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C8752),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                item['day'] as String,
                style: TextStyle(fontSize: 10, color: Colors.brown.shade400),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
