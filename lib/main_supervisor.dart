import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'login_screen.dart';
import 'supervisor_pengajuan.dart';
import 'supervisor_pendaftaran.dart';
import 'supervisor_lead.dart';
import 'navbar_supervisor.dart';

class MainSupervisor extends StatefulWidget {
  final int initialPage;

  const MainSupervisor({this.initialPage = 0, Key? key}) : super(key: key);

  @override
  State<MainSupervisor> createState() => _MainSupervisorState();
}

class _MainSupervisorState extends State<MainSupervisor> {
  late PageController _pageController;
  late int _currentPage;

  final List<String> _routes = ['/pengajuan', '/pendaftaran', '/lead'];

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _pageController = PageController(initialPage: _currentPage)
      ..addListener(() {
        if (mounted) setState(() {});
      });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final double pageOffset =
        _pageController.hasClients
            ? _pageController.page ?? _currentPage.toDouble()
            : _currentPage.toDouble();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F5),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFFF0F4F5),
        elevation: 0,
        foregroundColor: Colors.black,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Color(0xFFF0F4F5),
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        title: Row(
          children: [
            RichText(
              text: const TextSpan(
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                children: [
                  TextSpan(
                    text: 'Supervisor ',
                    style: TextStyle(color: Color(0xFF0E5C36)),
                  ),
                  TextSpan(
                    text: 'Mode',
                    style: TextStyle(color: Color(0xFFE67D13)),
                  ),
                ],
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.black),
              onPressed: _logout,
            ),
          ],
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        physics: const BouncingScrollPhysics(),
        itemCount: _routes.length,
        onPageChanged: (index) => setState(() => _currentPage = index),
        itemBuilder: (context, index) {
          switch (index) {
            case 0:
              return PengajuanSupervisor();
            case 1:
              return PendaftaranSupervisor();
            case 2:
              return LeadSupervisor();
            default:
              return const SizedBox();
          }
        },
      ),
      bottomNavigationBar: BottomNavBarSupervisor(
        currentRoute: _routes[_currentPage],
        onTapIndex: (index) {
          if (_currentPage != index) {
            _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
            );
            setState(() => _currentPage = index);
          }
        },
        pageOffset: pageOffset,
      ),
    );
  }
}
