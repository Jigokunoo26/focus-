import 'package:flutter/material.dart';

/// Helper class for responsive calculations across various mobile screen sizes
class ResponsiveUtils {
  static double horizontalPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 360) return 12.0;
    if (width > 600) return 24.0;
    return 16.0;
  }

  static double verticalPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 360) return 8.0;
    return 12.0;
  }

  static bool isCompact(BuildContext context) {
    return MediaQuery.of(context).size.width < 360;
  }

  static bool isTablet(BuildContext context) {
    return MediaQuery.of(context).size.width >= 600;
  }
}

/// Unified responsive layout wrapper ensuring consistent alignment, safe areas,
/// and max-width containment across compact phones, tall aspect ratios, and tablets.
class ResponsiveScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final double maxWidth;
  final bool scrollable;
  final EdgeInsetsGeometry? customPadding;
  final Color? backgroundColor;

  const ResponsiveScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.floatingActionButtonLocation,
    this.maxWidth = 680.0,
    this.scrollable = false,
    this.customPadding,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final hPadding = ResponsiveUtils.horizontalPadding(context);
    final vPadding = ResponsiveUtils.verticalPadding(context);
    final padding = customPadding ?? EdgeInsets.symmetric(
      horizontal: hPadding,
      vertical: vPadding,
    );

    Widget content = body;
    if (scrollable) {
      content = SingleChildScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: padding,
        child: content,
      );
    } else if (customPadding != null || padding != EdgeInsets.zero) {
      content = Padding(
        padding: padding,
        child: content,
      );
    }

    // Constrain to center column on wide screens (tablets, desktops, foldables)
    final constrainedBody = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: content,
      ),
    );

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: appBar,
      body: SafeArea(
        top: true,
        bottom: true,
        left: true,
        right: true,
        child: constrainedBody,
      ),
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
