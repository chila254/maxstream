import 'package:flutter/material.dart';
import '../utils/index.dart';

class TvSplashScreen extends StatefulWidget {
  const TvSplashScreen({super.key});

  @override
  State<TvSplashScreen> createState() => _TvSplashScreenState();
}

class _TvSplashScreenState extends State<TvSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logoSize = TvUtils.responsiveFontSize(200, context, maxSize: 300);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: FadeTransition(
          opacity: _animation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/maxstream_logo.png',
                width: logoSize,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.play_circle_fill,
                    size: logoSize,
                    color: Colors.red,
                  );
                },
              ),
              SizedBox(height: TvUtils.responsivePadding(24, context)),
              Text(
                'MaxStream TV',
                style: TvTypography.heroTitle,
              ),
              SizedBox(height: TvUtils.responsivePadding(32, context)),
              SizedBox(
                width: TvUtils.responsiveFontSize(60, context, maxSize: 80),
                height: TvUtils.responsiveFontSize(60, context, maxSize: 80),
                child: const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                  strokeWidth: 4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
