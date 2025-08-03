import 'package:flutter/material.dart';
import 'package:retail_management/widgets/beautiful_data_table.dart';

// Example of how to use the beautiful table in your original superadmin dashboard
class SuperadminDashboardBeautifulExample {
  
  // Example for Users tab
  static Widget buildUsersTable() {
    return BeautifulDataTable(
      headers: ['ID', 'Username', 'Email', 'Role', 'Status', 'Actions'],
      data: [
        ['1', 'admin1', 'admin1@example.com', 'Admin', 'Active', 'Edit | Delete'],
        ['2', 'user1', 'user1@example.com', 'User', 'Active', 'Edit | Delete'],
        ['3', 'manager1', 'manager1@example.com', 'Manager', 'Inactive', 'Edit | Delete'],
        ['4', 'admin2', 'admin2@example.com', 'Admin', 'Active', 'Edit | Delete'],
        ['5', 'user2', 'user2@example.com', 'User', 'Active', 'Edit | Delete'],
      ],
      headerColors: [
        Colors.blue,
        Colors.blue.shade700,
      ],
      height: 400,
      showSearch: true,
      showPagination: true,
      itemsPerPage: 5,
      actions: [
        ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.add),
          label: const Text('Add User'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
      ],
      onRowTap: (index) {
        print('Tapped row $index');
      },
    );
  }

  // Example for Businesses tab
  static Widget buildBusinessesTable() {
    return BeautifulDataTable(
      headers: ['ID', 'Name', 'Owner', 'Status', 'Revenue', 'Actions'],
      data: [
        ['1', 'Tech Solutions', 'John Doe', 'Active', '\$50,000', 'View | Edit | Delete'],
        ['2', 'Digital Marketing', 'Jane Smith', 'Active', '\$75,000', 'View | Edit | Delete'],
        ['3', 'Web Development', 'Mike Johnson', 'Pending', '\$25,000', 'View | Edit | Delete'],
        ['4', 'Mobile Apps', 'Sarah Wilson', 'Active', '\$100,000', 'View | Edit | Delete'],
        ['5', 'Cloud Services', 'David Brown', 'Suspended', '\$30,000', 'View | Edit | Delete'],
      ],
      headerColors: [
        Colors.purple,
        Colors.purple.shade700,
      ],
      height: 400,
      showSearch: true,
      showPagination: true,
      itemsPerPage: 5,
      actions: [
        ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.business),
          label: const Text('Add Business'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  // Example for Analytics tab
  static Widget buildAnalyticsTable() {
    return BeautifulDataTable(
      headers: ['Metric', 'Current', 'Previous', 'Change', 'Trend'],
      data: [
        ['Total Revenue', '\$500,000', '\$450,000', '+11.1%', '📈'],
        ['Active Users', '1,250', '1,100', '+13.6%', '📈'],
        ['New Businesses', '25', '20', '+25.0%', '📈'],
        ['System Load', '65%', '70%', '-7.1%', '📉'],
        ['Uptime', '99.9%', '99.8%', '+0.1%', '📈'],
      ],
      headerColors: [
        Colors.green,
        Colors.green.shade700,
      ],
      height: 300,
      showSearch: false,
      showPagination: false,
    );
  }

  // Example for Settings tab
  static Widget buildSettingsTable() {
    return BeautifulDataTable(
      headers: ['Setting', 'Current Value', 'Description', 'Actions'],
      data: [
        ['System Theme', 'Dark Mode', 'Application appearance', 'Edit'],
        ['Backup Frequency', 'Daily', 'Data backup schedule', 'Edit'],
        ['Email Notifications', 'Enabled', 'System notifications', 'Edit'],
        ['Security Level', 'High', 'System security settings', 'Edit'],
        ['Language', 'English', 'Interface language', 'Edit'],
      ],
      headerColors: [
        Colors.orange,
        Colors.orange.shade700,
      ],
      height: 300,
      showSearch: true,
      showPagination: false,
    );
  }

  // Example for Data Management tab
  static Widget buildDataTable() {
    return BeautifulDataTable(
      headers: ['Table', 'Records', 'Size', 'Last Backup', 'Actions'],
      data: [
        ['Users', '1,250', '2.5 MB', '2 hours ago', 'Backup | Restore | Export'],
        ['Businesses', '150', '1.8 MB', '1 hour ago', 'Backup | Restore | Export'],
        ['Products', '5,000', '15.2 MB', '30 minutes ago', 'Backup | Restore | Export'],
        ['Sales', '25,000', '45.7 MB', '15 minutes ago', 'Backup | Restore | Export'],
        ['Logs', '100,000', '125.3 MB', '5 minutes ago', 'Backup | Restore | Export'],
      ],
      headerColors: [
        Colors.red,
        Colors.red.shade700,
      ],
      height: 350,
      showSearch: true,
      showPagination: true,
      itemsPerPage: 5,
      actions: [
        ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.backup),
          label: const Text('Backup All'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  // Example for Notifications tab
  static Widget buildNotificationsTable() {
    return BeautifulDataTable(
      headers: ['ID', 'Type', 'Message', 'Status', 'Date', 'Actions'],
      data: [
        ['1', 'System', 'Backup completed successfully', 'Read', '2024-01-15 10:30', 'Mark Unread | Delete'],
        ['2', 'Security', 'New login detected', 'Unread', '2024-01-15 09:15', 'Mark Read | Delete'],
        ['3', 'Business', 'New business registered', 'Read', '2024-01-15 08:45', 'Mark Unread | Delete'],
        ['4', 'Error', 'Database connection timeout', 'Unread', '2024-01-15 08:30', 'Mark Read | Delete'],
        ['5', 'Info', 'System maintenance scheduled', 'Read', '2024-01-15 08:00', 'Mark Unread | Delete'],
      ],
      headerColors: [
        Colors.teal,
        Colors.teal.shade700,
      ],
      height: 400,
      showSearch: true,
      showPagination: true,
      itemsPerPage: 5,
      actions: [
        ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.mark_email_read),
          label: const Text('Mark All Read'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  // Example for Audit Logs tab
  static Widget buildAuditLogsTable() {
    return BeautifulDataTable(
      headers: ['Timestamp', 'User', 'Action', 'Table', 'Details'],
      data: [
        ['2024-01-15 10:30:15', 'admin1', 'CREATE', 'users', 'Created user: john.doe'],
        ['2024-01-15 10:25:42', 'admin2', 'UPDATE', 'businesses', 'Updated business: TechCorp'],
        ['2024-01-15 10:20:18', 'manager1', 'DELETE', 'products', 'Deleted product: Old Widget'],
        ['2024-01-15 10:15:33', 'admin1', 'LOGIN', 'system', 'User logged in from 192.168.1.100'],
        ['2024-01-15 10:10:55', 'user1', 'READ', 'reports', 'Generated monthly report'],
      ],
      headerColors: [
        Colors.indigo,
        Colors.indigo.shade700,
      ],
      height: 400,
      showSearch: true,
      showPagination: true,
      itemsPerPage: 10,
      actions: [
        ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.download),
          label: const Text('Export Logs'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

// How to integrate this into your original superadmin dashboard:
/*
In your original superadmin dashboard, replace the existing table widgets with these beautiful ones:

1. In _buildUsersAndSecurityTab() method:
   return BeautifulDataTable.buildUsersTable();

2. In _buildBusinessesTab() method:
   return BeautifulDataTable.buildBusinessesTable();

3. In _buildAnalyticsTab() method:
   return BeautifulDataTable.buildAnalyticsTable();

4. In _buildSettingsTab() method:
   return BeautifulDataTable.buildSettingsTable();

5. In _buildDataManagementTab() method:
   return BeautifulDataTable.buildDataTable();

6. For notifications:
   return BeautifulDataTable.buildNotificationsTable();

7. For audit logs:
   return BeautifulDataTable.buildAuditLogsTable();
*/ 