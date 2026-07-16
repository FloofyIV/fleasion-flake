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
          sha256 = "sha256-cuyBLcsZJcTxx45T8gkMHm1jk5YC7GeYFGfZrJm/qgc=";
        };

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

        fleasion = pkgs.writeShellScriptBin "fleasion" ''
          set -euo pipefail

          export LD_LIBRARY_PATH="${libPath}:''${LD_LIBRARY_PATH:-}"
          export PYTHONPATH="${fleasionSrc}/src:''${PYTHONPATH:-}"

          VENV_DIR="''${XDG_CACHE_HOME:-$HOME/.cache}/fleasion-venv"

          if [ ! -d "$VENV_DIR" ]; then
            ${pythonEnv}/bin/python -m venv \
              --system-site-packages \
              "$VENV_DIR"
          fi

          source "$VENV_DIR/bin/activate"

          python -c "import DracoPy" 2>/dev/null || \
            pip install --quiet DracoPy

          python -c "import browser_cookie3" 2>/dev/null || \
            pip install --quiet browser-cookie3

          cd "${fleasionSrc}"

          exec python launcher.py "$@"
        '';

        fleasionProxyHelper = pkgs.writeShellScriptBin "fleasion-linux-proxy-helper" ''
          set -euo pipefail

          export LD_LIBRARY_PATH="${libPath}:''${LD_LIBRARY_PATH:-}"
          export PYTHONPATH="${fleasionSrc}/src:''${PYTHONPATH:-}"

          exec ${pythonEnv}/bin/python \
            -m Fleasion.linux_proxy_helper_daemon "$@"
        '';

        fleasionDesktopItem = pkgs.makeDesktopItem {
          name = "fleasion";
          desktopName = "Fleasion";
          exec = "fleasion";
          icon = "fleasion";
          categories = [
            "Utility"
          ];
        };

        fleasionPackage = pkgs.symlinkJoin {
          name = "fleasion";

          paths = [
            fleasion
            fleasionProxyHelper
            fleasionDesktopItem
          ];

          postBuild = ''
            mkdir -p \
              $out/share/icons/hicolor/256x256/apps

            cp ${./fleasion.png} \
              $out/share/icons/hicolor/256x256/apps/fleasion.png
          '';
        };

      in
      {
        packages.default = fleasionPackage;

        apps.default = {
          type = "app";
          program = "${fleasionPackage}/bin/fleasion";
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [
            pythonEnv
          ] ++ runtimeLibs;

          LD_LIBRARY_PATH = libPath;
        };
      }
    );
}
