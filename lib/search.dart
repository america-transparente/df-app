// import 'package:diario_oficial/http_trans_impl.dart';

import 'package:elastic_client/elastic_client.dart' as elastic;

class Document {
  final String title;
  final String body;
  final List<String> highlight;
  // TODO: Change to DateTime
  final String indexDate;
  final String directory;

  Document(
      this.title, this.body, this.highlight, this.indexDate, this.directory);

  @override
  String toString() {
    return 'Document(title="$title")';
  }
}

List simpleQueryString(String query, List<String> fields,
    {List<String>? highlightFields,
    int fragmentSize = 100,
    int numberOfFragments = 1,
    String? defaultField}) {
  final queryString = {
    'simple_query_string': {
      "query": query,
      "fields": fields,
      "default_operator": "and",
      "lenient": "true",
      if (defaultField != null) 'default_field': defaultField,
    }
  };
  final highlight = elastic.HighlightOptions(fields: {
    for (var field in highlightFields ?? fields)
      field: elastic.HighlightField(),
  }, fragmentSize: fragmentSize, numberOfFragments: numberOfFragments);
  return [queryString, highlight];
}

Future<List<Document>> searchOfficialDiary(
    elastic.Client client, String query) async {
  final queryContents = simpleQueryString(query, ['content'],
      fragmentSize: 120, numberOfFragments: 1);
  final queryString = queryContents[0];
  final highlight = queryContents[1];

  final elastic.SearchResult searchResult = await client.search(
    index: "documentlist",
    type: "info",
    query: queryString,
    highlight: highlight,
    source: true,
  );
  var documentList = <Document>[];
  for (final result in searchResult.hits) {
    documentList.add(Document(
        result.doc["name"],
        result.doc["content"],
        result.highlight!["content"] ?? [],
        result.doc["indexingDate"],
        result.doc["directory"]));
  }

  print("Search: Found ${documentList.length} results");
  return documentList;
}

void main() async {
  var url = Uri.parse("https://df-api.reguleque.cl/es");
  final transport = elastic.HttpTransport(url: url);
  final client = elastic.Client(transport);
  print(await searchOfficialDiary(client, "a"));
}

String cleanDocumentContent(String content) =>
    content.trim().split("\n").join(" ").substring(0, 100) + "...";
