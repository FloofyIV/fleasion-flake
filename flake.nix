{
  description = "fleasion";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        fleasionSrc = pkgs.fetchFromGitHub {
          owner = "fleasion";
          repo = "Fleasion";
          rev = "main-indev";
          sha256 = "sha256-vXwVIZHs/ZpL+sKM0nsWE3mLzK4OJdL7O3kL71BHOjk=";
        };
        
        srcDir = fleasionSrc;

        pythonEnv = pkgs.python314.withPackages (ps: with ps; [
          pip
          pyqt6
          pyopengl
          pillow
          numpy
          requests
          sounddevice
          soundfile
          cryptography
          certifi
          lz4
          orjson
          zstandard
          python-dateutil
          platformdirs
        ]);

        runtimeLibs = with pkgs; [
          mesa
          libGL
          sdl3
          libx11
          glew
          glfw
          libxcb
          libxkbcommon
          portaudio
          nss.tools
        ];

        libPath = pkgs.lib.makeLibraryPath runtimeLibs;

        fleasionSrcRun = pkgs.writeShellScriptBin "fleasion-src" ''
          set -euo pipefail
          if [ ! -d "${toString srcDir}" ]; then
            echo "error: ${toString srcDir} not found." >&2
            exit 1
          fi
          export LD_LIBRARY_PATH="${libPath}:''${LD_LIBRARY_PATH:-}"
          export PYTHONPATH="${toString srcDir}/src:''${PYTHONPATH:-}"

          VENV_DIR="''${XDG_CACHE_HOME:-$HOME/.cache}/fleasion-venv"
          if [ ! -d "$VENV_DIR" ]; then
            ${pythonEnv}/bin/python -m venv --system-site-packages "$VENV_DIR"
          fi
          source "$VENV_DIR/bin/activate"

          python -c "import DracoPy" 2>/dev/null || pip install --quiet DracoPy
          python -c "import browser_cookie3" 2>/dev/null || pip install --quiet browser-cookie3
          
          cd "${toString srcDir}"
          exec python launcher.py "$@"
        '';

        fleasionDesktopItem = pkgs.makeDesktopItem {
          name = "fleasion";
          desktopName = "Fleasion";
          exec = "${fleasionSrcRun}/bin/fleasion-src";
          icon = "fleasion";
          categories = [ "Utility" ];
        };

        fleasionPackage = pkgs.symlinkJoin {
          name = "fleasion";
          paths = [ fleasionSrcRun fleasionDesktopItem ];
          postBuild = ''
            mkdir -p $out/share/icons/hicolor/256x256/apps
            cp ${./fleasion.png} $out/share/icons/hicolor/256x256/apps/fleasion.png
          '';
        };

           polkitActionNamespace = "com.fleasion.proxy-helper";
           polkitRunActionId = "com.fleasion.proxy-helper.run";
           polkitInstallCaActionId = "com.fleasion.proxy-helper.install-system-ca";
           installedHelperPath = "/usr/local/libexec/fleasion-linux-proxy-helper";
 
           helperWrapper = pkgs.writeShellScript "fleasion-proxy-helper-daemon" ''
             set -euo pipefail
             export LD_LIBRARY_PATH="${libPath}:''${LD_LIBRARY_PATH:-}"
             export PYTHONPATH="${toString srcDir}/src:''${PYTHONPATH:-}"
             VENV_DIR="''${XDG_CACHE_HOME:-$HOME/.cache}/fleasion-venv"
             if [ -d "$VENV_DIR" ]; then
               source "$VENV_DIR/bin/activate"
             fi
             exec ${pythonEnv}/bin/python -m Fleasion.linux_proxy_helper_daemon "$@"
           '';
 
           polkitPolicyXml = ''
             <?xml version="1.0" encoding="UTF-8"?>
             <!DOCTYPE policyconfig PUBLIC "-//freedesktop//DTD polkit Policy Configuration 1.0//EN"
             "http://www.freedesktop.org/software/polkit/policyconfig-1.dtd">
             <policyconfig>
               <vendor>Fleasion</vendor>
               <vendor_url>https://github.com/fleasion/Fleasion</vendor_url>
               <action id="${polkitRunActionId}">
                 <description>Run the Fleasion Linux proxy helper</description>
                 <message>Authentication is required to let Fleasion update POC proxy hosts and run its local port-443 relay.</message>
                 <defaults>
                   <allow_any>no</allow_any>
                   <allow_inactive>no</allow_inactive>
                   <allow_active>yes</allow_active>
                 </defaults>
                 <annotate key="org.freedesktop.policykit.exec.path">${installedHelperPath}</annotate>
                 <annotate key="org.freedesktop.policykit.exec.argv1">--backend-port</annotate>
               </action>
               <action id="${polkitInstallCaActionId}">
                 <description>Install the Fleasion proxy CA into Linux system trust</description>
                 <message>Authentication is required to trust Fleasion's proxy CA for system WebView traffic.</message>
                 <defaults>
                   <allow_any>no</allow_any>
                   <allow_inactive>no</allow_inactive>
                   <allow_active>auth_admin</allow_active>
                 </defaults>
                 <annotate key="org.freedesktop.policykit.exec.path">${installedHelperPath}</annotate>
                 <annotate key="org.freedesktop.policykit.exec.argv1">--install-system-ca</annotate>
               </action>
             </policyconfig>
           '';
 
           polkitPromptlessRule = ''
             polkit.addRule(function(action, subject) {
                 if (action.id == "${polkitRunActionId}" &&
                     subject.local && subject.active &&
                     (subject.isInGroup("sudo") || subject.isInGroup("wheel"))) {
                     return polkit.Result.YES;
                 }
             });
           '';
         in
      {
        packages.default = fleasionPackage;

        apps.default = {
          type = "app";
          program = "${fleasionPackage}/bin/fleasion-src";
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [ pythonEnv ] ++ runtimeLibs;
          LD_LIBRARY_PATH = libPath;
          };

        _fleasionPolkit = {
          inherit helperWrapper installedHelperPath polkitPolicyXml polkitPromptlessRule polkitActionNamespace;
          inherit pythonEnv;
          helperDaemonScript = "${srcDir}/src/Fleasion/linux_proxy_helper_daemon.py";
        };
      }
    )
    // {
      nixosModules.default = { config, lib, pkgs, ... }:
        with lib;
        let
          cfg = config.services.fleasion-proxy-helper;
          polkitData = self._fleasionPolkit.${pkgs.system};
          parentDir = builtins.dirOf polkitData.installedHelperPath;
        in
        {
          options.services.fleasion-proxy-helper = {
            enable = mkEnableOption "Fleasion Linux proxy helper Polkit integration";
            promptless = mkOption {
              type = types.bool;
              default = true;
              description = ''
                Auto-approve the Fleasion proxy helper action for local, active
                users in the "sudo" or "wheel" group, without a password prompt
                on every launch. Leave false to always require confirmation.
              '';
            };
          };

          config = mkIf cfg.enable {
            environment.etc."polkit-1/actions/${polkitData.polkitActionNamespace}.policy".text =
              polkitData.polkitPolicyXml;

            environment.etc."polkit-1/rules.d/50-fleasion-promptless.rules" = mkIf cfg.promptless {
              text = polkitData.polkitPromptlessRule;
            };

            systemd.tmpfiles.rules = [
              "d ${parentDir} 0755 root root -"
              "L+ ${polkitData.installedHelperPath} - - - - ${polkitData.helperWrapper}"
            ];
          };
        };
      nixosModules.system = import ./fleasion-system.nix { inherit self; };
    };
}
