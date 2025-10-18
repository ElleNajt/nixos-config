{ pkgs }:

let
  proxiesDir = ./proxies;
  claudeboxDir = ./claudebox;
  runpodDir = ./runpod;
  emacsDir = ./emacs;

  # Package entire containers directory so claudebox can access Dockerfile and ssh-agent submodule
  containersPackage = pkgs.stdenv.mkDerivation {
    name = "claudebox-containers";
    src = ./.;

    # Don't patch shebangs in files that go into Docker images
    dontPatchShebangs = true;

    installPhase = ''
      mkdir -p $out/share/claudebox
      cp -r . $out/share/claudebox/

      mkdir -p $out/bin
      cat > $out/bin/claudebox <<EOF
      #!/bin/bash
      CLAUDEBOX_DIR="$out/share/claudebox/claudebox"
      CONTAINER_DIR="$out/share/claudebox"
      export CLAUDEBOX_DIR CONTAINER_DIR
      exec bash $out/share/claudebox/claudebox/claudebox "\$@"
      EOF
      chmod +x $out/bin/claudebox

      # Copy other claudebox scripts
      cp ${claudeboxDir}/claudebox-save-conversations $out/bin/
      cp ${claudeboxDir}/test-claudebox-security.sh $out/bin/test-claudebox-security
      chmod +x $out/bin/claudebox-save-conversations
      chmod +x $out/bin/test-claudebox-security
    '';
  };
in
[
  containersPackage

  (pkgs.writeScriptBin "claude-auth-proxy.py" ''
    #!${pkgs.python3}/bin/python3
    ${builtins.readFile "${proxiesDir}/claude-auth-proxy.py"}
  '')

  (pkgs.writeScriptBin "get-claude-credentials.sh" ''
    ${builtins.readFile "${proxiesDir}/get-claude-credentials.sh"}
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
