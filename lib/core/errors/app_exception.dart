abstract class AppException implements Exception {
  const AppException(this.userMessage, this.technicalDetail);

  final String userMessage;
  final String technicalDetail;

  @override
  String toString() => 'AppException($userMessage): $technicalDetail';
}

class ClaudeException extends AppException {
  const ClaudeException(String userMessage, String technicalDetail)
      : super(userMessage, technicalDetail);
}

class YnabException extends AppException {
  const YnabException(String userMessage, String technicalDetail)
      : super(userMessage, technicalDetail);
}

class StorageException extends AppException {
  const StorageException(String userMessage, String technicalDetail)
      : super(userMessage, technicalDetail);
}

class ImageException extends AppException {
  const ImageException(String userMessage, String technicalDetail)
      : super(userMessage, technicalDetail);
}
