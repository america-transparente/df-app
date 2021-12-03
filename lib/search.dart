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

Map simpleQueryString(String query, List<String> fields,
    {String? defaultField}) {
  return {
    'simple_query_string': {
      "query": query,
      "fields": fields,
      "default_operator": "and",
      "lenient": "true",
      if (defaultField != null) 'default_field': defaultField,
    },
  };
}

Future<List<Document>> searchOfficialDiary(
    elastic.Client client, String query) async {
  var stringQuery = simpleQueryString(query, ['content']);
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

String cleanDocumentContent(String content) =>
    content.trim().split("\n").join(" ").substring(0, 100) + "...";
