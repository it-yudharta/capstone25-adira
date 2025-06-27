// ignore_for_file: use_super_parameters, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'login_screen.dart';
import 'pendaftaran_screen.dart';
import 'generate_qr_screen.dart';
import 'saved_pendaftaran_screen.dart';
import 'bottom_nav_bar_pendaftaran.dart';

class AdminPendaftaranScreen extends StatefulWidget {
  final int initialPage;

  const AdminPendaftaranScreen({this.initialPage = 0, Key? key})
    : super(key: key);

  @override
  State<AdminPendaftaranScreen> createState() => _AdminPendaftaranScreenState();
}

class _AdminPendaftaranScreenState extends State<AdminPendaftaranScreen> {
  late PageController _pageController;
  late int _currentPage;

  final List<String> _routes = ['/pendaftaran', '/qr', '/saved_pendaftaran'];

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _pageController = PageController(initialPage: _currentPage)
      ..addListener(() {
        if (mounted) {
          setState(() {});
        }
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
                    text: 'Fundra',
                    style: TextStyle(color: Color(0xFF0E5C36)),
                  ),
                  TextSpan(
                    text: 'IN',
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
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        itemCount: _routes.length,
        onPageChanged: (index) => setState(() => _currentPage = index),
        itemBuilder: (context, index) {
          switch (index) {
            case 0:
              return PendaftaranScreen();
            case 1:
              return GenerateQRScreen();
            case 2:
              return SavedPendaftaranScreen();
            default:
              return const SizedBox();
          }
        },
      ),
      bottomNavigationBar: BottomNavBarPendaftaran(
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
