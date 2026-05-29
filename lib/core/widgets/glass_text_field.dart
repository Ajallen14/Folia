import 'package:flutter/material.dart';

class GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final bool isNumber;
  final bool isCenter;
  final String? Function(String?)? validator;

  const GlassTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.icon,
    this.isNumber = false,
    this.isCenter = false,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      textAlign: isCenter ? TextAlign.center : TextAlign.start,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      validator: validator,
      decoration: InputDecoration(
        prefixIcon: isCenter || icon == null
            ? null
            : Icon(icon, color: Colors.white54, size: 20),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: isCenter ? 15 : 12,
        ),
      ),
    );
  }
}
