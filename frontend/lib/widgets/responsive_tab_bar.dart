import 'package:flutter/material.dart';

class ResponsiveTabBar extends StatelessWidget implements PreferredSizeWidget {
  final TabController controller;
  final bool isMobile;
  final bool isVerySmall;

  const ResponsiveTabBar({
    Key? key,
    required this.controller,
    required this.isMobile,
    required this.isVerySmall,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!isMobile) {
      return TabBar(
        controller: controller,
        labelColor: Theme.of(context).primaryColor,
        unselectedLabelColor: Colors.grey[600],
        indicatorColor: Theme.of(context).primaryColor,
        tabs: [
          Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
          Tab(icon: Icon(Icons.business), text: 'Businesses'),
          Tab(icon: Icon(Icons.people), text: 'Users & Security'),
          Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
          Tab(icon: Icon(Icons.settings), text: 'Settings'),
          Tab(icon: Icon(Icons.storage), text: 'Data Management'),
        ],
      );
    }

    // Mobile TabBar with overflow prevention
    return Container(
      height: isVerySmall ? 16 : 20,
      child: TabBar(
        controller: controller,
        isScrollable: true,
        labelColor: Theme.of(context).primaryColor,
        unselectedLabelColor: Colors.grey[600],
        indicatorColor: Theme.of(context).primaryColor,
        labelPadding: EdgeInsets.symmetric(horizontal: isVerySmall ? 0 : 2),
        labelStyle: TextStyle(fontSize: isVerySmall ? 3 : 4),
        unselectedLabelStyle: TextStyle(fontSize: isVerySmall ? 3 : 4),
        tabs: isVerySmall ? [
          // Icon-only tabs for very small screens
          Tab(icon: Icon(Icons.dashboard, size: 5)),
          Tab(icon: Icon(Icons.business, size: 5)),
          Tab(icon: Icon(Icons.people, size: 5)),
          Tab(icon: Icon(Icons.analytics, size: 5)),
          Tab(icon: Icon(Icons.settings, size: 5)),
          Tab(icon: Icon(Icons.storage, size: 5)),
        ] : [
          // Compact tabs with text
          Tab(icon: Icon(Icons.dashboard, size: 6), text: 'Overview'),
          Tab(icon: Icon(Icons.business, size: 6), text: 'Businesses'),
          Tab(icon: Icon(Icons.people, size: 6), text: 'Users'),
          Tab(icon: Icon(Icons.analytics, size: 6), text: 'Analytics'),
          Tab(icon: Icon(Icons.settings, size: 6), text: 'Settings'),
          Tab(icon: Icon(Icons.storage, size: 6), text: 'Data'),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(isVerySmall ? 16 : (isMobile ? 20 : 48));
} 