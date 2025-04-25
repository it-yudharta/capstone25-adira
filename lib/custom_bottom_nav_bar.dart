import 'package:flutter/material.dart';

class CustomBottomNavBar extends StatelessWidget {
  final String currentRoute;

  const CustomBottomNavBar({required this.currentRoute, super.key});

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

    // Check if the current route is one of the main navbar screens
    bool isMainScreen = routes.contains(currentRoute);

    return BottomNavigationBar(
      currentIndex: activeIndex ?? 0,
      selectedItemColor: const Color(0xFF0E5C36),
      unselectedItemColor: Colors.black,
      type: BottomNavigationBarType.fixed,
      onTap: (index) {
        if (activeIndex != index) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            routes[index],
            (route) => false,
          );
        }
      },
      items: [
        BottomNavigationBarItem(
          icon: Transform.translate(
            offset: Offset(
              0,
              isMainScreen
                  ? (activeIndex == 0
                      ? 0
                      : 15) // More drop for inactive icons on main screens
                  : (activeIndex == 0
                      ? 0
                      : 5), // Less drop for inactive icons on other screens
            ),
            child: Icon(
              Icons.insert_drive_file,
              color: activeIndex == 0 ? const Color(0xFF0E5C36) : Colors.black,
            ),
          ),
          label: activeIndex == 0 ? 'Pengajuan' : '',
        ),
        BottomNavigationBarItem(
          icon: Transform.translate(
            offset: Offset(
              0,
              isMainScreen
                  ? (activeIndex == 1
                      ? 0
                      : 15) // More drop for inactive icons on main screens
                  : (activeIndex == 1
                      ? 0
                      : 5), // Less drop for inactive icons on other screens
            ),
            child: Icon(
              Icons.qr_code,
              color: activeIndex == 1 ? const Color(0xFF0E5C36) : Colors.black,
            ),
          ),
          label: activeIndex == 1 ? 'QR Code' : '',
        ),
        BottomNavigationBarItem(
          icon: Transform.translate(
            offset: Offset(
              0,
              isMainScreen
                  ? (activeIndex == 2
                      ? 0
                      : 15) // More drop for inactive icons on main screens
                  : (activeIndex == 2
                      ? 0
                      : 5), // Less drop for inactive icons on other screens
            ),
            child: Icon(
              Icons.assignment,
              color: activeIndex == 2 ? const Color(0xFF0E5C36) : Colors.black,
            ),
          ),
          label: activeIndex == 2 ? 'Pendaftaran' : '',
        ),
        BottomNavigationBarItem(
          icon: Transform.translate(
            offset: Offset(
              0,
              isMainScreen
                  ? (activeIndex == 3
                      ? 0
                      : 15) // More drop for inactive icons on main screens
                  : (activeIndex == 3
                      ? 0
                      : 5), // Less drop for inactive icons on other screens
            ),
            child: Icon(
              Icons.bookmark,
              color: activeIndex == 3 ? const Color(0xFF0E5C36) : Colors.black,
            ),
          ),
          label: activeIndex == 3 ? 'Lead' : '',
        ),
      ],
      selectedFontSize: activeIndex != null ? 14 : 0,
      unselectedFontSize: 14,
    );
  }
}
