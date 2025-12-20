import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CreditRecordPage extends StatelessWidget {
  const CreditRecordPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Debit Records - Track outstanding payments',
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.grey[600],
        ),
      ),
    );
  }
}
