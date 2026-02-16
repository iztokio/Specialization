import 'package:equatable/equatable.dart';

// ============================================================
// BASE ERROR TYPES
// ============================================================

sealed class AppError extends Equatable {
  const AppError({required this.message, this.originalError});

  final String message;
  final Object? originalError;

  @override
  List<Object?> get props => [message, originalError];
}

// Network errors
final class NetworkError extends AppError {
  const NetworkError({super.message = 'Network unavailable', super.originalError});
}

final class TimeoutError extends AppError {
  const TimeoutError({super.message = 'Request timed out', super.originalError});
}

// Firebase errors
final class FirestoreError extends AppError {
  const FirestoreError({required super.message, super.originalError});
}

final class AuthError extends AppError {
  const AuthError({required super.message, super.originalError});
}

// Business logic errors
final class ValidationError extends AppError {
  const ValidationError({required super.message});
}

final class NotFoundError extends AppError {
  const NotFoundError({required super.message});
}

final class PermissionError extends AppError {
  const PermissionError({required super.message});
}

// Purchase errors
final class PurchaseError extends AppError {
  const PurchaseError({required super.message, super.originalError});
}

final class PurchaseVerificationError extends AppError {
  const PurchaseVerificationError({
    super.message = 'Purchase verification failed',
    super.originalError,
  });
}

// Content errors
final class ContentNotAvailableError extends AppError {
  const ContentNotAvailableError({
    super.message = 'Content not available offline',
  });
}

// ============================================================
// RESULT TYPE (Railway-oriented programming)
// ============================================================

sealed class Result<T> {
  const Result();
}

final class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

final class Failure<T> extends Result<T> {
  const Failure(this.error);
  final AppError error;
}

extension ResultExtension<T> on Result<T> {
  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  T? get valueOrNull => switch (this) {
    Success<T>(value: final v) => v,
    Failure<T>() => null,
  };

  AppError? get errorOrNull => switch (this) {
    Success<T>() => null,
    Failure<T>(error: final e) => e,
  };

  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(AppError error) onFailure,
  }) =>
      switch (this) {
        Success<T>(value: final v) => onSuccess(v),
        Failure<T>(error: final e) => onFailure(e),
      };
}
