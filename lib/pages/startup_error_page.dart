import 'package:flutter/material.dart';

class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.message, required this.logPath});
  final String message;
  final String logPath;

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF355C7D)),
        darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark, colorSchemeSeed: const Color(0xFF7EA6C4)),
        themeMode: ThemeMode.system,
        home: Scaffold(
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Card(
                margin: const EdgeInsets.all(24),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.error_outline, size: 42),
                    const SizedBox(height: 12),
                    Text('Impossibile avviare il gestionale', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 12),
                    const Text('L’applicazione non è riuscita a inizializzare i dati locali o il database. I dettagli tecnici sono stati salvati nel log.'),
                    const SizedBox(height: 12),
                    SelectableText(message),
                    const SizedBox(height: 12),
                    Text('Log: $logPath', style: Theme.of(context).textTheme.bodySmall),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
}
