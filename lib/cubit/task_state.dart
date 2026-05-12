// part of 'task_cubit.dart';
//
// abstract class TaskState extends Equatable {
//   const TaskState();
//   @override List<Object?> get props => [];
// }
//
// class TaskInitial extends TaskState {}
// class TaskRunning extends TaskState {}
// class TaskLog extends TaskState {
//   final String message;
//   const TaskLog(this.message);
//   @override List<Object?> get props => [message];
//   @override
//   String toString() => 'TaskLog: $message'; // helpful for debugging
// }
// class TaskSuccess extends TaskState {}
// class TaskFailure extends TaskState {
//   final String error;
//   const TaskFailure(this.error);
//   @override List<Object?> get props => [error];
// }


import 'package:equatable/equatable.dart';
import '../models/message.dart';

enum TaskStatus {
  initial,
  loading,
  success,
  failure,
}

class TaskState extends Equatable {
  final TaskStatus status;
  final List<String> logs;
  final List<Message> messages;
  final String? error;

  const TaskState({
    this.status = TaskStatus.initial,
    this.logs = const [],
    this.messages = const [],
    this.error,
  });

  TaskState copyWith({
    TaskStatus? status,
    List<String>? logs,
    List<Message>? messages,
    String? error,
  }) {
    return TaskState(
      status: status ?? this.status,
      logs: logs ?? this.logs,
      messages: messages ?? this.messages,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [
    status,
    logs,
    messages,
    error,
  ];
}
