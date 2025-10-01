{ pkgs }:

let
  scriptsDir = ./scripts;
in
[
  (pkgs.writeScriptBin "claude-auth-proxy.py" ''
    #!${pkgs.python3}/bin/python3
    ${builtins.readFile "${scriptsDir}/claude-auth-proxy.py"}
  '')

  (pkgs.writeScriptBin "get-claude-credentials.sh" ''
    ${builtins.readFile "${scriptsDir}/get-claude-credentials.sh"}
  '')

  (pkgs.writeScriptBin "claudebox" ''
    ${builtins.readFile "${scriptsDir}/claudebox"}
  '')
]
