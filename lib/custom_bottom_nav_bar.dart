import 'package:flutter/material.dart';
import 'main_page.dart'; // Jangan lupa import

class CustomBottomNavBar extends StatelessWidget {
  final String currentRoute;
  final Function(int)? onTapIndex;
  final double pageOffset; // <--- Tambahin ini!

  const CustomBottomNavBar({
    required this.currentRoute,
    this.onTapIndex,
    this.pageOffset = 0.0, // <--- Default supaya backward compatible
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

    return BottomNavigationBar(
      currentIndex: activeIndex ?? 0,
      selectedItemColor: const Color(0xFF0E5C36),
      unselectedItemColor: Colors.black,
      type: BottomNavigationBarType.fixed,
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
      selectedFontSize: 14,
      unselectedFontSize: 14,
    );
  }

  BottomNavigationBarItem _buildNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required bool isMainScreen,
    required int itemIndex, // <--- Tambah ini
  }) {
    final double distance = (pageOffset - itemIndex).abs().clamp(0.0, 1.0);
    final double verticalOffset = isMainScreen ? (15 * distance) : 5;

    return BottomNavigationBarItem(
      icon: Transform.translate(
        offset: Offset(0, verticalOffset),
        child: Icon(
          icon,
          color: isSelected ? const Color(0xFF0E5C36) : Colors.black,
        ),
      ),
      label: isSelected ? label : '',
    );
  }
}
