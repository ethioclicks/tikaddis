import 'package:flutter/material.dart';

/// App logo + "Tikaddis" wordmark in a single colour, used on the blue
/// gradient splash and launch screens. The logo PNG is transparent, so it is
/// tinted to [color] to read as a clean mono mark.
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.logoHeight = 56,
    this.fontSize = 30,
    this.color = Colors.white,
  });

  final double logoHeight;
  final double fontSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Tikaddis',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ColorFiltered(
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              child: Image.asset(
                'assets/images/logo.png',
                height: logoHeight,
                fit: BoxFit.contain,
              ),
            ),
            SizedBox(width: logoHeight * 0.02),
            Text(
              'Tikaddis',
              style: TextStyle(
                color: color,
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
