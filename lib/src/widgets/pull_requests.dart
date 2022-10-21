import 'package:flutter/material.dart';
import 'package:github_app/src/github_gql/github_gql.dart';
import 'package:github_app/src/utils/query_exception.dart';
import 'package:gql_exec/gql_exec.dart';
import 'package:gql_http_link/gql_http_link.dart';
import 'package:url_launcher/url_launcher_string.dart';

class PullRequestsList extends StatefulWidget {
  const PullRequestsList({super.key, required this.link});

  final HttpLink link;

  @override
  PullRequestsListState createState() => PullRequestsListState();
}

class PullRequestsListState extends State<PullRequestsList> {
  late Future<List<GPullRequestsData_viewer_pullRequests_edges_node>>
      _pullRequests;

  @override
  void initState() {
    super.initState();
    _pullRequests = _retrievePullRequests(widget.link);
  }

  Future<List<GPullRequestsData_viewer_pullRequests_edges_node>>
      _retrievePullRequests(HttpLink link) async {
    final GPullRequests request = GPullRequests(
        (GPullRequestsBuilder builder) => builder..vars.count = 100);
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
    return GPullRequestsData.fromJson(result.data!)!
        .viewer
        .pullRequests
        .edges!
        .map((GPullRequestsData_viewer_pullRequests_edges e) => e.node)
        .whereType<GPullRequestsData_viewer_pullRequests_edges_node>()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<
        List<GPullRequestsData_viewer_pullRequests_edges_node>>(
      future: _pullRequests,
      builder: (_,
          AsyncSnapshot<List<GPullRequestsData_viewer_pullRequests_edges_node>>
              snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }
        final List<GPullRequestsData_viewer_pullRequests_edges_node>
            pullRequests = snapshot.data!;
        return ListView.builder(
          primary: false,
          itemCount: pullRequests.length,
          prototypeItem: const SizedBox(height: 60),
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemBuilder: (_, int index) {
            final GPullRequestsData_viewer_pullRequests_edges_node pullRequest =
                pullRequests[index];
            return ListTile(
              title: Text(pullRequest.title),
              subtitle: Text('${pullRequest.repository.nameWithOwner} '
                  'PR #${pullRequest.number} '
                  'opened by ${pullRequest.author!.login} '
                  '(${pullRequest.state.name.toLowerCase()})'),
              onTap: () async {
                final url = pullRequest.url.value;
                if (await canLaunchUrlString(url)) await launchUrlString(url);
              },
            );
          },
        );
      },
    );
  }
}
