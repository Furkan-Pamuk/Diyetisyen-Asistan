import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'screens/auth_gate.dart';
import 'services/notification_service.dart';
import 'state/app_store.dart';
import 'theme/app_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await initializeDateFormatting('tr_TR', null);
  } catch (e) {
    debugPrint('Tarih yerelleştirme başlatılamadı: $e');
  }
  await NotificationService.instance.init();
  final store = AppStore();
  await store.init();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    store.firebaseReady = true;
  } catch (e) {
    debugPrint('Firebase başlatılamadı (yerel mod): $e');
  }
  runApp(DietitianApp(store: store));
}

class DietitianApp extends StatelessWidget {
  final AppStore store;
  const DietitianApp({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    // Base font: Plus Jakarta Sans for ultra-modern, crisp and elegant typography
    final baseTextTheme = GoogleFonts.plusJakartaSansTextTheme(
      ThemeData.light().textTheme,
    ).apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    );

    return ChangeNotifierProvider.value(
      value: store,
      child: MaterialApp(
        title: 'Diyetisyen Asistanı',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: AppColors.surface,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            primary: AppColors.primary,
            secondary: AppColors.primaryAccent,
            surface: AppColors.surface,
            error: AppColors.error,
          ),
          textTheme: baseTextTheme.copyWith(
            displayLarge: GoogleFonts.plusJakartaSans(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
              color: AppColors.text,
            ),
            headlineMedium: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: AppColors.text,
            ),
            titleLarge: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              letterSpacing: -0.3,
              color: AppColors.text,
            ),
            titleMedium: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              letterSpacing: -0.2,
              color: AppColors.text,
            ),
            bodyLarge: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              letterSpacing: -0.1,
              color: AppColors.text,
            ),
            bodyMedium: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
            bodySmall: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: AppColors.muted,
            ),
          ),
          cardTheme: CardThemeData(
            color: AppColors.card,
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.cardBorder, width: 1),
            ),
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: AppColors.text,
            elevation: 0,
            scrolledUnderElevation: 0.5,
            centerTitle: false,
            titleTextStyle: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              color: AppColors.text,
            ),
            iconTheme: const IconThemeData(color: AppColors.textSecondary),
            actionsIconTheme: const IconThemeData(color: AppColors.textSecondary),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.text,
              side: const BorderSide(color: AppColors.cardBorder, width: 1.2),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          floatingActionButtonTheme: FloatingActionButtonThemeData(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.cardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            hintStyle: GoogleFonts.plusJakartaSans(
              color: AppColors.muted,
              fontSize: 14,
            ),
          ),
          dividerTheme: const DividerThemeData(
            color: AppColors.divider,
            thickness: 1,
            space: 1,
          ),
          navigationBarTheme: NavigationBarThemeData(
            height: 68,
            backgroundColor: Colors.white,
            indicatorColor: AppColors.primaryMuted,
            elevation: 4,
            labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>(
              (states) => states.contains(WidgetState.selected)
                  ? GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: AppColors.primary,
                    )
                  : GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
            ),
          ),
        ),
        home: const AuthGate(),
      ),
    );
  }
}

String fmtDay(DateTime d) {
  try {
    return DateFormat.yMMMd('tr_TR').format(d);
  } catch (_) {
    return DateFormat.yMMMd().format(d);
  }
}

String fmtFullDay(DateTime d) {
  try {
    return DateFormat.yMMMMEEEEd('tr_TR').format(d);
  } catch (_) {
    return DateFormat.yMMMMEEEEd().format(d);
  }
}
