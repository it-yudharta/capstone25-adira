import 'package:flutter/material.dart';
import 'main_page.dart';

class CustomBottomNavBar extends StatelessWidget {
  final String currentRoute;
  final Function(int)? onTapIndex;
  final double pageOffset;

  const CustomBottomNavBar({
    required this.currentRoute,
    this.onTapIndex,
    this.pageOffset = 0.0,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    int? getIndexFromRoute(String route) {
      switch (route) {
        case '/pengajuan':
          return 0;
        case '/qr':
          return 1;
        case '/pendaftaran':
          return 2;
        case '/saved':
          return 3;
        default:
          return null;
      }
    }

    final routes = ['/pengajuan', '/qr', '/pendaftaran', '/saved'];
    final activeIndex = getIndexFromRoute(currentRoute);
    final bool isMainScreen = routes.contains(currentRoute);

    return Theme(
      data: Theme.of(context).copyWith(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
      ),
      child: BottomNavigationBar(
        backgroundColor: const Color(0xFFF0F4F5),
        currentIndex: activeIndex ?? 0,
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
                builder: (context) => MainPage(initialPage: index),
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
            isSelected: activeIndex == 0 && isMainScreen,
            isMainScreen: isMainScreen,
            itemIndex: 0,
          ),
          _buildNavItem(
            icon: Icons.qr_code,
            label: 'QR Code',
            isSelected: activeIndex == 1 && isMainScreen,
            isMainScreen: isMainScreen,
            itemIndex: 1,
          ),
          _buildNavItem(
            icon: Icons.assignment,
            label: 'Pendaftaran',
            isSelected: activeIndex == 2 && isMainScreen,
            isMainScreen: isMainScreen,
            itemIndex: 2,
          ),
          _buildNavItem(
            icon: Icons.bookmark,
            label: 'Lead',
            isSelected: activeIndex == 3 && isMainScreen,
            isMainScreen: isMainScreen,
            itemIndex: 3,
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
