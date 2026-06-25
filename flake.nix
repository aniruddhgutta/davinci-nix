{
  description = "A flake for DaVinci Resolve Studio with FFmpeg encoder plugin and patches";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # Version of nixpkgs just before davinci updated to 20.3.3 (which patches this)
    nixpkgs-pinned.url = "github:NixOS/nixpkgs/e4ec59bc1152b09a4843702e4a49381194f065a2";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-pinned,
      ...
    }:
    let
      system = "x86_64-linux";
      lib = nixpkgs.lib; # For compatibility

      # Allow unfree in nixpkgs
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      pkgs-pinned = import nixpkgs-pinned {
        inherit system;
        config.allowUnfree = true;
      };

      # Build derivation of ffmpeg encoder
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

      # Failed attempt to stop davinci rebuilding every time
      davinci-locked = pkgs-pinned.davinci-resolve-studio;

      davinci-resolve-studio-cracked =
        let

          # Patching step
          davinci-patched = davinci-locked.davinci.overrideAttrs (old: {
            postInstall = ''
                              ${old.postInstall or ""}

              								# Patch davinci binary
                              ${lib.getExe pkgs.perl} -pi -e 's/\x74\x11\xe8\x21\x23\x00\x00/\xeb\x11\xe8\x21\x23\x00\x00/g' $out/bin/resolve
                              ${lib.getExe pkgs.perl} -pi -e 's/\x03\x00\x89\x45\xFC\x83\x7D\xFC\x00\x74\x11\x48\x8B\x45\xC8\x8B/\x03\x00\x89\x45\xFC\x83\x7D\xFC\x00\xEB\x11\x48\x8B\x45\xC8\x8B/' $out/bin/resolve
                              ${lib.getExe pkgs.perl} -pi -e 's/\x74\x11\x48\x8B\x45\xC8\x8B\x55\xFC\x89\x50\x58\xB8\x00\x00\x00/\xEB\x11\x48\x8B\x45\xC8\x8B\x55\xFC\x89\x50\x58\xB8\x00\x00\x00/' $out/bin/resolve
                              ${lib.getExe pkgs.perl} -pi -e 's/\x41\xb6\x01\x84\xc0\x0f\x84\xb0\x00\x00\x00\x48\x85\xdb\x74\x08\x45\x31\xf6\xe9\xa3\x00\x00\x00/\x41\xb6\x00\x84\xc0\x0f\x84\xb0\x00\x00\x00\x48\x85\xdb\x74\x08\x45\x31\xf6\xe9\xa3\x00\x00\x00/' $out/bin/resolve

              								# Make dummy license file
                              touch $out/.license/blackmagic.lic
                              echo -e "LICENSE blackmagic davinciresolvestudio 999999 permanent uncounted\n  hostid=ANY issuer=CGP customer=CGP issued=28-dec-2023\n  akey=0000-0000-0000-0000 _ck=00 sig=\"00\"" > $out/.license/blackmagic.lic
            '';
          });
        in
        # Build davinci sandbox
        pkgs.buildFHSEnv {
          inherit (davinci-patched) pname version;

          # Taken from davinci's package.nix (not sure if even necessary)
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
              mesa
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
            ]
            ++ [
              # Custom patched davinci
              davinci-patched
            ];

          # Make user facing directories
          extraPreBwrapCmds = ''
            mkdir -p ~/.local/share/DaVinciResolve/Extras || exit 1
            mkdir -p ~/.local/share/DaVinciResolve/IOPlugins || exit 1
          '';

          extraBwrapArgs = [
            # Mount extras folder to home
            ''--bind "$HOME"/.local/share/DaVinciResolve/Extras /Extras''

            # Set up bwrap dir for ffmpeg plugin
            "--dir /IOPlugins/ffmpeg_encoder_plugin.dvcp.bundle/Contents/Linux-x86-64"

            # Mount bundle file into correct location
            "--ro-bind ${ffmpeg-encoder-plugin}/ffmpeg_encoder_plugin.dvcp /IOPlugins/ffmpeg_encoder_plugin.dvcp.bundle/Contents/Linux-x86-64/ffmpeg_encoder_plugin.dvcp"

            # Bind IOPlugins to home after plugin install to avoid weird linking behaviour
            ''--bind "$HOME"/.local/share/DaVinciResolve/IOPlugins /IOPlugins''
          ];

          # Wrapper to stop wayland nonsense from occuring (Use I3 if you want to use 2 screen mode)
          runScript = "${lib.getExe pkgs.bash} ${pkgs.writeText "davinci-wrapper" ''
            export QT_XKB_CONFIG_ROOT="${pkgs.xkeyboard_config}/share/X11/xkb"
            export QT_PLUGIN_PATH="${davinci-patched}/libs/plugins:$QT_PLUGIN_PATH"
            export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/lib:/usr/lib32:${davinci-patched}/libs
            export QT_QPA_PLATFORM=xcb
            unset WAYLAND_DISPLAY
            ${davinci-patched}/bin/resolve
          ''}";

          # Application entries
          extraInstallCommands = ''
            mkdir -p $out/share/applications $out/share/icons/hicolor/128x128/apps
            ln -s ${davinci-patched}/share/applications/*.desktop $out/share/applications/
            ln -s ${davinci-patched}/graphics/DV_Resolve.png $out/share/icons/hicolor/128x128/apps/davinci-resolve-studio.png
          '';

          # Stolen update script that doesnt work lol
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
    # Provide default package
    {
      packages.${system} = {
        davinci-resolve-studio-cracked = davinci-resolve-studio-cracked;
        default = davinci-resolve-studio-cracked;
      };
    };
}
