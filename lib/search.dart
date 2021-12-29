import 'package:elastic_client/elastic_client.dart' as elastic;
import 'package:intl/intl.dart';

class Document {
  final String title;
  final String cve;
  final String content;
  final List<String> highlight;
  // TODO: Change to DateTime
  final DateTime date;
  final String path;

  Document(
      this.title, this.cve, this.content, this.highlight, this.date, this.path);

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
    size: 50,
  );
  var documentList = <Document>[];
  for (final result in searchResult.hits) {
    documentList.add(Document(
        result.doc["title"],
        result.doc["cve"],
        result.doc["content"],
        result.highlight!["content"] ?? [],
        DateTime.parse(result.doc["date"]),
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

String generateDocumentTitle(Document doc) {
  final DateFormat formatter = DateFormat('dd/MM/yyyy');
  if (doc.title.trim() == "" && doc.cve.trim() == "") {
    return "Publicación del ${formatter.format(doc.date)}";
  } else if (doc.title.trim() == "") {
    return "Publicación del ${formatter.format(doc.date)} (${doc.cve})";
  } else {
    return "Publicación del ${formatter.format(doc.date)}";
  }
}
