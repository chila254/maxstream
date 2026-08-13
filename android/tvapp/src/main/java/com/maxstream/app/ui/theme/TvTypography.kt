package com.maxstream.app.ui.theme

import androidx.compose.runtime.Composable
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.material3.Typography

object TvTypography {
    const val primaryFont = "Inter"
    const val accentFont = "Poppins"

    val heroTitle: TextStyle
        get() = TextStyle(
            fontFamily = FontFamily.Default,
            fontSize = 56.sp,
            fontWeight = FontWeight.W900,
            lineHeight = 1.2.sp,
            letterSpacing = (-0.5).sp,
            color = Color.White,
        )

    val sectionTitle: TextStyle
        get() = TextStyle(
            fontFamily = FontFamily.Default,
            fontSize = 32.sp,
            fontWeight = FontWeight.W700,
            lineHeight = 1.3.sp,
            letterSpacing = (-0.3).sp,
            color = Color.White,
        )

    val subsectionTitle: TextStyle
        get() = TextStyle(
            fontFamily = FontFamily.Default,
            fontSize = 24.sp,
            fontWeight = FontWeight.W600,
            lineHeight = 1.4.sp,
            letterSpacing = (-0.2).sp,
            color = Color.White,
        )

    val cardTitle: TextStyle
        get() = TextStyle(
            fontFamily = FontFamily.Default,
            fontSize = 16.sp,
            fontWeight = FontWeight.W600,
            lineHeight = 1.4.sp,
            letterSpacing = 0.sp,
            color = Color.White,
        )

    val bodyLarge: TextStyle
        get() = TextStyle(
            fontFamily = FontFamily.Default,
            fontSize = 16.sp,
            fontWeight = FontWeight.Normal,
            lineHeight = 1.6.sp,
            letterSpacing = 0.3.sp,
            color = Color.White,
        )

    val bodyMedium: TextStyle
        get() = TextStyle(
            fontFamily = FontFamily.Default,
            fontSize = 14.sp,
            fontWeight = FontWeight.Normal,
            lineHeight = 1.5.sp,
            letterSpacing = 0.2.sp,
            color = Color.White.copy(alpha = 0.7f),
        )

    val labelSmall: TextStyle
        get() = TextStyle(
            fontFamily = FontFamily.Default,
            fontSize = 12.sp,
            fontWeight = FontWeight.Medium,
            lineHeight = 1.4.sp,
            letterSpacing = 0.5.sp,
            color = Color.White,
        )

    val caption: TextStyle
        get() = TextStyle(
            fontFamily = FontFamily.Default,
            fontSize = 11.sp,
            fontWeight = FontWeight.Normal,
            lineHeight = 1.3.sp,
            letterSpacing = 0.3.sp,
            color = Color.White.copy(alpha = 0.7f),
        )

    val buttonText: TextStyle
        get() = TextStyle(
            fontFamily = FontFamily.Default,
            fontSize = 14.sp,
            fontWeight = FontWeight.W600,
            lineHeight = 1.4.sp,
            letterSpacing = 0.5.sp,
            color = Color.White,
        )

    val overline: TextStyle
        get() = TextStyle(
            fontFamily = FontFamily.Default,
            fontSize = 10.sp,
            fontWeight = FontWeight.W700,
            lineHeight = 1.3.sp,
            letterSpacing = 1.5.sp,
            color = Color.White,
        )

    val accentTitle: TextStyle
        get() = TextStyle(
            fontFamily = FontFamily.Default,
            fontSize = 28.sp,
            fontWeight = FontWeight.W700,
            lineHeight = 1.3.sp,
            letterSpacing = (-0.2).sp,
            color = Color.White,
        )
}

object ResponsiveTypography {
    @Composable
    fun heroTitle(): TextStyle {
        val width = LocalConfiguration.current.screenWidthDp.dp
        return when {
            width < 768.dp -> TextStyle(
                fontFamily = FontFamily.Default,
                fontSize = 32.sp,
                fontWeight = FontWeight.W900,
                lineHeight = 1.2.sp,
                letterSpacing = (-0.3).sp,
                color = Color.White,
            )
            width < 1280.dp -> TextStyle(
                fontFamily = FontFamily.Default,
                fontSize = 44.sp,
                fontWeight = FontWeight.W900,
                lineHeight = 1.2.sp,
                letterSpacing = (-0.4).sp,
                color = Color.White,
            )
            else -> TvTypography.heroTitle
        }
    }

    @Composable
    fun sectionTitle(): TextStyle {
        val width = LocalConfiguration.current.screenWidthDp.dp
        return when {
            width < 768.dp -> TextStyle(
                fontFamily = FontFamily.Default,
                fontSize = 20.sp,
                fontWeight = FontWeight.W700,
                lineHeight = 1.3.sp,
                letterSpacing = (-0.2).sp,
                color = Color.White,
            )
            width < 1280.dp -> TextStyle(
                fontFamily = FontFamily.Default,
                fontSize = 26.sp,
                fontWeight = FontWeight.W700,
                lineHeight = 1.3.sp,
                letterSpacing = (-0.2).sp,
                color = Color.White,
            )
            else -> TvTypography.sectionTitle
        }
    }

    @Composable
    fun cardTitle(): TextStyle {
        val width = LocalConfiguration.current.screenWidthDp.dp
        return if (width < 768.dp) {
            TextStyle(
                fontFamily = FontFamily.Default,
                fontSize = 14.sp,
                fontWeight = FontWeight.W600,
                lineHeight = 1.4.sp,
                letterSpacing = 0.sp,
                color = Color.White,
            )
        } else {
            TvTypography.cardTitle
        }
    }
}

object TvSpacing {
    val xs = 4.dp
    val sm = 8.dp
    val md = 12.dp
    val lg = 16.dp
    val xl = 24.dp
    val xxl = 32.dp
    val huge = 48.dp
    val mega = 64.dp

    val sectionPaddingH = xxl
    val sectionPaddingV = xl
    val cardSpacing = lg
    val titleGap = md
    val sectionGap = xl
    val largeGap = huge
    val safeAreaPadding = xxl
}

object TvTextStyles {
    val heroBannerTitle: TextStyle
        get() = TextStyle(
            fontFamily = FontFamily.Default,
            fontSize = 48.sp,
            fontWeight = FontWeight.Bold,
            lineHeight = 1.2.sp,
            shadow = Shadow(
                color = Color.Black.copy(alpha = 0.5f),
                offset = androidx.compose.ui.geometry.Offset(2f, 2f),
                blurRadius = 10f
            )
        )

    val sectionHeader: TextStyle
        get() = TextStyle(
            fontFamily = FontFamily.Default,
            fontSize = 28.sp,
            fontWeight = FontWeight.W700,
            letterSpacing = (-0.5).sp,
            color = Color.White,
        )

    val featuredBadge: TextStyle
        get() = TextStyle(
            fontFamily = FontFamily.Default,
            fontSize = 11.sp,
            fontWeight = FontWeight.W700,
            letterSpacing = 1.5.sp,
            color = Color(0xFFE50914),
        )

    val newBadge: TextStyle
        get() = TextStyle(
            fontFamily = FontFamily.Default,
            fontSize = 10.sp,
            fontWeight = FontWeight.W700,
            letterSpacing = 1.2.sp,
            color = Color(0xFFFFEB3B),
        )

    val trendingLabel: TextStyle
        get() = TextStyle(
            fontFamily = FontFamily.Default,
            fontSize = 12.sp,
            fontWeight = FontWeight.W600,
            letterSpacing = 0.5.sp,
            color = Color.White.copy(alpha = 0.7f),
        )

    val subtitle: TextStyle
        get() = TextStyle(
            fontFamily = FontFamily.Default,
            fontSize = 13.sp,
            fontWeight = FontWeight.Normal,
            letterSpacing = 0.2.sp,
            color = Color.White.copy(alpha = 0.7f),
            lineHeight = 1.5.sp,
        )

    val metadata: TextStyle
        get() = TextStyle(
            fontFamily = FontFamily.Default,
            fontSize = 12.sp,
            fontWeight = FontWeight.Normal,
            letterSpacing = 0.3.sp,
            color = Color.White.copy(alpha = 0.6f),
        )

    val genreTag: TextStyle
        get() = TextStyle(
            fontFamily = FontFamily.Default,
            fontSize = 11.sp,
            fontWeight = FontWeight.Medium,
            letterSpacing = 0.2.sp,
            color = Color.White.copy(alpha = 0.7f),
        )
}

val Typography.tvTypography: TvTypography
    get() = TvTypography

val Typography.tvSpacing: TvSpacing
    get() = TvSpacing

val Typography.tvTextStyles: TvTextStyles
    get() = TvTextStyles
