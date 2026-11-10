{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  ffmpeg-full,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "ffmpeg-encoder-plugin";
  version = "1.4.0";

  src = fetchFromGitHub {
    owner = "EdvinNilsson";
    repo = "ffmpeg_encoder_plugin";
    rev = "v${finalAttrs.version}";
    hash = "sha256-q37cA1GR2+qPzrJVrAN9uOqEmQ6ehPrmZWt+v4W94OE=";
  };

  nativeBuildInputs = [ cmake ];
  buildInputs = [ ffmpeg-full ];

  installPhase = ''
    mkdir -p $out
    cp ffmpeg_encoder_plugin.dvcp $out/
  '';

  meta = {
    description = "FFmpeg Encoder Plugin for DaVinci Resolve Studio";
    homepage = "https://github.com/EdvinNilsson/ffmpeg_encoder_plugin";
    license = lib.licenses.gpl3Only;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
  };
})
