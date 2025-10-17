{ pkgs }:

let
  proxiesDir = ./proxies;
  claudeboxDir = ./claudebox;
  runpodDir = ./runpod;
  emacsDir = ./emacs;
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

  (pkgs.writeScriptBin "claudebox-save-conversations" ''
    ${builtins.readFile "${claudeboxDir}/claudebox-save-conversations"}
  '')

  (pkgs.writeScriptBin "test-claudebox-security" ''
    ${builtins.readFile "${claudeboxDir}/test-claudebox-security.sh"}
  '')

  (pkgs.writeScriptBin "runpod" ''
    #!${pkgs.python3}/bin/python3
    ${builtins.readFile "${runpodDir}/runpod.py"}
  '')

  (pkgs.writeScriptBin "check-fallbacks.sh" ''
    #!${pkgs.python3}/bin/python3
    ${builtins.readFile "${emacsDir}/check-fallbacks.py"}
  '')
]
