#!/usr/bin/env bash
# Officiële Omarchy-plugininstallatie voor 80procent: acculimiet-schakelaar
# voor Intel-MacBooks. Werkt vanaf elke locatie: USB-stick, github-kopie,
# willekeurige map.
#
# De acculimiet zit in de Apple-SMC en wordt geschreven via de setuid-root
# helper /usr/local/bin/macbook-charge-limit. Die ene installstap vraagt je
# sudo-wachtwoord (eenmalig); alles daarna werkt zonder wachtwoord.
#
#   install     installeer of ververs de plugin
#   helper      laat zien/installeer de setuid-root helper (eenmalig, sudo)
#   version     toon gebundelde en geïnstalleerde versie
#   uninstall   verwijder de plugin; de SMC-limiet blijft zoals hij staat
set -euo pipefail

SRC_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$SRC_DIR/manifest.json"
HELPER=/usr/local/bin/macbook-charge-limit
TOOL_BIN="$SRC_DIR/tool/macbook-charge-limit"
PLUGINS_DIR="$HOME/.config/omarchy/plugins"

say()  { printf '\033[1m%s\033[0m\n' "$*"; }
info() { printf '  %s\n' "$*"; }
fail() { printf 'installer: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<EOF
gebruik: ./install.sh [commando]

commando:
  install     (standaard) installeer of ververs de plugin
  helper      eenmalig de setuid-root helper installeren (sudo-wachtwoord)
  version     toon gebundelde en geïnstalleerde versie
  uninstall   verwijder de plugin via de officiële omarchy-tooling
  help        dit overzicht
EOF
}

require_omarchy() {
  command -v omarchy >/dev/null 2>&1 || fail "omarchy is niet gevonden; dit is een Omarchy-plugin"
  command -v jq >/dev/null 2>&1 || fail "jq is niet geïnstalleerd"
}

plugin_id()   { jq -r '.id // empty' "$MANIFEST"; }
bundled_version() { jq -r '.version // "0"' "$MANIFEST"; }

installed_version() {
  local m="$PLUGINS_DIR/$(plugin_id)/manifest.json"
  [[ -f $m ]] && jq -r '.version // "0"' "$m" || echo ""
}

helper_build() {
  if [[ -x $TOOL_BIN ]]; then return; fi
  info "bundel bevat nog geen gebouwde helper; hij wordt gebouwd (gcc)"
  ( cd "$SRC_DIR/tool" && make ) >/dev/null || fail "helper kon niet worden gebouwd"
}

helper_status() {
  if [[ ! -x $HELPER ]]; then
    say "helper NIET geïnstalleerd"
    return 1
  fi
  if [[ $(stat -c '%a' "$HELPER") != *4* ]]; then
    say "helper aanwezig maar geen setuid-root"
    return 1
  fi
  say "helper in orde: $HELPER"
  return 0
}

helper() {
  helper_build
  if helper_status; then return 0; fi
  say "Voer nu in een terminal de volgende regel uit (vraagt eenmalig je sudo-wachtwoord):"
  printf '\n  sudo install -m 4755 -o root -g root %s %s\n\n' "$TOOL_BIN" "$HELPER"
  fail "de helper mist; voer bovenstaande regel eerst uit en herhaal ./install.sh install"
}

install() {
  require_omarchy
  local id
  id=$(plugin_id)

  say "[1/5] Plugin valideren (officiële schema- en veiligheidscheck)"
  omarchy plugin validate "$SRC_DIR"
  info "ok: $id"

  say "[2/5] Helper controleren (de setuid-root accu-helper)"
  helper_build
  if ! helper_status >/dev/null; then
    fail "helper ontbreekt. Eerst: ./install.sh helper (dan nogmaals install)"
  fi

  say "[3/5] Kopiëren naar $PLUGINS_DIR/$id"
  local stage="$PLUGINS_DIR/.$id.install.$$"
  rm -rf "$stage"
  mkdir -p "$stage"
  cp -a "$SRC_DIR/manifest.json" "$SRC_DIR/Panel.qml" "$stage/"
  cp -a "$SRC_DIR/bin" "$stage/bin"
  chmod +x "$stage"/bin/laadlimiet

  if [[ -e $PLUGINS_DIR/$id ]]; then
    mkdir -p "$HOME/.config/omarchy/plugin-backups"
    cp -a "$PLUGINS_DIR/$id" "$HOME/.config/omarchy/plugin-backups/$id-$(date +%Y%m%d-%H%M%S)"
    info "vorige installatie bewaard in plugin-backups"
  fi
  rm -rf "$PLUGINS_DIR/$id"
  mv "$stage" "$PLUGINS_DIR/$id"

  say "[4/5] Plugins opnieuw laten ontdekken en inschakelen"
  omarchy-shell shell rescanPlugins >/dev/null || true
  if ! omarchy plugin list --json 2>/dev/null | jq -e --arg id "$id" 'any(.[]; .id == $id and .enabled)' >/dev/null 2>&1; then
    for (( attempt = 0; attempt < 40; attempt++ )); do
      omarchy plugin list --json 2>/dev/null | jq -e --arg id "$id" 'any(.[]; .id == $id)' >/dev/null 2>&1 && break
      sleep 0.05
    done
    local section
    section=$(jq -r '.barWidget.defaultSection // "left"' "$MANIFEST")
    omarchy plugin enable "$id" "$section"
  fi

  say "[5/5] Klaar"
  info "Klik op het accu-icoontje in de bar: link = schakelen, rechts = status."
  info "Versies: ./install.sh version  |  verwijderen: ./install.sh uninstall"
}

uninstall() {
  require_omarchy
  local id
  id=$(plugin_id)
  if omarchy plugin list --json 2>/dev/null | jq -e --arg id "$id" 'any(.[]; .id == $id)' >/dev/null 2>&1; then
    omarchy plugin remove "$id"
  else
    info "plugin $id is niet geïnstalleerd; niets te doen"
  fi
  say "De SMC-limiet blijft zoals hij nu staat (reset met: sudo $HELPER reset)"
}

version() {
  require_omarchy
  say "Versie-overzicht"
  info "gebundeld (deze map):  $(bundled_version)"
  local inst
  inst=$(installed_version)
  [[ -n $inst ]] && info "geïnstalleerd:          $inst" || info "niet geïnstalleerd op deze machine"
  helper_status || info "(helper: installeer met ./install.sh helper)"
}

case "${1:-install}" in
  install|"") install ;;
  helper) helper ;;
  version|info) version ;;
  uninstall|remove|rm) uninstall ;;
  help|-h|--help) usage ;;
  *) fail "onbekend commando '$1' (zie: ./install.sh help)" ;;
esac