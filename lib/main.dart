import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/music_provider.dart';
import 'providers/player_provider.dart';
import 'providers/playlist_provider.dart';
import 'providers/bilibili_provider.dart';
import 'screens/welcome_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LitMusicApp());
}

class LitMusicApp extends StatelessWidget {
  const LitMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => MusicProvider()),
        ChangeNotifierProvider(create: (_) => PlayerProvider()),
        ChangeNotifierProvider(create: (_) => PlaylistProvider()),
        ChangeNotifierProvider(create: (_) => BilibiliProvider()),
      ],
      child: Builder(
        builder: (ctx) {
          // Wire up duration lazy-load: when the player discovers a song's
          // real duration, update it in the music provider.
          ctx.read<PlayerProvider>().onDurationKnown =
              ctx.read<MusicProvider>().updateSongDuration;

          // Wire BilibiliProvider -> MusicProvider refresh
          ctx.read<BilibiliProvider>().onSongAdded = () {
            ctx.read<MusicProvider>().loadSongs();
          };

          // Check for saved Bilibili session on app start
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ctx.read<BilibiliProvider>().checkSession();
          });

          return MaterialApp(
            title: 'LitMusic',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.deepPurple,
                brightness: Brightness.dark,
              ),
              scaffoldBackgroundColor: const Color(0xFF0f0f23),
              useMaterial3: true,
            ),
            home: const WelcomePage(),
          );
        },
      ),
    );
  }
}
