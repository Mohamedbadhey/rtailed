import 'package:flutter/material.dart';

class BeautifulDataTable extends StatelessWidget {
  final List<String> headers;
  final List<List<String>> data;
  final List<Color>? headerColors;
  final List<Color>? rowColors;
  final double? height;
  final bool showSearch;
  final bool showPagination;
  final int itemsPerPage;
  final Function(int)? onRowTap;
  final List<Widget>? actions;

  const BeautifulDataTable({
    super.key,
    required this.headers,
    required this.data,
    this.headerColors,
    this.rowColors,
    this.height,
    this.showSearch = true,
    this.showPagination = true,
    this.itemsPerPage = 10,
    this.onRowTap,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setState) {
        return _BeautifulDataTableState(
          headers: headers,
          data: data,
          headerColors: headerColors,
          rowColors: rowColors,
          height: height,
          showSearch: showSearch,
          showPagination: showPagination,
          itemsPerPage: itemsPerPage,
          onRowTap: onRowTap,
          actions: actions,
        );
      },
    );
  }
}

class _BeautifulDataTableState extends State<BeautifulDataTable> {
  final List<String> headers;
  final List<List<String>> data;
  final List<Color>? headerColors;
  final List<Color>? rowColors;
  final double? height;
  final bool showSearch;
  final bool showPagination;
  final int itemsPerPage;
  final Function(int)? onRowTap;
  final List<Widget>? actions;

  String searchQuery = '';
  int currentPage = 0;

  _BeautifulDataTableState({
    required this.headers,
    required this.data,
    this.headerColors,
    this.rowColors,
    this.height,
    required this.showSearch,
    required this.showPagination,
    required this.itemsPerPage,
    this.onRowTap,
    this.actions,
  });

  List<List<String>> get filteredData {
    if (searchQuery.isEmpty) {
      return data;
    }
    return data.where((row) {
      return row.any((cell) => 
        cell.toLowerCase().contains(searchQuery.toLowerCase())
      );
    }).toList();
  }

  List<List<String>> get paginatedData {
    final startIndex = currentPage * itemsPerPage;
    final endIndex = (startIndex + itemsPerPage).clamp(0, filteredData.length);
    return filteredData.sublist(startIndex, endIndex);
  }

  int get totalPages => (filteredData.length / itemsPerPage).ceil();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Header with search and actions
            if (showSearch || actions != null)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.primaryColor.withOpacity(0.1),
                      theme.primaryColor.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: [
                    if (showSearch) ...[
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[800] : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TextField(
                            onChanged: (value) {
                              setState(() {
                                searchQuery = value;
                                currentPage = 0;
                              });
                            },
                            decoration: InputDecoration(
                              hintText: 'Search...',
                              prefixIcon: Icon(
                                Icons.search,
                                color: theme.primaryColor,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                    if (actions != null) ...[
                      ...actions!,
                    ],
                  ],
                ),
              ),
            
            // Table
            Container(
              height: height ?? 400,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.white,
              ),
              child: Column(
                children: [
                  // Table Header
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: headerColors ?? [
                          theme.primaryColor,
                          theme.primaryColor.withOpacity(0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Row(
                      children: headers.map((header) {
                        return Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            child: Text(
                              header,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  
                  // Table Body
                  Expanded(
                    child: ListView.builder(
                      itemCount: paginatedData.length,
                      itemBuilder: (context, index) {
                        final row = paginatedData[index];
                        final isEven = index % 2 == 0;
                        
                        return Container(
                          decoration: BoxDecoration(
                            color: isEven 
                              ? (isDark ? Colors.grey[850] : Colors.grey[50])
                              : (isDark ? Colors.grey[900] : Colors.white),
                            border: Border(
                              bottom: BorderSide(
                                color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                                width: 0.5,
                              ),
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: onRowTap != null ? () => onRowTap!(index) : null,
                              child: Row(
                                children: row.map((cell) {
                                  return Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      child: Text(
                                        cell,
                                        style: TextStyle(
                                          color: isDark ? Colors.white : Colors.grey[800],
                                          fontSize: 13,
                                        ),
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            
            // Pagination
            if (showPagination && totalPages > 1)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[850] : Colors.grey[100],
                  border: Border(
                    top: BorderSide(
                      color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Showing ${(currentPage * itemsPerPage) + 1} to ${(currentPage + 1) * itemsPerPage} of ${filteredData.length} entries',
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    Row(
                      children: [
                        _buildPaginationButton(
                          icon: Icons.chevron_left,
                          onPressed: currentPage > 0
                            ? () => setState(() => currentPage--)
                            : null,
                        ),
                        const SizedBox(width: 8),
                        ...List.generate(
                          totalPages.clamp(0, 5),
                          (index) {
                            final page = index;
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: _buildPageButton(page),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildPaginationButton(
                          icon: Icons.chevron_right,
                          onPressed: currentPage < totalPages - 1
                            ? () => setState(() => currentPage++)
                            : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaginationButton({
    required IconData icon,
    VoidCallback? onPressed,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: onPressed != null 
          ? theme.primaryColor 
          : (isDark ? Colors.grey[700] : Colors.grey[300]),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: Icon(
          icon,
          color: onPressed != null ? Colors.white : Colors.grey,
          size: 20,
        ),
        onPressed: onPressed,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(
          minWidth: 32,
          minHeight: 32,
        ),
      ),
    );
  }

  Widget _buildPageButton(int page) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isActive = page == currentPage;
    
    return Container(
      decoration: BoxDecoration(
        color: isActive 
          ? theme.primaryColor 
          : (isDark ? Colors.grey[700] : Colors.grey[300]),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: () => setState(() => currentPage = page),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          child: Text(
            '${page + 1}',
            style: TextStyle(
              color: isActive ? Colors.white : Colors.grey[600],
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

// Beautiful Card Table for smaller data sets
class BeautifulCardTable extends StatelessWidget {
  final List<String> headers;
  final List<List<String>> data;
  final Color? cardColor;
  final bool showSearch;
  final Function(int)? onCardTap;

  const BeautifulCardTable({
    super.key,
    required this.headers,
    required this.data,
    this.cardColor,
    this.showSearch = true,
    this.onCardTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return StatefulBuilder(
      builder: (context, setState) {
        String searchQuery = '';
        
        List<List<String>> filteredData = data.where((row) {
          if (searchQuery.isEmpty) return true;
          return row.any((cell) => 
            cell.toLowerCase().contains(searchQuery.toLowerCase())
          );
        }).toList();

        return Column(
          children: [
            if (showSearch)
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[800] : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search...',
                      prefixIcon: Icon(
                        Icons.search,
                        color: theme.primaryColor,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ),
            
            Expanded(
              child: ListView.builder(
                itemCount: filteredData.length,
                itemBuilder: (context, index) {
                  final row = filteredData[index];
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: cardColor ?? (isDark ? Colors.grey[850] : Colors.white),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onCardTap != null ? () => onCardTap!(index) : null,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: row.asMap().entries.map((entry) {
                              final headerIndex = entry.key;
                              final value = entry.value;
                              
                              return Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        headers[headerIndex],
                                        style: TextStyle(
                                          color: theme.primaryColor,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        value,
                                        style: TextStyle(
                                          color: isDark ? Colors.white : Colors.grey[800],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
} 