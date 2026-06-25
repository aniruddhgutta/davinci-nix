{
  description = "A flake for DaVinci Resolve Studio with FFmpeg encoder plugin and patches";

  inputs = {
    # Main nixpkgs input (NixOS 26.05)
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # Pinned nixpkgs input exclusively for the raw DaVinci Resolve Studio binary
    nixpkgs-pinned.url = "github:NixOS/nixpkgs/e4ec59bc1152b09a4843702e4a49381194f065a2";

    # Custom mesa input
    # mesa-davinci.url = "github:nixos/nixpkgs?ref=599ddd2b79331c1e6153e1659bdaab65d62c4c82";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-pinned,
      # mesa-davinci,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      lib = nixpkgs.lib;

      # Import main pkgs (NixOS 26.05)
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      # Import pinned pkgs (Used *only* to fetch the unpatched binary)
      pkgs-pinned = import nixpkgs-pinned {
        inherit system;
        config.allowUnfree = true;
      };

      # mesa-good-pkg = mesa-davinci.legacyPackages.${system}.mesa;

      # Built using NixOS 26.05
      ffmpeg-encoder-plugin = pkgs.stdenv.mkDerivation (finalAttrs: {
        pname = "ffmpeg-encoder-plugin";
        version = "1.2.1";

        src = pkgs.fetchFromGitHub {
          owner = "EdvinNilsson";
          repo = "ffmpeg_encoder_plugin";
          rev = "v${finalAttrs.version}";
          hash = "sha256-F4Q8YCXD5UldTwLbWK4nHacNPQ/B+4yLL96sq7xZurM=";
        };

        nativeBuildInputs = [ pkgs.cmake ];
        buildInputs = [ pkgs.ffmpeg-full ];

        installPhase = ''
          mkdir -p $out
          cp ffmpeg_encoder_plugin.dvcp $out/
        '';
      });

      davinci-resolve-studio-cracked =
        let
          davinci-patched =
            let
              # ONLY this specific line touches the pinned repository
              davinci-locked = pkgs-pinned.davinci-resolve-studio;
            in
            davinci-locked.davinci.overrideAttrs (old: {
              postInstall = ''
                ${old.postInstall or ""}
                # Patched using 26.05 perl tools
                ${lib.getExe pkgs.perl} -pi -e 's/\x74\x11\xe8\x21\x23\x00\x00/\xeb\x11\xe8\x21\x23\x00\x00/g' $out/bin/resolve
                ${lib.getExe pkgs.perl} -pi -e 's/\x03\x00\x89\x45\xFC\x83\x7D\xFC\x00\x74\x11\x48\x8B\x45\xC8\x8B/\x03\x00\x89\x45\xFC\x83\x7D\xFC\x00\xEB\x11\x48\x8B\x45\xC8\x8B/' $out/bin/resolve
                ${lib.getExe pkgs.perl} -pi -e 's/\x74\x11\x48\x8B\x45\xC8\x8B\x55\xFC\x89\x50\x58\xB8\x00\x00\x00/\xEB\x11\x48\x8B\x45\xC8\x8B\x55\xFC\x89\x50\x58\xB8\x00\x00\x00/' $out/bin/resolve
                ${lib.getExe pkgs.perl} -pi -e 's/\x41\xb6\x01\x84\xc0\x0f\x84\xb0\x00\x00\x00\x48\x85\xdb\x74\x08\x45\x31\xf6\xe9\xa3\x00\x00\x00/\x41\xb6\x00\x84\xc0\x0f\x84\xb0\x00\x00\x00\x48\x85\xdb\x74\x08\x45\x31\xf6\xe9\xa3\x00\x00\x00/' $out/bin/resolve
                touch $out/.license/blackmagic.lic
                echo -e "LICENSE blackmagic davinciresolvestudio 999999 permanent uncounted\n  hostid=ANY issuer=CGP customer=CGP issued=28-dec-2023\n  akey=0000-0000-0000-0000 _ck=00 sig=\"00\"" > $out/.license/blackmagic.lic

                mkdir -p $out/IOPlugins
                mkdir -p $out/IOPlugins/ffmpeg_encoder_plugin.dvcp.bundle/Contents/Linux-x86-64
                cp ${ffmpeg-encoder-plugin}/ffmpeg_encoder_plugin.dvcp $out/IOPlugins/ffmpeg_encoder_plugin.dvcp.bundle/Contents/Linux-x86-64/
              '';
            });
        in
        # Sandbox framework evaluated entirely against NixOS 26.05
        pkgs.buildFHSEnv {
          inherit (davinci-patched) pname version;

          targetPkgs =
            inner-pkgs:
            with inner-pkgs;
            [
              alsa-lib
              aprutil
              bzip2
              dbus
              expat
              fontconfig
              freetype
              glib
              libGL
              libGLU
              libarchive
              libcap
              librsvg
              libtool
              libuuid
              libxcrypt
              libxkbcommon
              nspr
              ocl-icd
              opencl-headers
              python3
              python3.pkgs.numpy
              udev
              xdg-utils
              libice
              libsm
              libx11
              libxcomposite
              libxcursor
              libxdamage
              libxext
              libxfixes
              libxi
              libxinerama
              libxrandr
              libxrender
              libxt
              libxtst
              libxxf86vm
              libxcb
              xcbutil
              xcbutilimage
              xcbutilkeysyms
              xcbutilrenderutil
              xcbutilwm
              xkeyboardconfig
              zlib
              rocmPackages.clr.icd
              mesa
            ]
            ++ [
              # mesa-good-pkg
              davinci-patched
            ];

          extraPreBwrapCmds = ''
            mkdir -p ~/.local/share/DaVinciResolve/Extras || exit 1
          '';

          extraBwrapArgs = [
            # 1. Mount the Extras folder cleanly to the user's home directory
            ''--bind "$HOME"/.local/share/DaVinciResolve/Extras /Extras''

            # 2. Let bubblewrap safely create the required bundle subdirectory inside the existing structure
            "--dir /IOPlugins/ffmpeg_encoder_plugin.dvcp.bundle/Contents/Linux-x86-64"

            # 3. Mount the built plugin file directly into its bundle location
            "--ro-bind ${ffmpeg-encoder-plugin}/ffmpeg_encoder_plugin.dvcp /IOPlugins/ffmpeg_encoder_plugin.dvcp.bundle/Contents/Linux-x86-64/ffmpeg_encoder_plugin.dvcp"
          ];

          runScript = "${lib.getExe pkgs.bash} ${pkgs.writeText "davinci-wrapper" ''
            export QT_XKB_CONFIG_ROOT="${pkgs.xkeyboard_config}/share/X11/xkb"
            export QT_PLUGIN_PATH="${davinci-patched}/libs/plugins:$QT_PLUGIN_PATH"
            export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/lib:/usr/lib32:${davinci-patched}/libs
            export QT_QPA_PLATFORM=xcb
            unset WAYLAND_DISPLAY
            ${davinci-patched}/bin/resolve
          ''}";

          extraInstallCommands = ''
            mkdir -p $out/share/applications $out/share/icons/hicolor/128x128/apps
            ln -s ${davinci-patched}/share/applications/*.desktop $out/share/applications/
            ln -s ${davinci-patched}/graphics/DV_Resolve.png $out/share/icons/hicolor/128x128/apps/davinci-resolve-studio.png
          '';

          passthru = {
            inherit davinci-patched;
            updateScript = lib.getExe (
              pkgs.writeShellApplication {
                name = "update-davinci-resolve";
                runtimeInputs = [
                  pkgs.curl
                  pkgs.jq
                  pkgs.common-updater-scripts
                ];
                text = ''
                  set -o errexit
                  drv=pkgs/by-name/da/davinci-resolve/package.nix
                  currentVersion=${lib.escapeShellArg davinci-patched.version}
                  downloadsJSON="$(curl --fail --silent https://www.blackmagicdesign.com/api/support/us/downloads.json)"

                  latestLinuxVersion="$(echo "$downloadsJSON" | jq '[.downloads[] | select(.urls.Linux) | .urls.Linux[] | select(.downloadTitle | test("DaVinci Resolve")) | .downloadTitle]' | grep -oP 'DaVinci Resolve \K\d+\.\d+(\.\d+)?' | sort | tail -n 1)"
                  update-source-version davinci-resolve "$latestLinuxVersion" --source-key=davinci.src

                  sed -i -e "s/""$latestLinuxVersion""/""$currentVersion""/" "$drv"

                  latestStudioLinuxVersion="$(echo "$downloadsJSON" | jq '[.downloads[] | select(.urls.Linux) | .urls.Linux[] | select(.downloadTitle | test("DaVinci Resolve")) | .downloadTitle]' | grep -oP 'DaVinci Resolve Studio \K\d+\.\d+(\.\d+)?' | sort | tail -n 1)"
                  update-source-version davinci-resolve-studio "$latestStudioLinuxVersion" --source-key=davinci.src
                '';
              }
            );
          };
        };
    in
    {
      packages.${system} = {
        davinci-resolve-studio-cracked = davinci-resolve-studio-cracked;
        default = davinci-resolve-studio-cracked;
      };
    };
}
