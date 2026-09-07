class WebDavConfiguration {
  const WebDavConfiguration({
    required this.serverUrl,
    required this.username,
    required this.hasPassword,
  });

  final String serverUrl;
  final String username;
  final bool hasPassword;
}

class WebDavCredentials {
  const WebDavCredentials({
    required this.serverUri,
    required this.username,
    required this.password,
  });

  final Uri serverUri;
  final String username;
  final String password;
}
