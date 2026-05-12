import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nura/cubit/task_cubit.dart';
import 'package:nura/cubit/task_state.dart';
import 'package:nura/services/ordered_message_service.dart';
import 'package:nura/services/polling_service.dart';
import 'package:nura/services/websocket_service.dart';
import 'di/injector.dart';

void main() {
  setupInjector();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WebSocket Task',
      theme: ThemeData.dark(),
      home: BlocProvider(
        create: (_) => TaskCubit(
          getIt<WebSocketService>(),
          getIt<PollingService>(),
          getIt<OrderedMessageService>(),
        ),
        child: const HomePage(),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ScrollController _scrollController = ScrollController();
  static const int _maxLogs = 500;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _timestamp() =>
      DateTime.now().toLocal().toIso8601String().substring(11, 23);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monotonic Counters - Final'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              // Clear logs by resetting state? This is a UI-only clear,
              // but the cubit doesn't expose a clear method.
              // For simplicity, we can just rebuild with empty logs? But state is from cubit.
              // Better to add a clearLogs method in cubit if needed.
              // Alternatively, we can keep local logs for clear, but that defeats the purpose.
              // Let's add a cubit method to clear logs.
              context.read<TaskCubit>().clearLogs();
            },
            tooltip: 'Clear logs',
          ),
        ],
      ),
      body: BlocConsumer<TaskCubit, TaskState>(
        listener: (ctx, state) {
          // Show snackbar on success/failure
          if (state.status == TaskStatus.success) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              const SnackBar(
                content: Text('✅ Task succeeded!'),
                backgroundColor: Colors.green,
              ),
            );
          } else if (state.status == TaskStatus.failure) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(
                content: Text('❌ ${state.error ?? "Unknown error"}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (ctx, state) {
          final isRunning = state.status == TaskStatus.loading;
          final logs = state.logs;

          // Auto-scroll to top when new logs arrive
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients && logs.isNotEmpty) {
              _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 100),
                curve: Curves.easeOut,
              );
            }
          });

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: isRunning
                      ? null
                      : () => context.read<TaskCubit>().run(),
                  icon: isRunning
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.play_arrow),
                  label: Text(isRunning ? 'Running...' : 'Start Test'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade800),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: logs.isEmpty
                      ? const Center(
                    child: Text(
                      'No logs yet.\nPress "Start Test" to begin.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                      : ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    itemCount: logs.length,
                    itemBuilder: (ctx, idx) {
                      // Show newest first (reverse order)
                      final logEntry = logs[logs.length - 1 - idx];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: Text(
                          '${_timestamp()} $logEntry',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
