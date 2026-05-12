import 'package:get_it/get_it.dart';
import '../core/network/api_client.dart';
import '../repositories/message_repository.dart';
import '../services/websocket_service.dart';
import '../services/polling_service.dart';
import '../services/ordered_message_service.dart';

final getIt = GetIt.instance;

void setupInjector() {
  getIt.registerLazySingleton<ApiClient>(() => ApiClient());
  getIt.registerLazySingleton<MessageRepository>(
    () => MessageRepository(getIt<ApiClient>()),
  );
  getIt.registerFactory<WebSocketService>(() => WebSocketService());
  getIt.registerFactory<PollingService>(
    () => PollingService(getIt<MessageRepository>()),
  );
  getIt.registerFactory<OrderedMessageService>(() => OrderedMessageService());
}
