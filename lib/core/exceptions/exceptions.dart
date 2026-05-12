
abstract class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic originalError;

  ApiException(this.message, {this.statusCode, this.originalError});

  @override
  String toString() => '[$runtimeType] $message (status: $statusCode)';
}

class NetworkException extends ApiException {
  NetworkException(super.message, {super.statusCode, super.originalError});
}

class TimeoutException extends ApiException {
  TimeoutException(super.message, {super.statusCode, super.originalError});
}

class UnauthorizedException extends ApiException {
  UnauthorizedException(super.message, {int? statusCode, super.originalError})
      : super(statusCode: statusCode ?? 401);
}

class ForbiddenException extends ApiException {
  ForbiddenException(super.message, {int? statusCode, super.originalError})
      : super(statusCode: statusCode ?? 403);
}

class NotFoundException extends ApiException {
  NotFoundException(super.message, {int? statusCode, super.originalError})
      : super(statusCode: statusCode ?? 404);
}

class BadRequestException extends ApiException {
  BadRequestException(super.message, {int? statusCode, super.originalError})
      : super(statusCode: statusCode ?? 400);
}

class ConflictException extends ApiException {
  ConflictException(super.message, {int? statusCode, super.originalError})
      : super(statusCode: statusCode ?? 409);
}

class ValidationException extends ApiException {
  ValidationException(super.message, {int? statusCode, super.originalError})
      : super(statusCode: statusCode ?? 422);
}

class ServerException extends ApiException {
  ServerException(super.message, {int? statusCode, super.originalError})
      : super(statusCode: statusCode ?? 500);
}

class CancellationException extends ApiException {
  CancellationException(super.message, {super.statusCode, super.originalError});
}

class ParsingException extends ApiException {
  ParsingException(super.message, {super.statusCode, super.originalError});
}

class UnknownException extends ApiException {
  UnknownException(super.message, {super.statusCode, super.originalError});
}