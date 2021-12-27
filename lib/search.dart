// import 'package:diario_oficial/http_trans_impl.dart';

import 'package:elastic_client/elastic_client.dart' as elastic;

class Document {
  final String title;
  final String content;
  final List<String> highlight;
  // TODO: Change to DateTime
  final String date;
  final String path;

  Document(this.title, this.content, this.highlight, this.date, this.path);

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
    index: "dfinales2",
    query: queryString,
    highlight: highlight,
    source: true,
  );
  var documentList = <Document>[];
  for (final result in searchResult.hits) {
    documentList.add(Document(
        result.doc["title"],
        result.doc["content"],
        result.highlight!["content"] ?? [],
        result.doc["date"],
        result.doc["path"]));
  }

  print("Search: Found ${documentList.length} results");
  return documentList;
}

void main() async {
  var url = Uri.parse("https://df-api.americatransparente.org/es");
  final transport = elastic.HttpTransport(url: url);
  final client = elastic.Client(transport);
  print(await searchOfficialDiary(client, "a"));
}

String cleanDocumentContent(String content) =>
    content.trim().split("\n").join(" ").substring(0, 100) + "...";
