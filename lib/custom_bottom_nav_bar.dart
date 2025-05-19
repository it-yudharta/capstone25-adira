import 'package:flutter/material.dart';
import 'admin_pengajuan_screen.dart';

class CustomBottomNavBar extends StatelessWidget {
  final String currentRoute;
  final Function(int)? onTapIndex;
  final double pageOffset;
  final bool showOnlyEssentialButtons;

  const CustomBottomNavBar({
    required this.currentRoute,
    this.onTapIndex,
    this.pageOffset = 0.0,
    this.showOnlyEssentialButtons = false,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final routes = ['/pengajuan', '/saved'];

    final activeIndex = routes.indexOf(currentRoute);
    final safeIndex = activeIndex < 0 ? 0 : activeIndex;
    final bool isMainScreen = routes.contains(currentRoute);

    return Theme(
      data: Theme.of(context).copyWith(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
      ),
      child: BottomNavigationBar(
        backgroundColor: const Color(0xFFF0F4F5),
        currentIndex: safeIndex,
        selectedItemColor: const Color(0xFF0E5C36),
        unselectedItemColor: Colors.black,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        onTap: (index) {
          if (onTapIndex != null) {
            onTapIndex!(index);
          } else if (activeIndex != index) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => AdminPengajuanScreen(initialPage: index),
              ),
              (route) => false,
            );
          }
        },
        selectedFontSize: 14,
        unselectedFontSize: 14,
        items: [
          _buildNavItem(
            icon: Icons.insert_drive_file,
            label: 'Pengajuan',
            isSelected: currentRoute == '/pengajuan',
            isMainScreen: true,
            itemIndex: 0,
          ),
          _buildNavItem(
            icon: Icons.bookmark,
            label: 'Lead',
            isSelected: currentRoute == '/saved',
            isMainScreen: true,
            itemIndex: 1,
          ),
        ],
      ),
    );
  }

  BottomNavigationBarItem _buildNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required bool isMainScreen,
    required int itemIndex,
  }) {
    final double distance = (pageOffset - itemIndex).abs().clamp(0.0, 1.0);
    final double verticalOffset = isMainScreen ? (8 * distance) : 0;

    return BottomNavigationBarItem(
      icon: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Transform.translate(
            offset: Offset(0, verticalOffset),
            child: Icon(
              icon,
              size: 24,
              color: isSelected ? const Color(0xFF0E5C36) : Colors.black,
            ),
          ),
          const SizedBox(height: 2),
          AnimatedOpacity(
            opacity: isSelected ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? const Color(0xFF0E5C36) : Colors.black,
              ),
            ),
          ),
        ],
      ),
      label: '',
    );
  }
}
