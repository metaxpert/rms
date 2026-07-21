import 'package:flutter/material.dart';

/// Warm, appetite-forward palette that matches the RMS web module (amber primary,
/// semantic status colors reused from the KDS/floor views).
class AppTheme {
  static const primary = Color(0xFFD35400); // warm terracotta/amber
  static const bg = Color(0xFFFBF7F2);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF23180F),
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFEBE3D8)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEBE3D8)),
        ),
      ),
    );
  }

  /// Table/order status → (background, foreground) chip colors, mirroring the web STATUS_TONE.
  static (Color, Color) statusColors(String status) {
    switch (status) {
      case 'AVAILABLE':
      case 'READY':
      case 'SETTLED':
      case 'COMPLETED':
      case 'CONFIRMED':
        return (const Color(0xFFD6F5E3), const Color(0xFF1B7A4B));
      case 'OCCUPIED':
      case 'IN_PROGRESS':
      case 'PREPARING':
      case 'SERVED':
      case 'PLACED':
        return (const Color(0xFFD6ECF8), const Color(0xFF1F6390));
      case 'RESERVED':
      case 'WAITING':
      case 'QUEUED':
      case 'CLEANING':
        return (const Color(0xFFFBEBC8), const Color(0xFF8A5A20));
      case 'VOID':
      case 'CANCELLED':
        return (const Color(0xFFFAD7DD), const Color(0xFFA02840));
      default:
        return (const Color(0xFFEDE7DE), const Color(0xFF6B6055));
    }
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final String status;
  @override
  Widget build(BuildContext context) {
    final (bg, fg) = AppTheme.statusColors(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        status.replaceAll('_', ' ').toLowerCase(),
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// A food image with a warm gradient fallback (used when a dish has no photo / it fails to load).
class FoodImage extends StatelessWidget {
  const FoodImage({super.key, required this.url, required this.name, this.size, this.radius = 10});
  final String? url;
  final String name;
  final double? size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFBE4C4), Color(0xFFF3C7A0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        name.isEmpty ? '•' : name[0].toUpperCase(),
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFFB8621F)),
      ),
    );
    final child = url == null
        ? fallback
        : Image.network(
            url!,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback,
            loadingBuilder: (_, child, progress) =>
                progress == null ? child : Container(width: size, height: size, color: const Color(0xFFEDE7DE)),
          );
    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: child);
  }
}
