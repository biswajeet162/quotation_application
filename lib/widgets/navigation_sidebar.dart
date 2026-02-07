import 'package:flutter/material.dart';

class NavigationSidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final bool isAdmin;

  const NavigationSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    this.isAdmin = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      color: Colors.grey[100],
      child: Column(
        children: [
          // Title
          Container(
            padding: const EdgeInsets.all(24.0),
            alignment: Alignment.centerLeft,
            child: const Text(
              'Quotation App',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          const Divider(height: 1),
          // Navigation Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _NavItem(
                  icon: Icons.inventory_2,
                  title: 'Products',
                  isSelected: selectedIndex == 0,
                  onTap: () => onItemSelected(0),
                ),
                _NavItem(
                  icon: Icons.dashboard,
                  title: 'Dashboard',
                  isSelected: selectedIndex == 1,
                  onTap: () => onItemSelected(1),
                ),
                _NavItem(
                  icon: Icons.description,
                  title: 'Make Quotation',
                  isSelected: selectedIndex == 2,
                  onTap: () => onItemSelected(2),
                ),
                _NavItem(
                  icon: Icons.history,
                  title: 'Quotation History',
                  isSelected: selectedIndex == 3,
                  onTap: () => onItemSelected(3),
                ),
                _NavItem(
                  icon: Icons.business,
                  title: 'Companies',
                  isSelected: selectedIndex == 4,
                  onTap: () => onItemSelected(4),
                ),
                if (isAdmin)
                  _NavItem(
                    icon: Icons.people,
                    title: 'User Management',
                    isSelected: selectedIndex == 5,
                    onTap: () => onItemSelected(5),
                  ),
                _NavItem(
                  icon: Icons.monitor,
                  title: 'Sync Monitor',
                  isSelected: selectedIndex == (isAdmin ? 6 : 5),
                  onTap: () => onItemSelected(isAdmin ? 6 : 5),
                ),
                _NavItem(
                  icon: Icons.settings,
                  title: 'Settings',
                  isSelected: selectedIndex == (isAdmin ? 7 : 6),
                  onTap: () => onItemSelected(isAdmin ? 7 : 6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: isSelected ? Colors.blue.withValues(alpha: 0.1) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(
              icon,
              color: Colors.black87,
              size: 24,
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                color: Colors.black87,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}



