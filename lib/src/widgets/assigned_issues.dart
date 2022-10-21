import 'package:flutter/material.dart';
import 'package:github_app/src/github_gql/github_gql.dart';
import 'package:github_app/src/utils/query_exception.dart';
import 'package:gql_exec/gql_exec.dart';
import 'package:gql_http_link/gql_http_link.dart';
import 'package:url_launcher/url_launcher_string.dart';

class AssignedIssuesList extends StatefulWidget {
  const AssignedIssuesList({super.key, required this.link});

  final HttpLink link;

  @override
  AssignedIssuesListState createState() => AssignedIssuesListState();
}

class AssignedIssuesListState extends State<AssignedIssuesList> {
  late Future<List<GAssignedIssuesData_search_edges_node__asIssue>>
      _assignedIssues;

  @override
  void initState() {
    super.initState();
    _assignedIssues = _retrieveAssignedIssues(widget.link);
  }

  Future<List<GAssignedIssuesData_search_edges_node__asIssue>>
      _retrieveAssignedIssues(HttpLink link) async {
    final GViewerDetail request =
        GViewerDetail((GViewerDetailBuilder builder) => builder);
    Response result = await link
        .request(Request(
          operation: request.operation,
          variables: request.vars.toJson(),
        ))
        .first;
    List<GraphQLError>? errors = result.errors;
    if (errors != null && errors.isNotEmpty) {
      throw QueryException(errors);
    }
    final GViewerDetailData_viewer viewer =
        GViewerDetailData.fromJson(result.data!)!.viewer;
    final GAssignedIssues issueRequest = GAssignedIssues(
      (GAssignedIssuesBuilder builder) => builder
        ..vars.count = 100
        ..vars.query = 'is:open assignee:${viewer.login} archived:false',
    );
    result = await link
        .request(Request(
          operation: issueRequest.operation,
          variables: issueRequest.vars.toJson(),
        ))
        .first;
    errors = result.errors;
    if (errors != null && errors.isNotEmpty) {
      throw QueryException(errors);
    }
    return GAssignedIssuesData.fromJson(result.data!)!
        .search
        .edges!
        .map((GAssignedIssuesData_search_edges e) => e.node)
        .whereType<GAssignedIssuesData_search_edges_node__asIssue>()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<GAssignedIssuesData_search_edges_node__asIssue>>(
      future: _assignedIssues,
      builder: (_,
          AsyncSnapshot<List<GAssignedIssuesData_search_edges_node__asIssue>>
              snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }
        final List<GAssignedIssuesData_search_edges_node__asIssue>
            assignedIssues = snapshot.data!;
        return ListView.builder(
          primary: false,
          itemCount: assignedIssues.length,
          prototypeItem: const SizedBox(height: 60),
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemBuilder: (_, int index) {
            final GAssignedIssuesData_search_edges_node__asIssue assignedIssue =
                assignedIssues[index];
            return ListTile(
              title: Text(assignedIssue.title),
              subtitle: Text('${assignedIssue.repository.nameWithOwner} '
                  'Issue #${assignedIssue.number} '
                  'opened by ${assignedIssue.author!.login}'),
              onTap: () async {
                final url = assignedIssue.url.value;
                if (await canLaunchUrlString(url)) await launchUrlString(url);
              },
            );
          },
        );
      },
    );
  }
}
