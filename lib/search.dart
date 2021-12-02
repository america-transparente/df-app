import 'package:elastic_client/elastic_client.dart';

class DocumentResult {
  final String title;
  final String extract;
  final DateTime published;
  final String url;

  DocumentResult(this.title, this.extract, this.published, this.url);
}

<DocumentResult> searchOfficialDiary(String query) {
  return <DocumentResult>[];
}