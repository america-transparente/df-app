// import 'package:diario_oficial/http_trans_impl.dart';
import 'package:elastic_client/elastic_client.dart' as elastic;

class Document {
  final String title;
  final String body;
  // TODO: Change to DateTime
  final String indexDate;
  final String directory;

  Document(this.title, this.body, this.indexDate, this.directory);

  @override
  String toString() {
    return 'Document(title="$title")';
  }
}

Future<List<Document>> searchOfficialDiary(
    elastic.Client client, String query) async {
  var stringQuery = elastic.Query.queryString(query);
  final searchResult = await client.search(
    index: "documentlist",
    type: "info",
    query: stringQuery,
    source: true,
  );
  var documentList = <Document>[];
  for (final result in searchResult.hits) {
    documentList.add(Document(result.doc["name"], result.doc["content"],
        result.doc["indexingDate"], result.doc["directory"]));
  }

  print("Search: Found ${documentList.length} results");
  return documentList;
}

void main() async {
  var url = Uri.parse("http://127.0.0.1:9200");
  final transport = elastic.HttpTransport(url: url);
  final client = elastic.Client(transport);
  print(await searchOfficialDiary(client, "a"));
}
