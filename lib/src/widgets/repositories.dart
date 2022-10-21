import 'package:flutter/material.dart';
import 'package:github_app/src/github_gql/github_gql.dart';
import 'package:github_app/src/utils/query_exception.dart';
import 'package:gql_exec/gql_exec.dart';
import 'package:gql_http_link/gql_http_link.dart';
import 'package:url_launcher/url_launcher_string.dart';

class RepositoryList extends StatefulWidget {
  const RepositoryList({super.key, required this.link});

  final HttpLink link;

  @override
  RepositoryListState createState() => RepositoryListState();
}

class RepositoryListState extends State<RepositoryList> {
  late Future<List<GRepositoriesData_viewer_repositories_nodes>> _repositories;

  @override
  void initState() {
    super.initState();
    _repositories = _retrieveRepositories(widget.link);
  }

  Future<List<GRepositoriesData_viewer_repositories_nodes>>
      _retrieveRepositories(HttpLink link) async {
    final GRepositories request = GRepositories(
        (GRepositoriesBuilder builder) => builder..vars.count = 100);
    final Response result = await link
        .request(Request(
          operation: request.operation,
          variables: request.vars.toJson(),
        ))
        .first;
    final List<GraphQLError>? errors = result.errors;
    if (errors != null && errors.isNotEmpty) {
      throw QueryException(errors);
    }
    return GRepositoriesData.fromJson(result.data!)!
        .viewer
        .repositories
        .nodes!
        .asList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<GRepositoriesData_viewer_repositories_nodes>>(
      future: _repositories,
      builder: (_,
          AsyncSnapshot<List<GRepositoriesData_viewer_repositories_nodes>>
              snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }
        final List<GRepositoriesData_viewer_repositories_nodes> repositories =
            snapshot.data!;
        return ListView.builder(
          primary: false,
          itemCount: repositories.length,
          prototypeItem: const SizedBox(height: 60),
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemBuilder: (_, int index) {
            final GRepositoriesData_viewer_repositories_nodes repository =
                repositories[index];
            return ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: Image.network(repository.owner.avatarUrl.value),
              ),
              title: Text(repository.name),
              subtitle: Text(
                repository.description ?? 'No description',
                maxLines: 2,
              ),
              onTap: () async {
                final url = repository.url.value;
                if (await canLaunchUrlString(url)) await launchUrlString(url);
              },
            );
          },
        );
      },
    );
  }
}
