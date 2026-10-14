import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BackOfficeDashboard extends StatefulWidget {
  const BackOfficeDashboard({super.key});

  @override
  State<BackOfficeDashboard> createState() => _BackOfficeDashboardState();
}

class _BackOfficeDashboardState extends State<BackOfficeDashboard> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    Center(child: Text('Pending Approvals & Ticket Verification')),
    Center(child: Text('Contractor & Team Allocation Manager')),
    Center(child: Text('SLA Performance & Operational Analytics')),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('JKR Admin Portal'),
        backgroundColor: const Color(0xFF1E293B), // Darker admin theme
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: Row(
        children: [
          // Navigation Side Rail for multi-pane administrative view
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() => _selectedIndex = index);
            },
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.rate_review),
                label: Text('Approvals'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.group_add),
                label: Text('Assign'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.analytics),
                label: Text('Analytics'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: _pages[_selectedIndex]),
        ],
      ),
    );
  }
}
