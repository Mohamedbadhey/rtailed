// Responsive fix for Superadmin Dashboard
// Add this widget to any content area for mobile logout functionality

import 'package:flutter/material.dart';
import 'package:retail_management/utils/translate.dart';

class MobileLogoutButton extends StatelessWidget {
  final VoidCallback onRefresh;
  final VoidCallback onProfile;
  final VoidCallback onLogout;

  const MobileLogoutButton({
    Key? key,
    required this.onRefresh,
    required this.onProfile,
    required this.onLogout,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Superadmin Controls',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.refresh, size: 16),
                onPressed: onRefresh,
                tooltip: t(context, 'Refresh'),
              ),
              IconButton(
                icon: const Icon(Icons.person, size: 16),
                onPressed: onProfile,
                tooltip: t(context, 'Profile'),
              ),
              IconButton(
                icon: const Icon(Icons.logout, size: 16, color: Colors.red),
                onPressed: onLogout,
                tooltip: t(context, 'Logout'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Usage in superadmin dashboard:
// 
// Widget _buildOverviewContent() {
//   final screenWidth = MediaQuery.of(context).size.width;
//   final isVerySmall = screenWidth < 400;
//   
//   return SingleChildScrollView(
//     padding: const EdgeInsets.all(4),
//     child: Column(
//       children: [
//         if (isVerySmall)
//           MobileLogoutButton(
//             onRefresh: _loadDashboardData,
//             onProfile: _showProfileDialog,
//             onLogout: _showLogoutDialog,
//           ),
//         // Rest of content...
//       ],
//     ),
//   );
// } 