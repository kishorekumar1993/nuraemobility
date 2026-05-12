import 'package:equatable/equatable.dart';

class Message extends Equatable {
  final String echoMessage;
  final int counter;
  final int ts;

  const Message({
    required this.echoMessage,
    required this.counter,
    required this.ts,
  });

  factory Message.fromJson(Map<String, dynamic> json) => Message(
    echoMessage: json['echo_message'],
    counter: json['counter'],
    ts: json['ts'],
  );

  @override
  List<Object?> get props => [counter, echoMessage, ts];
}
