import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_floating_search_bar/material_floating_search_bar.dart';
import 'package:elastic_client/elastic_client.dart' as elastic;
import 'package:url_launcher/url_launcher.dart';
import 'package:json_theme/json_theme.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:duenos_finales/search.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final themeStr = await rootBundle.loadString('assets/flutter_theme.json');
  final themeJson = jsonDecode(themeStr);

  final theme = ThemeDecoder.decodeThemeData(themeJson)!;

  runApp(MyApp(theme: theme));
}

class MyApp extends StatelessWidget {
  final ThemeData theme;

  const MyApp({Key? key, required this.theme}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dueños Directos',
      theme: theme,
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
  bool seenDonationPopup = false;

  Future<void> _showDonationPopup() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Necesitamos decirte algo.'),
          content: InkWell(
            child: SvgPicture.asset("assets/popup.svg"),
            onTap: () => launch(
                "https://app.reveniu.com/checkout-custom-link/aSmPLaykZ0lAnrXpMcJUopEccz9F4kRE"),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cerrar'),
              onPressed: () {
                seenDonationPopup = true;
                Navigator.of(context).pop();
              },
            ),
            TextButton(
                onPressed: () {
                  seenDonationPopup = true;
                  launch(
                      "https://app.reveniu.com/checkout-custom-link/aSmPLaykZ0lAnrXpMcJUopEccz9F4kRE");
                },
                child: const Text("Donar"))
          ],
        );
      },
    );
  }

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
        backgroundColor: Theme.of(context).colorScheme.primary,
        iconColor: Theme.of(context).colorScheme.onPrimary,
        controller: controller,
        body: FloatingSearchBarScrollNotifier(
          child: SearchResultsListView(
            searchTerm: selectedTerm,
            elasticClient: elasticClient,
          ),
        ),
        title: Text(
          selectedTerm ?? "Dueños Directos",
          style: Theme.of(context).textTheme.headline6?.merge(
              TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
        ),
        hint: "Busca nombres, organizaciones, etc.",
        hintStyle: Theme.of(context)
            .textTheme
            .bodyText1!
            .merge(TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
        queryStyle: Theme.of(context)
            .textTheme
            .bodyText1!
            .merge(TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
        actions: [FloatingSearchBarAction.searchToClear()],
        onQueryChanged: (query) {
          setState(() {
            filteredSearchHistory = filterSearchTerms(filter: query);
          });
        },
        onSubmitted: (query) {
          setState(() {
            if (!seenDonationPopup) {
              _showDonationPopup();
            }

            addSearchTerm(query);
            selectedTerm = query;
          });
          controller.close();
        },
        builder: (context, transition) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Material(
              color: Theme.of(context).colorScheme.primary,
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
                        style: Theme.of(context).textTheme.subtitle1!.merge(
                            TextStyle(
                                color:
                                    Theme.of(context).colorScheme.onPrimary)),
                      ),
                    );
                  } else if (filteredSearchHistory.isEmpty) {
                    return ListTile(
                      title: Text(controller.query),
                      textColor: Theme.of(context).colorScheme.onPrimary,
                      leading: Icon(Icons.search,
                          color: Theme.of(context).colorScheme.onPrimary),
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
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyText1!
                                    .merge(TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onPrimary)),
                              ),
                              leading: Icon(Icons.history,
                                  color:
                                      Theme.of(context).colorScheme.onPrimary),
                              trailing: IconButton(
                                icon: Icon(Icons.clear,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimary),
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
            Icon(Icons.search,
                size: 64, color: Theme.of(context).colorScheme.onBackground),
            Text(
              'Empieza a buscar!',
              style: Theme.of(context).textTheme.headline5,
            ),
            Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 25.0, vertical: 5),
                child: Text(
                  "Recuerda que esta plataforma está en alpha, así que todavía puede haber cosas que no funcionan como deberían.\n\nTip: Para hacer búsquedas exactas, rodea tu consulta en comillas dobles (Ej: \"Sebastián Piñera\").",
                  style: Theme.of(context).textTheme.bodyText1,
                  textAlign: TextAlign.center,
                ))
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
                child: Padding(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline_outlined,
                          size: 64,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        Text(
                          'No se encontraron resultados',
                          style: Theme.of(context).textTheme.headline5?.merge(
                              TextStyle(
                                  color: Theme.of(context).colorScheme.error)),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          "Revisa que hayas escrito bien las entidades y prueba con formas distintas de deletrear lo que estabas buscando.",
                          style: Theme.of(context).textTheme.bodyText1,
                          textAlign: TextAlign.center,
                        )
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 40.0)),
              );
            } else {
              final hits = <ListTile>[];
              for (final result in snapshot.data as List<Document>) {
                hits.add(
                  ListTile(
                    leading: const Icon(Icons.description),
                    title: SelectableText(generateDocumentTitle(result)),
                    subtitle: cleanAndGiveEmphasis(result.highlight),
                    trailing: InkWell(
                      child: const Icon(Icons.open_in_new),
                      onTap: () => launch(
                          "https://df-api.americatransparente.org/documents/" +
                              result.path),
                    ),
                  ),
                );
              }
              return ListView(
                // TODO: Fix padding in a dynamic manner
                padding: EdgeInsets.only(top: fsb.widget.height + 16),
                children: hits,
              );
            }
          } else if (const [ConnectionState.waiting, ConnectionState.active]
              .contains(snapshot.connectionState)) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [CircularProgressIndicator()],
            );
          } else {
            return Center(
                child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.error,
                    size: 64,
                    semanticLabel: "Error interno",
                    color: Theme.of(context).colorScheme.error),
                Text("Error interno",
                    style: Theme.of(context).textTheme.headline5!.merge(
                        TextStyle(color: Theme.of(context).colorScheme.error))),
                Padding(
                    child: Text(
                      "Puede que nuestros servidores estén más ocupados de lo usual. Si el error persiste, contáctanos a contacto@americatransparente.org.",
                      style: Theme.of(context).textTheme.subtitle1,
                      textAlign: TextAlign.center,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 40.0))
              ],
            ));
          }
        },
        future: searchOfficialDiary(elasticClient!, searchTerm!));
  }
}
