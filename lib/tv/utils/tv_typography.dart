import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Modern Typography System for MaxStream TV
/// Uses Google Fonts and hierarchical font weights
class TvTypography {
  // Font families
  static const String primaryFont = 'Inter';
  static const String accentFont = 'Poppins';

  /// Hero/Banner Titles - Largest, boldest
  /// Used for: Main hero banners, page titles
  static TextStyle get heroTitle => GoogleFonts.inter(
        fontSize: 56,
        fontWeight: FontWeight.w900,
        height: 1.2,
        letterSpacing: -0.5,
        color: Colors.white,
      );

  /// Section Titles - Large, bold
  /// Used for: "Trending Now", "Popular Series", section headers
  static TextStyle get sectionTitle => GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.3,
        letterSpacing: -0.3,
        color: Colors.white,
      );

  /// Subsection Titles - Medium-large
  /// Used for: Category headers, "See More" buttons
  static TextStyle get subsectionTitle => GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.4,
        letterSpacing: -0.2,
        color: Colors.white,
      );

  /// Card Titles - Medium
  /// Used for: Content card titles (movies, series)
  static TextStyle get cardTitle => GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.4,
        letterSpacing: 0,
        color: Colors.white,
      );

  /// Body Text - Regular
  /// Used for: Descriptions, overviews, longer text
  static TextStyle get bodyLarge => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.6,
        letterSpacing: 0.3,
        color: Colors.white,
      );

  /// Body Text - Medium
  /// Used for: Standard descriptions, metadata
  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
        letterSpacing: 0.2,
        color: Colors.white70,
      );

  /// Label Text - Small
  /// Used for: Badges, tags, small labels, duration
  static TextStyle get labelSmall => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.4,
        letterSpacing: 0.5,
        color: Colors.white,
      );

  /// Caption Text - Extra small
  /// Used for: Ratings, years, small metadata
  static TextStyle get caption => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        height: 1.3,
        letterSpacing: 0.3,
        color: Colors.white70,
      );

  /// Button Text - Medium, bold
  /// Used for: "Play", "See More", "Add to Watchlist"
  static TextStyle get buttonText => GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.4,
        letterSpacing: 0.5,
        color: Colors.white,
      );

  /// Overline/Accent - Small, bold
  /// Used for: "NEW", "TRENDING", "FEATURED"
  static TextStyle get overline => GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        height: 1.3,
        letterSpacing: 1.5,
        color: Colors.white,
      );

  /// Gradient/Accent Title
  /// Used for: Special featured content
  static TextStyle get accentTitle => GoogleFonts.poppins(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.3,
        letterSpacing: -0.2,
        color: Colors.white,
      );
}

/// Responsive Typography - Scales based on screen size
class ResponsiveTypography {
  static TextStyle heroTitle(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 768;
    final isTablet = width >= 768 && width < 1280;

    if (isMobile) {
      return GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w900,
        height: 1.2,
        letterSpacing: -0.3,
        color: Colors.white,
      );
    } else if (isTablet) {
      return GoogleFonts.inter(
        fontSize: 44,
        fontWeight: FontWeight.w900,
        height: 1.2,
        letterSpacing: -0.4,
        color: Colors.white,
      );
    } else {
      return TvTypography.heroTitle;
    }
  }

  static TextStyle sectionTitle(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 768;
    final isTablet = width >= 768 && width < 1280;

    if (isMobile) {
      return GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.3,
        letterSpacing: -0.2,
        color: Colors.white,
      );
    } else if (isTablet) {
      return GoogleFonts.inter(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        height: 1.3,
        letterSpacing: -0.2,
        color: Colors.white,
      );
    } else {
      return TvTypography.sectionTitle;
    }
  }

  static TextStyle cardTitle(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 768;

    if (isMobile) {
      return GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.4,
        letterSpacing: 0,
        color: Colors.white,
      );
    } else {
      return TvTypography.cardTitle;
    }
  }
}

/// Spacing System - Consistent spacing values
class TvSpacing {
  // Base spacing unit (8dp)
  static const double xs = 4; // 0.5x
  static const double sm = 8; // 1x
  static const double md = 12; // 1.5x
  static const double lg = 16; // 2x
  static const double xl = 24; // 3x
  static const double xxl = 32; // 4x
  static const double huge = 48; // 6x
  static const double mega = 64; // 8x

  /// Section padding (horizontal)
  static const double sectionPaddingH = xxl; // 32px

  /// Section padding (vertical)
  static const double sectionPaddingV = xl; // 24px

  /// Card spacing in lists
  static const double cardSpacing = lg; // 16px

  /// Between title and content
  static const double titleGap = md; // 12px

  /// Between content sections
  static const double sectionGap = xl; // 24px

  /// Large gap between major sections
  static const double largeGap = huge; // 48px

  /// Safe area padding (TV edges)
  static const double safeAreaPadding = xxl; // 32px
}

/// Text Styles with Common Variants
class TvTextStyles {
  /// Hero banner title
  static TextStyle get heroBannerTitle => GoogleFonts.inter(
        fontSize: 48,
        fontWeight: FontWeight.bold,
        height: 1.2,
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(2, 2),
          ),
        ],
      );

  /// Section header with accent
  static TextStyle get sectionHeader => GoogleFonts.poppins(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: Colors.white,
      );

  /// Featured badge text
  static TextStyle get featuredBadge => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
        color: const Color(0xFFE50914),
      );

  /// New release badge
  static TextStyle get newBadge => GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: Colors.amber,
      );

  /// Trending indicator
  static TextStyle get trendingLabel => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: Colors.white70,
      );

  /// Subtitle/descriptor
  static TextStyle get subtitle => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.2,
        color: Colors.white70,
        height: 1.5,
      );

  /// Meta information (year, duration)
  static TextStyle get metadata => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.3,
        color: Colors.white60,
      );

  /// Genre tags
  static TextStyle get genreTag => GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
        color: Colors.white70,
      );
}

/// Theme Data Extension for Typography
extension TypographyTheme on ThemeData {
  /// Get typography set
  TvTypography get tvTypography => TvTypography();

  /// Get spacing system
  TvSpacing get tvSpacing => TvSpacing();

  /// Get text styles
  TvTextStyles get tvTextStyles => TvTextStyles();
}
