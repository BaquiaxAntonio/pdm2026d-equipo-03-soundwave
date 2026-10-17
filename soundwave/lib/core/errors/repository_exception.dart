enum RepositoryErrorCode { network, notFound, conflict, storage, invalidData }

/// Expected, recoverable failures raised by repository implementations.
class RepositoryException implements Exception {
  const RepositoryException(this.code, this.message, {this.cause});

  final RepositoryErrorCode code;
  final String message;
  final Object? cause;

  @override
  String toString() => 'RepositoryException($code): $message';
}
