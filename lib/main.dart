import 'package:flutter/material.dart';
import 'package:material_floating_search_bar/material_floating_search_bar.dart';
import 'package:elastic_client/elastic_client.dart' as elastic;
import 'package:url_launcher/url_launcher.dart';

import 'package:diario_oficial/search.dart';
// import 'package:diario_oficial/http_trans_impl.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Diario Oficial',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static final _elasticURL =
      Uri.parse("https://df-api.americatransparente.org/es");
  static final _elasticTransport = elastic.HttpTransport(url: _elasticURL);
  final elasticClient = elastic.Client(_elasticTransport);

  static const historyLength = 5;
  List<String> searchHistory = <String>[];
  List<String> filteredSearchHistory = <String>[];

  // Current term being searched
  String? selectedTerm;

  List<String> filterSearchTerms({
    @required String? filter,
  }) {
    if (filter != null && filter.isNotEmpty) {
      // Reversed because we want the last added items to appear first in the UI
      return searchHistory.reversed
          .where((term) => term.startsWith(filter))
          .toList();
    } else {
      return searchHistory.reversed.toList();
    }
  }

  void addSearchTerm(String term) {
    if (searchHistory.contains(term)) {
      // This method will be implemented soon
      putSearchTermFirst(term);
      return;
    }
    searchHistory.add(term);
    if (searchHistory.length > historyLength) {
      searchHistory.removeRange(0, searchHistory.length - historyLength);
    }
    // Changes in _searchHistory mean that we have to update the filteredSearchHistory
    filteredSearchHistory = filterSearchTerms(filter: null);
  }

  void deleteSearchTerm(String term) {
    searchHistory.removeWhere((t) => t == term);
    filteredSearchHistory = filterSearchTerms(filter: null);
  }

  void putSearchTermFirst(String term) {
    deleteSearchTerm(term);
    addSearchTerm(term);
  }

  late FloatingSearchBarController controller;

  @override
  void initState() {
    super.initState();
    controller = FloatingSearchBarController();
    filteredSearchHistory = filterSearchTerms(filter: null);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FloatingSearchBar(
        backgroundColor: Colors.teal[100],
        controller: controller,
        body: FloatingSearchBarScrollNotifier(
          child: SearchResultsListView(
            searchTerm: selectedTerm,
            elasticClient: elasticClient,
          ),
        ),
        title: Text(
          selectedTerm ?? "Diario Oficial",
          style: Theme.of(context).textTheme.headline6,
        ),
        hint: "Busca nombres, organizaciones, etc.",
        actions: [FloatingSearchBarAction.searchToClear()],
        onQueryChanged: (query) {
          setState(() {
            filteredSearchHistory = filterSearchTerms(filter: query);
          });
        },
        onSubmitted: (query) {
          setState(() {
            addSearchTerm(query);
            selectedTerm = query;
          });
          controller.close();
        },
        builder: (context, transition) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Material(
              color: Colors.teal[50],
              elevation: 4,
              child: Builder(
                builder: (context) {
                  if (filteredSearchHistory.isEmpty &&
                      controller.query.isEmpty) {
                    return Container(
                      height: 56,
                      width: double.infinity,
                      alignment: Alignment.center,
                      child: Text(
                        'Comienza a buscar!',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.caption,
                      ),
                    );
                  } else if (filteredSearchHistory.isEmpty) {
                    return ListTile(
                      title: Text(controller.query),
                      leading: const Icon(Icons.search),
                      onTap: () {
                        setState(() {
                          addSearchTerm(controller.query);
                          selectedTerm = controller.query;
                        });
                        controller.close();
                      },
                    );
                  } else {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: filteredSearchHistory
                          .map(
                            (term) => ListTile(
                              title: Text(
                                term,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyText1,
                              ),
                              leading: const Icon(Icons.history),
                              trailing: IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    deleteSearchTerm(term);
                                  });
                                },
                              ),
                              onTap: () {
                                setState(() {
                                  putSearchTermFirst(term);
                                  selectedTerm = term;
                                });
                                controller.close();
                              },
                            ),
                          )
                          .toList(),
                    );
                  }
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class SearchResultsListView extends StatelessWidget {
  final String? searchTerm;
  final elastic.Client? elasticClient;

  const SearchResultsListView({
    Key? key,
    @required this.elasticClient,
    @required this.searchTerm,
  }) : super(key: key);

  RichText cleanAndGiveEmphasis(List<String> text) {
    final emMatch = RegExp(r"<em\s*.*>\s*.*<\/em>");
    final newlineMatch = RegExp(r"(\r\n|\r|\n)");
    final whitespaceMatch = RegExp(r"\s+");
    final String? emphasized = emMatch
        .stringMatch(text[0])!
        .replaceAll("<em>", "")
        .replaceAll("</em>", "")
        .replaceAll(newlineMatch, " ")
        .replaceAll(whitespaceMatch, " ");
    assert(emphasized != null);
    final List<String> nonEmphasized = text[0]
        .replaceAll(newlineMatch, " ")
        .replaceAll(whitespaceMatch, " ")
        .trim()
        .split(emMatch);
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '“${nonEmphasized[0]}',
            style: const TextStyle(
              color: Colors.black,
              fontStyle: FontStyle.italic,
            ),
          ),
          TextSpan(
            text: emphasized,
            style: const TextStyle(
              color: Colors.blue,
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
            ),
          ),
          TextSpan(
            text: '${nonEmphasized[1]}”',
            style: const TextStyle(
              color: Colors.black,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    @required
    final fsb = FloatingSearchBar.of(context)!;

    if (searchTerm == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.search,
              size: 64,
            ),
            Text(
              'Empieza a buscar!',
              style: Theme.of(context).textTheme.headline5,
            )
          ],
        ),
      );
    }
    return FutureBuilder(
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              snapshot.hasData) {
            final data = snapshot.data as List<Document>;
            if (data.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_outlined,
                      size: 64,
                    ),
                    Text(
                      'No se encontraron resultados',
                      style: Theme.of(context).textTheme.headline5,
                    )
                  ],
                ),
              );
            } else {
              final hits = <ListTile>[];
              for (final result in snapshot.data as List<Document>) {
                hits.add(ListTile(
                    leading: const Icon(Icons.description),
                    title: Text(result.title),
                    subtitle: cleanAndGiveEmphasis(result.highlight),
                    trailing: InkWell(
                        child: const Icon(Icons.open_in_new),
                        onTap: () => launch(result.path))));
              }
              return ListView(
                // TODO: Fix padding in a dynamic manner
                padding: EdgeInsets.only(top: fsb.widget.height + 16),
                children: hits,
              );
            }
          } else if (const [ConnectionState.waiting, ConnectionState.active]
              .contains(snapshot.connectionState)) {
            return const CircularProgressIndicator();
          } else {
            return Center(
                child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error,
                  size: 64,
                  semanticLabel: "Error interno",
                ),
                Text("Error interno.",
                    style: Theme.of(context).textTheme.headline5)
              ],
            ));
          }
        },
        future: searchOfficialDiary(elasticClient!, searchTerm!));
  }
}
