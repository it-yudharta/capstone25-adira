import 'package:flutter/material.dart';
import 'main_supervisor.dart';

class BottomNavBarSupervisor extends StatelessWidget {
  final String currentRoute;
  final Function(int)? onTapIndex;
  final double pageOffset;

  const BottomNavBarSupervisor({
    required this.currentRoute,
    this.onTapIndex,
    this.pageOffset = 0.0,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final routes = ['/pengajuan', '/pendaftaran', '/lead'];
    final activeIndex = routes.indexOf(currentRoute);
    final bool isMainScreen = activeIndex != -1;
    final safeIndex = isMainScreen ? activeIndex : 0;

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
        selectedFontSize: 14,
        unselectedFontSize: 14,
        onTap: (index) {
          if (isMainScreen) {
            if (onTapIndex != null) {
              onTapIndex!(index);
            } else if (index != activeIndex) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => MainSupervisor(initialPage: index),
                ),
                (route) => false,
              );
            }
          } else {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (_) => MainSupervisor(initialPage: index),
              ),
              (route) => false,
            );
          }
        },
        items: [
          _buildNavItem(
            icon: Icons.assignment,
            label: 'Pengajuan',
            isSelected: currentRoute == '/pengajuan',
            isMainScreen: isMainScreen,
            itemIndex: 0,
          ),
          _buildNavItem(
            icon: Icons.app_registration,
            label: 'Pendaftaran',
            isSelected: currentRoute == '/pendaftaran',
            isMainScreen: isMainScreen,
            itemIndex: 1,
          ),
          _buildNavItem(
            icon: Icons.bookmark,
            label: 'Lead',
            isSelected: currentRoute == '/lead',
            isMainScreen: isMainScreen,
            itemIndex: 2,
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
