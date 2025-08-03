import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/offline_provider.dart';

class OfflineStatusWidget extends StatelessWidget {
  const OfflineStatusWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<OfflineProvider>(
      builder: (context, offlineProvider, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _getStatusColor(offlineProvider),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              _buildStatusIcon(offlineProvider),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offlineProvider.getConnectionStatusMessage(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      offlineProvider.getSyncStatusMessage(),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                    ),
                    if (offlineProvider.lastSyncTime != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Last sync: ${_formatDateTime(offlineProvider.lastSyncTime!)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (offlineProvider.pendingSyncItems > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${offlineProvider.pendingSyncItems}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (offlineProvider.isOnline && !offlineProvider.isSyncing)
                IconButton(
                  icon: const Icon(Icons.sync, size: 20),
                  onPressed: () => offlineProvider.triggerManualSync(),
                  tooltip: 'Manual sync',
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusIcon(OfflineProvider provider) {
    IconData iconData;
    Color iconColor;

    if (!provider.isOnline) {
      iconData = Icons.wifi_off;
      iconColor = Colors.red;
    } else if (provider.isSyncing) {
      iconData = Icons.sync;
      iconColor = Colors.blue;
    } else if (provider.pendingSyncItems > 0) {
      iconData = Icons.sync_problem;
      iconColor = Colors.orange;
    } else {
      iconData = Icons.wifi;
      iconColor = Colors.green;
    }

    return Icon(
      iconData,
      color: iconColor,
      size: 24,
    );
  }

  Color _getStatusColor(OfflineProvider provider) {
    if (!provider.isOnline) {
      return Colors.red[50]!;
    } else if (provider.isSyncing) {
      return Colors.blue[50]!;
    } else if (provider.pendingSyncItems > 0) {
      return Colors.orange[50]!;
    } else {
      return Colors.green[50]!;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

class OfflineStatusBar extends StatelessWidget {
  const OfflineStatusBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<OfflineProvider>(
      builder: (context, offlineProvider, child) {
        if (offlineProvider.isOnline && offlineProvider.syncStatus == 'synced') {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: _getStatusBarColor(offlineProvider),
          child: Row(
            children: [
              Icon(
                _getStatusBarIcon(offlineProvider),
                color: _getStatusBarIconColor(offlineProvider),
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  offlineProvider.getSyncStatusMessage(),
                  style: TextStyle(
                    color: _getStatusBarIconColor(offlineProvider),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (offlineProvider.isOnline && !offlineProvider.isSyncing)
                GestureDetector(
                  onTap: () => offlineProvider.triggerManualSync(),
                  child: Text(
                    'SYNC NOW',
                    style: TextStyle(
                      color: _getStatusBarIconColor(offlineProvider),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  IconData _getStatusBarIcon(OfflineProvider provider) {
    if (!provider.isOnline) {
      return Icons.wifi_off;
    } else if (provider.isSyncing) {
      return Icons.sync;
    } else {
      return Icons.sync_problem;
    }
  }

  Color _getStatusBarColor(OfflineProvider provider) {
    if (!provider.isOnline) {
      return Colors.red[100]!;
    } else if (provider.isSyncing) {
      return Colors.blue[100]!;
    } else {
      return Colors.orange[100]!;
    }
  }

  Color _getStatusBarIconColor(OfflineProvider provider) {
    if (!provider.isOnline) {
      return Colors.red[800]!;
    } else if (provider.isSyncing) {
      return Colors.blue[800]!;
    } else {
      return Colors.orange[800]!;
    }
  }
}

class OfflineDataSummaryCard extends StatelessWidget {
  const OfflineDataSummaryCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<OfflineProvider>(
      builder: (context, offlineProvider, child) {
        return FutureBuilder<Map<String, int>>(
          future: offlineProvider.getOfflineDataSummary(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            final data = snapshot.data!;
            final totalItems = data.values.reduce((a, b) => a + b);

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.storage,
                          color: Colors.blue[600],
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Offline Data',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildDataItem('Products', data['products'] ?? 0, Icons.inventory),
                        _buildDataItem('Customers', data['customers'] ?? 0, Icons.people),
                        _buildDataItem('Sales', data['sales'] ?? 0, Icons.receipt),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Total: $totalItems items available offline',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDataItem(String label, int count, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey[600], size: 24),
        const SizedBox(height: 4),
        Text(
          count.toString(),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
} 