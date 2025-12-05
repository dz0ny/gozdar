import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Network error types for categorization
enum NetworkErrorType {
  timeout,
  noConnection,
  serverError,
  unknown,
}

/// Result of a network operation with retry support
class NetworkResult<T> {
  final T? data;
  final NetworkErrorType? errorType;
  final String? errorMessage;
  final int attemptsMade;

  const NetworkResult._({
    this.data,
    this.errorType,
    this.errorMessage,
    required this.attemptsMade,
  });

  factory NetworkResult.success(T data, int attempts) =>
      NetworkResult._(data: data, attemptsMade: attempts);

  factory NetworkResult.failure(
    NetworkErrorType type,
    String message,
    int attempts,
  ) =>
      NetworkResult._(
        errorType: type,
        errorMessage: message,
        attemptsMade: attempts,
      );

  bool get isSuccess => data != null;
  bool get isFailure => !isSuccess;
}

/// Utility for retrying network operations with exponential backoff
class NetworkRetry {
  /// Default maximum retry attempts
  static const int defaultMaxAttempts = 3;

  /// Default initial delay between retries (doubles each attempt)
  static const Duration defaultInitialDelay = Duration(seconds: 1);

  /// Execute a network operation with retry logic
  ///
  /// [operation] - The async operation to execute
  /// [maxAttempts] - Maximum number of attempts (default: 3)
  /// [initialDelay] - Initial delay between retries (default: 1 second)
  /// [shouldRetry] - Optional function to determine if retry should happen
  /// [onRetry] - Optional callback before each retry attempt
  static Future<NetworkResult<T>> execute<T>({
    required Future<T> Function() operation,
    int maxAttempts = defaultMaxAttempts,
    Duration initialDelay = defaultInitialDelay,
    bool Function(Exception)? shouldRetry,
    void Function(int attempt, Exception error)? onRetry,
  }) async {
    int attempt = 0;
    Duration delay = initialDelay;

    while (attempt < maxAttempts) {
      attempt++;
      try {
        final result = await operation();
        return NetworkResult.success(result, attempt);
      } on SocketException catch (e) {
        // No internet connection
        if (attempt >= maxAttempts) {
          return NetworkResult.failure(
            NetworkErrorType.noConnection,
            'Ni internetne povezave: ${e.message}',
            attempt,
          );
        }
        onRetry?.call(attempt, e);
      } on TimeoutException catch (e) {
        // Request timeout
        if (attempt >= maxAttempts) {
          return NetworkResult.failure(
            NetworkErrorType.timeout,
            'Zahteva je potekla: ${e.message ?? "timeout"}',
            attempt,
          );
        }
        onRetry?.call(attempt, e);
      } on HttpException catch (e) {
        // HTTP error (server-side)
        if (attempt >= maxAttempts) {
          return NetworkResult.failure(
            NetworkErrorType.serverError,
            'Napaka strežnika: ${e.message}',
            attempt,
          );
        }
        // Only retry on 5xx errors
        if (shouldRetry?.call(e) ?? true) {
          onRetry?.call(attempt, e);
        } else {
          return NetworkResult.failure(
            NetworkErrorType.serverError,
            e.message,
            attempt,
          );
        }
      } catch (e) {
        // Unknown error
        if (e is Exception) {
          if (shouldRetry?.call(e) ?? false) {
            if (attempt >= maxAttempts) {
              return NetworkResult.failure(
                NetworkErrorType.unknown,
                e.toString(),
                attempt,
              );
            }
            onRetry?.call(attempt, e);
          } else {
            return NetworkResult.failure(
              NetworkErrorType.unknown,
              e.toString(),
              attempt,
            );
          }
        } else {
          // Not an exception, don't retry
          return NetworkResult.failure(
            NetworkErrorType.unknown,
            e.toString(),
            attempt,
          );
        }
      }

      // Wait before next attempt with exponential backoff
      if (attempt < maxAttempts) {
        debugPrint('NetworkRetry: Attempt $attempt failed, retrying in ${delay.inSeconds}s');
        await Future.delayed(delay);
        delay *= 2; // Exponential backoff
      }
    }

    // Should not reach here, but just in case
    return NetworkResult.failure(
      NetworkErrorType.unknown,
      'Maksimalno število poskusov doseženo',
      attempt,
    );
  }

  /// Execute with simple retry (returns data or throws)
  ///
  /// Simpler API that throws on failure instead of returning Result
  static Future<T> executeOrThrow<T>({
    required Future<T> Function() operation,
    int maxAttempts = defaultMaxAttempts,
    Duration initialDelay = defaultInitialDelay,
  }) async {
    final result = await execute(
      operation: operation,
      maxAttempts: maxAttempts,
      initialDelay: initialDelay,
    );

    if (result.isSuccess) {
      return result.data as T;
    }

    throw NetworkException(
      result.errorType ?? NetworkErrorType.unknown,
      result.errorMessage ?? 'Unknown error',
    );
  }
}

/// Exception thrown by NetworkRetry.executeOrThrow
class NetworkException implements Exception {
  final NetworkErrorType type;
  final String message;

  const NetworkException(this.type, this.message);

  @override
  String toString() => 'NetworkException($type): $message';

  /// User-friendly error message in Slovenian
  String get userMessage {
    switch (type) {
      case NetworkErrorType.timeout:
        return 'Povezava je potekla. Prosimo, poskusite znova.';
      case NetworkErrorType.noConnection:
        return 'Ni internetne povezave. Preverite omrežje.';
      case NetworkErrorType.serverError:
        return 'Strežnik ni dosegljiv. Poskusite pozneje.';
      case NetworkErrorType.unknown:
        return 'Prišlo je do napake. Poskusite znova.';
    }
  }
}
