import 'package:flutter/widgets.dart';

class MenuItem {
  final String title;
  final IconData icon;
  final bool isDestructive;
  final Function()? onTap;
  final Widget? customIcon;

  // constructor
  const MenuItem({
    required this.title,
    required this.icon,
    this.isDestructive = false,
    this.onTap,
    this.customIcon,
  });
}
