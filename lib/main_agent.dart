import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'login_screen.dart';
import 'agent_screen.dart';
import 'agent_qr_screen.dart';
import 'agent_lead.dart';
import 'navbar_agent.dart';
import 'reset_password.dart';

class MainAgent extends StatefulWidget {
  final int initialPage;

  const MainAgent({this.initialPage = 0, Key? key}) : super(key: key);

  @override
  State<MainAgent> createState() => _MainAgentState();
}

class _MainAgentState extends State<MainAgent> {
  late PageController _pageController;
  late int _currentPage;
  String? currentAgentEmail;
  bool isLoading = true;

  final List<String> _routes = ['/pengajuan', '/qrcode', '/lead'];

  void _checkAuth() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen()),
        (route) => false,
      );
      return;
    }

    setState(() {
      currentAgentEmail = user.email;
      isLoading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _pageController = PageController(initialPage: _currentPage)
      ..addListener(() {
        if (mounted) setState(() {});
      });
    _checkAuth();
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
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF0F4F5),
        body: Center(child: CircularProgressIndicator()),
      );
    }
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
            PopupMenuButton<String>(
              icon: SvgPicture.asset(
                'assets/icon/agent.svg',
                width: 24,
                height: 24,
                color: Colors.black,
              ),
              onSelected: (value) {
                if (value == 'logout') {
                  _logout();
                } else if (value == 'reset') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ResetPasswordAgentScreen(),
                    ),
                  );
                }
              },
              color: Colors.white,
              itemBuilder:
                  (BuildContext context) => [
                    PopupMenuItem<String>(
                      value: 'reset',
                      child: Row(
                        children: [
                          SvgPicture.asset(
                            'assets/icon/reset_password.svg',
                            width: 18,
                            height: 18,
                            color: Color(0xFF0E5C36),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Reset Password',
                            style: TextStyle(color: Color(0xFF0E5C36)),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem<String>(
                      value: 'logout',
                      child: Row(
                        children: [
                          SvgPicture.asset(
                            'assets/icon/logout.svg',
                            width: 18,
                            height: 18,
                            color: Color(0xFF0E5C36),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Logout',
                            style: TextStyle(color: Color(0xFF0E5C36)),
                          ),
                        ],
                      ),
                    ),
                  ],
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
              return AgentScreen();
            case 1:
              return AgentQRScreen();
            case 2:
              return AgentLead();
            default:
              return const SizedBox();
          }
        },
      ),
      bottomNavigationBar: BottomNavBarAgent(
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
