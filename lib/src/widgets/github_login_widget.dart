import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:oauth2/oauth2.dart' as oauth2;
import 'package:url_launcher/url_launcher.dart' as ul;

final Uri _authorizationEndPoint =
    Uri.https('github.com', 'login/oauth/authorize');

final Uri _tokenEndPoint = Uri.https('github.com', 'login/oauth/access_token');

typedef AuthenticatedBuilder = Widget Function(
    BuildContext context, oauth2.Client client);

class GitHubLoginWidget extends StatefulWidget {
  const GitHubLoginWidget({
    super.key,
    required this.builder,
    required this.githubClientId,
    required this.githubClientSecret,
    required this.githubScopes,
  });

  final AuthenticatedBuilder builder;
  final String githubClientId;
  final String githubClientSecret;
  final List<String> githubScopes;

  @override
  GitHubLoginWidgetState createState() => GitHubLoginWidgetState();
}

class GitHubLoginWidgetState extends State<GitHubLoginWidget> {
  HttpServer? _redirectServer;
  oauth2.Client? _client;

  @override
  Widget build(BuildContext context) {
    final oauth2.Client? client = _client;

    if (client != null) return widget.builder(context, client);
    return Center(
      child: CupertinoButton(
        color: CupertinoColors.activeBlue,
        onPressed: () async {
          await _redirectServer?.close();
          // Bind to an ephemeral port on localhost
          _redirectServer = await HttpServer.bind('localhost', 0);
          final oauth2.Client authenticatedHttpClient = await _getOAuth2Client(
              Uri.http('localhost:${_redirectServer!.port}', ''));
          setState(() => _client = authenticatedHttpClient);
        },
        child: const Text('Login to GitHub'),
      ),
    );
  }

  Future<oauth2.Client> _getOAuth2Client(Uri redirectUrl) async {
    if (widget.githubClientId.isEmpty || widget.githubClientSecret.isEmpty) {
      throw const _GitHubLoginException(
          'Client ID and Client Secret cannot be empty!');
    }
    final oauth2.AuthorizationCodeGrant grant = oauth2.AuthorizationCodeGrant(
      widget.githubClientId,
      _authorizationEndPoint,
      _tokenEndPoint,
      secret: widget.githubClientSecret,
      httpClient: _JsonAcceptingHttpClient(),
    );
    final Uri authorizationUrl = grant.getAuthorizationUrl(
      redirectUrl,
      scopes: widget.githubScopes,
    );
    await _redirect(authorizationUrl);
    final Map<String, String> responseQueryParameter = await _listen();
    final oauth2.Client client = await grant.handleAuthorizationResponse(
      responseQueryParameter,
    );
    return client;
  }

  Future<void> _redirect(Uri authorizationUrl) async {
    if (await ul.canLaunchUrl(authorizationUrl)) {
      await ul.launchUrl(authorizationUrl);
    } else {
      throw _GitHubLoginException('Cannot launch $authorizationUrl');
    }
  }

  Future<Map<String, String>> _listen() async {
    final HttpRequest request = await _redirectServer!.first;
    final Map<String, String> params = request.uri.queryParameters;
    request.response.statusCode = 200;
    request.response.headers.set('Content-Type', 'text/plain');
    request.response.writeln('Authenticated! You can close the window.');
    await request.response.close();
    await _redirectServer!.close();
    _redirectServer = null;
    return params;
  }
}

class _JsonAcceptingHttpClient extends http.BaseClient {
  final http.Client _httpClient = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Accept'] = 'application/json';
    return _httpClient.send(request);
  }
}

class _GitHubLoginException implements Exception {
  const _GitHubLoginException(this.message);
  final String message;

  @override
  String toString() => message;
}
