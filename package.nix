{
  lib,
  pkgs,
  callPackage,
  buildFHSEnv,
  writeText,
  bash,
  xkeyboard_config,
  davinci-resolve-studio,
}:
let
  ffmpeg-encoder-plugin = callPackage ./ffmpeg-encoder-plugin.nix { };
  plugdir = "/IOPlugins/ffmpeg_encoder_plugin.dvcp.bundle/Contents/Linux-x86-64";

  davinci = davinci-resolve-studio.davinci.overrideAttrs (old: {
    postInstall = ''
      ${old.postInstall or ""}
      # ref: https://www.reddit.com/r/LinuxCrackSupport/comments/1vpucp8/davinci_resolve_studio_21xx_bypass_licence_guide
      ${lib.getExe pkgs.perl} -pi -e 's/\x03\x00\x89\x45\xFC\x83\x7D\xFC\x00\x74\x11\x48\x8B\x45\xC8\x8B/\x03\x00\x89\x45\xFC\x83\x7D\xFC\x00\xEB\x11\x48\x8B\x45\xC8\x8B/g' $out/bin/resolve
      ${lib.getExe pkgs.perl} -pi -e 's/\x74\x11\x48\x8B\x45\xC8\x8B\x55\xFC\x89\x50\x58\xB8\x00\x00\x00/\xEB\x11\x48\x8B\x45\xC8\x8B\x55\xFC\x89\x50\x58\xB8\x00\x00\x00/g' $out/bin/resolve
      ${lib.getExe pkgs.perl} -0777 -pi -e 's/(\x40\x84\xED)\x74(.\xBF\x16\x00\x00\x00\xBE.\x01\x00\x00\xE8)/$1\x75$2/g' $out/bin/resolve
      touch $out/.license/blackmagic.lic
      echo -e "LICENSE blackmagic davinciresolvestudio 999999 permanent uncounted\n  hostid=ANY issuer=CGP customer=CGP issued=28-dec-2023\n  akey=0000-0000-0000-0000 _ck=00 sig=\"00\"" > $out/.license/blackmagic.lic

      mkdir -p $out${plugdir}
      cp ${ffmpeg-encoder-plugin}/ffmpeg_encoder_plugin.dvcp $out${plugdir}/
    '';
  });

  # default alsa -> pulse so resolve doesn't hang without a hw device
  alsaConf = writeText "davinci-alsa.conf" ''
    pcm.!default { type pulse }
    ctl.!default { type pulse }
  '';
in
buildFHSEnv {
  inherit (davinci) pname version;

  targetPkgs =
    p:
    with p;
    [
      alsa-lib
      alsa-plugins
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
    ++ [ davinci ];

  extraPreBwrapCmds = ''
    mkdir -p ~/.local/share/DaVinciResolve/Extras || exit 1
  '';

  extraBwrapArgs = [
    ''--bind "$HOME"/.local/share/DaVinciResolve/Extras /Extras''
    "--dir ${plugdir}"
    "--ro-bind ${ffmpeg-encoder-plugin}/ffmpeg_encoder_plugin.dvcp ${plugdir}/ffmpeg_encoder_plugin.dvcp"
  ];

  runScript = "${lib.getExe bash} ${writeText "davinci-wrapper" ''
    export ALSA_CONFIG_PATH="${alsaConf}"
    export QT_XKB_CONFIG_ROOT="${xkeyboard_config}/share/X11/xkb"
    export QT_PLUGIN_PATH="${davinci}/libs/plugins:$QT_PLUGIN_PATH"
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/lib:/usr/lib32:${davinci}/libs
    export QT_QPA_PLATFORM=xcb
    unset WAYLAND_DISPLAY
    exec ${davinci}/bin/resolve
  ''}";

  extraInstallCommands = ''
    mkdir -p $out/share/applications $out/share/icons/hicolor/128x128/apps
    ln -s ${davinci}/share/applications/*.desktop $out/share/applications/
    ln -s ${davinci}/graphics/DV_Resolve.png $out/share/icons/hicolor/128x128/apps/davinci-resolve-studio.png
  '';

  meta = {
    description = "DaVinci Resolve Studio with FFmpeg encoder plugin";
    homepage = "https://www.blackmagicdesign.com/products/davinciresolve";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "davinci-resolve-studio";
  };
}
