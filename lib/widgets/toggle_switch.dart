import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ToggleSwitch extends StatelessWidget {
  final bool isPersonal;
  final VoidCallback onToggle;

  const ToggleSwitch({
    super.key,
    required this.isPersonal,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildOption(context, 'Personal', isPersonal),
            _buildOption(context, 'Ledger', !isPersonal),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(BuildContext context, String label, bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFFBFA2DB)
            : Colors.transparent, // Light purple accent
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: isActive ? Colors.black87 : Colors.white70,
          fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
          fontSize: 13,
        ),
      ),
    );
  }
}
