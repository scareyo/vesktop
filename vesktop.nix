{
  lib,
  stdenv,
  makeWrapper,
  makeDesktopItem,
  copyDesktopItems,
  electron,
  libicns,
  pipewire,
  libpulseaudio,
  libx11,
  libxcb,
  libxkbcommon,
  libxtst,
  autoPatchelfHook,
  pnpm,
  fetchPnpmDeps,
  pnpmConfigHook,
  nodejs,
  jq,
  nix-update-script,
  withTTS ? true,
  withMiddleClickScroll ? false,
  version
}:

stdenv.mkDerivation (finalAttrs: {
  inherit version;

  pname = "vesktop";

  src = ./.;

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm;
    fetcherVersion = 3;
    hash = "sha256-p4mSgOHQcx6ff/Mf6JVht9LEYixCZoG7y8vjOw8MMlE=";
  };

  nativeBuildInputs = [
    nodejs
    pnpmConfigHook
    pnpm
    jq
    autoPatchelfHook
    copyDesktopItems
    # we use a script wrapper here for environment variable expansion at runtime
    # https://github.com/NixOS/nixpkgs/issues/172583
    makeWrapper
  ];

  buildInputs = [
    libpulseaudio
    pipewire

    # Venbind
    libx11.dev
    libxcb.dev
    libxkbcommon.dev
    libxtst

    (lib.getLib stdenv.cc.cc)
  ];

  env = {
    ELECTRON_SKIP_BINARY_DOWNLOAD = 1;
  };

  preBuild = ''
    # Validate electron version matches upstream package.json
    expectedMajor="$(jq -r '.devDependencies.electron | ltrimstr("^") | split(".") | .[0]' < package.json)"
    actualMajor="${lib.versions.major electron.version}"
    if [ "$actualMajor" -lt "$expectedMajor" ] 2>/dev/null; then
      echo "ERROR: nixpkgs electron version (major $actualMajor) is older than upstream package.json requirement (major $expectedMajor)"
      exit 1
    fi

    # electron builds must be writable
    cp -r ${electron.dist} electron-dist
    chmod -R u+w electron-dist
  '';

  buildPhase = ''
    runHook preBuild

    pnpm build
    pnpm exec electron-builder \
      --dir \
      -c.asarUnpack="**/*.node" \
      -c.electronDist=electron-dist \
      -c.electronVersion=${electron.version} \

    runHook postBuild
  '';

  postBuild = ''
    pushd build
    ${libicns}/bin/icns2png -x icon.icns
    popd
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/opt/Vesktop
    cp -r dist/*unpacked/resources $out/opt/Vesktop/

    for file in build/icon_*x32.png; do
      file_suffix=''${file//build\/icon_}
      install -Dm0644 $file $out/share/icons/hicolor/''${file_suffix//x32.png}/apps/vesktop.png
    done

    runHook postInstall
  '';

  postFixup = ''
    makeWrapper ${electron}/bin/electron $out/bin/vesktop \
      --add-flags $out/opt/Vesktop/resources/app.asar \
      ${lib.strings.optionalString withTTS ''
        --run 'if [[ "''${NIXOS_SPEECH:-default}" != "False" ]]; then NIXOS_SPEECH=True; else unset NIXOS_SPEECH; fi' \
        --add-flags "\''${NIXOS_SPEECH:+--enable-speech-dispatcher}" \
      ''} \
      ${lib.optionalString withMiddleClickScroll "--add-flags \"--enable-blink-features=MiddleClickAutoscroll\""} \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}"
  '';

  desktopItems = (makeDesktopItem {
    name = "dev.vencord.Vesktop";
    desktopName = "Vesktop";
    exec = "vesktop %U";
    icon = "vesktop";
    startupWMClass = "Vesktop";
    genericName = "Internet Messenger";
    keywords = [
      "discord"
      "vencord"
      "electron"
      "chat"
    ];
    categories = [
      "Network"
      "InstantMessaging"
      "Chat"
    ];
    mimeTypes = [
      "x-scheme-handler/discord"
    ];
  });

  passthru = {
    inherit (finalAttrs) pnpmDeps;
    updateScript = nix-update-script { };
  };

  meta = {
    description = "Alternate client for Discord with Vencord built-in";
    homepage = "https://github.com/scareyo/vesktop";
    license = lib.licenses.gpl3Only;
    mainProgram = "vesktop";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
})
