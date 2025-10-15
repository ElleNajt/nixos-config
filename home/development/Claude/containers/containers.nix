{ pkgs }:

let
  proxiesDir = ./proxies;
  claudeboxDir = ./claudebox;
  runpodDir = ./runpod;
in
[
  (pkgs.writeScriptBin "claude-auth-proxy.py" ''
    #!${pkgs.python3}/bin/python3
    ${builtins.readFile "${proxiesDir}/claude-auth-proxy.py"}
  '')

  (pkgs.writeScriptBin "get-claude-credentials.sh" ''
    ${builtins.readFile "${proxiesDir}/get-claude-credentials.sh"}
  '')

  (pkgs.writeScriptBin "claudebox" ''
    ${builtins.readFile "${claudeboxDir}/claudebox"}
  '')

  (pkgs.writeScriptBin "runpod" ''
    #!${pkgs.python3.withPackages (ps: with ps; [ boto3 requests python-dotenv runpod-python ])}/bin/python3
    ${builtins.readFile "${runpodDir}/runpod.py"}
  '')
]
