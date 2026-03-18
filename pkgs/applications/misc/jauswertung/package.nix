{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  jdk,
  xdg-utils,
}:

stdenv.mkDerivation rec {
  pname = "jauswertung";
  version = "18.0.1";

  src = fetchurl {
    url = "https://github.com/dennisfabri/JAuswertung/releases/download/v${version}/JAuswertung-${version}-Setup.tar";
    hash = "sha256-24YUPfvKq6bX/FgxElpqSU1JCxT/mBhtfN8PJ/+0xv4=";
  };

  nativeBuildInputs = [
    makeWrapper
  ];

  buildInputs = [
    jdk
  ];

  dontUnpack = true;

  # install4j supports fully headless unattended mode via -q.
  # By setting INSTALL4J_JAVA_HOME we force the installer to use our JDK
  # instead of the bundled JRE it ships with (which is a generic Linux binary
  # that cannot run in the Nix sandbox).
  installPhase = ''
    runHook preInstall

    mkdir -p setup
    tar xf $src -C setup
    chmod +x setup/JAuswertung-${version}-Setup.sh

    export HOME=$TMPDIR
    export XDG_CACHE_HOME=$TMPDIR/.cache
    mkdir -p "$XDG_CACHE_HOME"
    export INSTALL4J_JAVA_HOME="${jdk}"

    # -q  = unattended / headless (no GUI, no xvfb needed)
    # -dir = target directory
    setup/JAuswertung-${version}-Setup.sh -q -dir "$out"

    # Wrap every launcher so it finds the JDK at runtime
    mkdir -p "$out/bin"
    for launcher in \
        JAuswertung \
        JTeams \
        AlphaServer \
        Strafenkatalog \
        Regelwerkseditor \
        Veranstaltungswertung \
        UISettings \
        AresWriter; do
      src_bin="$out/$launcher"
      if [ -f "$src_bin" ]; then
        chmod +x "$src_bin"
        lower=$(echo "$launcher" | tr '[:upper:]' '[:lower:]')
        wrapProgram "$src_bin" \
          --set INSTALL4J_JAVA_HOME "${jdk}" \
          --prefix PATH : "${lib.makeBinPath [ xdg-utils ]}"
        ln -sf "$src_bin" "$out/bin/$lower"
      fi
    done

    mkdir -p "$out/share/applications"
    cat > "$out/share/applications/jauswertung.desktop" <<EOF
[Desktop Entry]
Name=JAuswertung
Comment=Software for managing swimming competitions
Exec=$out/bin/jauswertung
Icon=$out/.install4j/JAuswertung.png
Type=Application
Categories=Office;Sports;
Terminal=false
StartupWMClass=install4j-de-df-jauswertung-gui-JAuswertungLauncher
EOF

    runHook postInstall
  '';

  meta = {
    description = "Software for managing swimming competitions (DLRG/DSV)";
    longDescription = ''
      JAuswertung is a program that analyses and manages the results of
      contests of the DLRG (Deutsche Lebens-Rettungs-Gesellschaft - German
      Life-Saving Organisation), but it can be used for any time-based
      contest. It handles run scheduling, time entry, result calculation,
      certificate printing and more.
    '';
    homepage = "https://github.com/dennisfabri/JAuswertung";
    license = lib.licenses.gpl2Plus;
    platforms = lib.platforms.linux;
    maintainers = with lib.maintainers; [ Egge987 ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
