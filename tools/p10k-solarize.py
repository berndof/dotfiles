#!/usr/bin/env python3
"""
p10k-solarize.py — converte as cores do Powerlevel10k de índice xterm-256
para truecolor hex da paleta Solarized Dark.

POR QUE ISSO EXISTE
-------------------
O p10k usa apenas índices xterm-256 >= 28 (cubo 6x6x6 + rampa de cinzas).
O Konsole só remapeia os índices ANSI 0-15 do seu colorscheme — o cubo 256
permanece no RGB padrão do xterm. Resultado: o prompt NUNCA foi Solarized;
era xterm-padrão sobre fundo Solarized. Além disso, um índice 256 é
reinterpretado conforme a paleta do terminal cliente (via SSH, isso é o
terminal do usuário, não a máquina que serve).

Convertendo para hex, o p10k emite 38;2;R;G;B e a cor é idêntica em
qualquer terminal com truecolor, local ou remoto.

USO
---
  python3 tools/p10k-solarize.py configs/zsh/.p10k.zsh            # in-place
  python3 tools/p10k-solarize.py --check configs/zsh/.p10k.zsh     # só verifica
  python3 tools/p10k-solarize.py --diff  configs/zsh/.p10k.zsh     # mostra diff

A paleta é lida de configs/konsole/colorschemes/Solarized.colorscheme,
de modo que a fonte da verdade é única.
"""

from __future__ import annotations

import argparse
import difflib
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
COLORSCHEME = REPO_ROOT / "configs/konsole/colorschemes/Solarized.colorscheme"

# --------------------------------------------------------------------------
# Paleta Solarized Dark — lida do colorscheme do Konsole (fonte da verdade)
# --------------------------------------------------------------------------
PALETTE_NAMES = {
    0: "base02",
    1: "red",
    2: "green",
    3: "yellow",
    4: "blue",
    5: "magenta",
    6: "cyan",
    7: "base2",
}
# base0..base3 são fixos do Solarized Dark (não estão no bloco [ColorN])
SOLARIZED_BASE = {
    "base03": "#002b36",
    "base02": "#073642",
    "base01": "#586e75",
    "base00": "#657b83",
    "base0": "#839496",
    "base1": "#93a1a1",
    "base2": "#eee8d5",
    "base3": "#fdf6e3",
    "yellow": "#b58900",
    "orange": "#cb4b16",
    "red": "#dc322f",
    "magenta": "#d33682",
    "violet": "#6c71c4",
    "blue": "#268bd2",
    "cyan": "#2aa198",
    "green": "#859900",
}


def load_palette() -> dict[str, str]:
    """Deriva a paleta do colorscheme do Konsole e completa com os base do Solarized."""
    pal = dict(SOLARIZED_BASE)
    txt = COLORSCHEME.read_text()
    for idx, name in PALETTE_NAMES.items():
        m = re.search(rf"^\[Color{idx}\]\nColor=(\d+),(\d+),(\d+)", txt, re.M)
        if m:
            r, g, b = (int(x) for x in m.groups())
            pal[name] = f"#{r:02x}{g:02x}{b:02x}"
    return pal


# --------------------------------------------------------------------------
# Mapeamento semântico role -> acento Solarized
#
# Chave = nome do segmento p10k SEM o prefixo POWERLEVEL9K_ e SEM o
# sufixo _FOREGROUND. Todo role presente no arquivo DEVE estar aqui:
# o script falha alto se algum ficar de fora (fail-loud, não fail-silent).
# --------------------------------------------------------------------------
ROLE_TO_ACCENT: dict[str, str] = {
    # --- git / vcs -------------------------------------------------------
    "VCS_CLEAN": "green",
    "VCS_UNTRACKED": "green",
    "VCS_MODIFIED": "yellow",
    "VCS_VISUAL_IDENTIFIER_COLOR": "green",
    "VCS_LOADING_VISUAL_IDENTIFIER_COLOR": "base0",
    # o regex de _COLOR captura o role SEM o sufixo "_COLOR"
    "VCS_VISUAL_IDENTIFIER": "green",
    "VCS_LOADING_VISUAL_IDENTIFIER": "base0",
    # --- status ----------------------------------------------------------
    "STATUS_OK": "green",
    "STATUS_OK_PIPE": "green",
    "STATUS_ERROR": "red",
    "STATUS_ERROR_SIGNAL": "red",
    "STATUS_ERROR_PIPE": "red",
    # --- diretorio -------------------------------------------------------
    "DIR": "blue",
    "DIR_ANCHOR": "blue",
    "DIR_SHORTENED": "base0",
    "DIR_WORK": "cyan",
    "DIR_WORK_ANCHOR": "cyan",
    "DIR_WORK_SHORTENED": "base0",
    "DIR_WORK_NOT_WRITABLE": "orange",
    "DIR_WORK_NOT_WRITABLE_ANCHOR": "orange",
    "DIR_WORK_NOT_WRITABLE_SHORTENED": "base0",
    "DIR_WORK_NON_EXISTENT": "red",
    "DIR_WORK_NON_EXISTENT_ANCHOR": "red",
    "DIR_WORK_NON_EXISTENT_SHORTENED": "base0",
    # --- prompt char / ruler ---------------------------------------------
    "PROMPT_CHAR_OK_VIINS": "green",
    "PROMPT_CHAR_OK_VICMD": "green",
    "PROMPT_CHAR_OK_VIVIS": "green",
    "PROMPT_CHAR_OK_VIOWR": "green",
    "PROMPT_CHAR_ERROR_VIINS": "red",
    "PROMPT_CHAR_ERROR_VICMD": "red",
    "PROMPT_CHAR_ERROR_VIVIS": "red",
    "PROMPT_CHAR_ERROR_VIOWR": "red",
    "RULER": "base01",
    "MULTILINE_FIRST_PROMPT_GAP": "base01",
    # --- contexto / sistema ----------------------------------------------
    "OS_ICON": "base1",
    "CONTEXT": "base0",
    "CONTEXT_REMOTE": "orange",
    "CONTEXT_REMOTE_SUDO": "red",
    "CONTEXT_ROOT": "red",
    "TIME": "base0",
    "RAM": "base0",
    "LOAD_NORMAL": "base0",
    "LOAD_WARNING": "yellow",
    "LOAD_CRITICAL": "red",
    "DISK_USAGE_NORMAL": "green",
    "DISK_USAGE_WARNING": "yellow",
    "DISK_USAGE_CRITICAL": "red",
    "SWAP": "magenta",
    "IP": "cyan",
    "PUBLIC_IP": "cyan",
    "VPN_IP": "cyan",
    "NORDVPN": "cyan",
    "COMMAND_EXECUTION_TIME": "base0",
    "BACKGROUND_JOBS": "green",
    "PACKAGE": "blue",
    "CPU_ARCH": "orange",
    "TOOLBOX": "cyan",
    "BATTERY_CHARGING": "green",
    "BATTERY_CHARGED": "green",
    "BATTERY_DISCONNECTED": "red",
    "BATTERY_LOW": "orange",
    "PER_DIRECTORY_HISTORY_GLOBAL": "base0",
    "PER_DIRECTORY_HISTORY_LOCAL": "base0",
    # --- ferramentas de shell ---------------------------------------------
    "DIRENV": "yellow",
    "RANGER": "yellow",
    "YAZI": "yellow",
    "MIDNIGHT_COMMANDER": "yellow",
    "NNN": "cyan",
    "LF": "cyan",
    "XPLR": "cyan",
    "NIX_SHELL": "cyan",
    "TASKWARRIOR": "cyan",
    "TODO": "yellow",
    "TIMEWARRIOR": "yellow",
    "PROXY": "cyan",
    "WIFI": "cyan",
    "CHEZMOI_SHELL": "blue",
    "VIM_SHELL": "green",
    "EXAMPLE": "base0",
    # --- runtimes / gerenciadores -----------------------------------------
    "ASDF": "base0",
    "ASDF_NODEJS": "green",
    "ASDF_JULIA": "green",
    "ASDF_PYTHON": "magenta",
    "ASDF_GOLANG": "magenta",
    "ASDF_RUST": "magenta",
    "ASDF_RUBY": "magenta",
    "ASDF_ERLANG": "magenta",
    "ASDF_ELIXIR": "magenta",
    "ASDF_PERL": "magenta",
    "ASDF_LUA": "magenta",
    "ASDF_JAVA": "magenta",
    "ASDF_PHP": "magenta",
    "ASDF_HASKELL": "orange",
    "ASDF_DOTNET_CORE": "magenta",
    "ASDF_POSTGRES": "cyan",
    "ASDF_FLUTTER": "cyan",
    "FVM": "cyan",
    "NVM": "green",
    "NODENV": "green",
    "NODEENV": "green",
    "GOENV": "green",
    "PYENV": "magenta",
    "RBENV": "magenta",
    "RVM": "magenta",
    "RUST_VERSION": "magenta",
    "GO_VERSION": "magenta",
    "NODE_VERSION": "magenta",
    "PYTHON_VERSION": "magenta",
    "JAVA_VERSION": "magenta",
    "PHP_VERSION": "magenta",
    "DOTNET_VERSION": "magenta",
    "LUAENV": "magenta",
    "JENV": "magenta",
    "PHPENV": "magenta",
    "PLENV": "magenta",
    "PERLBREW": "magenta",
    "HASKELL_STACK": "magenta",
    "VIRTUALENV": "magenta",
    "ANACONDA": "magenta",
    "SCALAENV": "red",
    "LARAVEL_VERSION": "magenta",
    # --- cloud / k8s ------------------------------------------------------
    "AWS_DEFAULT": "orange",
    "AWS_EB_ENV": "orange",
    "AWS_TEST": "base0",
    "AZURE_OTHER": "orange",
    "AZURE_TEST": "base0",
    "GCLOUD": "orange",
    "GOOGLE_APP_CRED_DEFAULT": "orange",
    "GOOGLE_APP_CRED_TEST": "base0",
    "KUBECONTEXT_DEFAULT": "blue",
    "KUBECONTEXT_TEST": "base0",
    "TERRAFORM_VERSION": "cyan",
    "TERRAFORM_OTHER": "cyan",
    "TERRAFORM_TEST": "base0",
}

# linha com brace expansion: TYPESET-g POWERLEVEL9K_<HEAD>_{A,B}_FOREGROUND=<n>
RE_BRACE = re.compile(
    r"^(?P<indent>\s*typeset -g POWERLEVEL9K_)(?P<head>[A-Z0-9_]*?)"
    r"\{(?P<braces>[A-Z0-9_,]+)\}(?P<tail>_FOREGROUND)=(?P<val>\d+)(?P<trail>\s*)$"
)
# linha simples: typeset -g POWERLEVEL9K_<ROLE>_FOREGROUND=<n>
RE_SIMPLE = re.compile(
    r"^(?P<indent>\s*typeset -g POWERLEVEL9K_)(?P<role>[A-Z0-9_]+?)"
    r"_FOREGROUND=(?P<val>\d+)(?P<trail>\s*)$"
)
# variantes _COLOR= (ex: VCS_VISUAL_IDENTIFIER_COLOR, VCS_LOADING_VISUAL_IDENTIFIER_COLOR)
RE_COLOR = re.compile(
    r"^(?P<indent>\s*typeset -g POWERLEVEL9K_)(?P<role>[A-Z0-9_]+?)"
    r"_COLOR=(?P<val>\d+)(?P<trail>\s*)$"
)
# linha já convertida (idempotência)
RE_DONE = re.compile(r"FOREGROUND=(?P<q>['\"])(?P<hex>#[0-9a-fA-F]{6})(?P=q)")

# --------------------------------------------------------------------------
# Escapes de cor INLINE. Esses NAO passam por POWERLEVEL9K_*_FOREGROUND,
# entao precisam de tratamento separado.
#
# O zsh expande %F{<cor>} (e nao %{<cor>}F). Com indice 256, o p10k usava
# a forma curta %76F; para truecolor a forma correta e %F{#rrggbb}.
#
# Mapeamento semantico por papel no prompt:
#   %76F  -> verde  (git clean)
#   %178F -> amarelo (git modified)
#   %39F  -> azul   (git untracked)
#   %196F -> vermelho (git conflicted)
#   %244F -> base0  (git meta / detached)
#   %240F -> base01 (separadores de subsegmento)
#   %242F -> base01 (prefixos multiline)
#   %70F  -> verde  (rx rate)
#   %215F -> magenta (tx rate)
# --------------------------------------------------------------------------
INLINE_ROLE: dict[int, str] = {
    76: "green",
    178: "yellow",
    39: "blue",
    196: "red",
    244: "base0",
    240: "base01",
    242: "base01",
    70: "green",
    215: "magenta",
}

RE_INLINE = re.compile(r"%(?P<idx>[0-9]{1,3})F")


def convert(text: str, pal: dict[str, str]) -> tuple[str, list[str], int, list[int]]:
    """Retorna (texto, roles_sem_mapeamento, n_linhas_convertidas, idx_inline_sem_mapeamento)."""
    out: list[str] = []
    missing: list[str] = []
    missing_inline: list[int] = []
    count = 0

    for line in text.split("\n"):
        m = RE_BRACE.match(line)
        if m:
            head, braces, tail = m.group("head"), m.group("braces"), m.group("tail")
            names = braces.split(",")
            resolved: list[tuple[str, str]] = []
            for n in names:
                role = head + n
                accent = ROLE_TO_ACCENT.get(role)
                if accent is None:
                    missing.append(role)
                    accent = "base0"
                resolved.append((n, pal[accent]))
            hexes = {h for _, h in resolved}
            if len(hexes) == 1:
                # todas as variantes compartilham a mesma cor -> mantém a brace expansion
                only = resolved[0][1]
                out.append(
                    f"{m.group('indent')}{head}{{{braces}}}{tail}='{only}'{m.group('trail')}"
                )
            else:
                # cores divergem -> expande em linhas individuais
                for n, h in resolved:
                    out.append(
                        f"{m.group('indent')}{head}{n}{tail}='{h}'{m.group('trail')}"
                    )
            count += 1
            continue

        m = RE_SIMPLE.match(line)
        if m:
            role = m.group("role")
            accent = ROLE_TO_ACCENT.get(role)
            if accent is None:
                missing.append(role)
                accent = "base0"
            out.append(
                f"{m.group('indent')}{role}_FOREGROUND='{pal[accent]}'{m.group('trail')}"
            )
            count += 1
            continue

        m = RE_COLOR.match(line)
        if m:
            role = m.group("role")
            accent = ROLE_TO_ACCENT.get(role)
            if accent is None:
                missing.append(role)
                accent = "base0"
            out.append(
                f"{m.group('indent')}{role}_COLOR='{pal[accent]}'{m.group('trail')}"
            )
            count += 1
            continue

        # escapes inline %<num>F -> %F{#rrggbb}
        if RE_INLINE.search(line):
            def _sub(im: "re.Match[str]") -> str:
                idx = int(im.group("idx"))
                accent = INLINE_ROLE.get(idx)
                if accent is None:
                    missing_inline.append(idx)
                    accent = "base0"
                return f"%F{{{pal[accent]}}}"

            out.append(RE_INLINE.sub(_sub, line))
            count += 1
            continue

        out.append(line)

    return "\n".join(out), sorted(set(missing)), count, sorted(set(missing_inline))


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("file", nargs="?", default=str(REPO_ROOT / "configs/zsh/.p10k.zsh"))
    ap.add_argument("--check", action="store_true", help="apenas reporta estado, nao escreve")
    ap.add_argument("--diff", action="store_true", help="mostra o diff em vez de escrever")
    args = ap.parse_args()

    path = Path(args.file)
    original = path.read_text()
    pal = load_palette()
    converted, missing, count, missing_inline = convert(original, pal)

    # idempotência: rodar de novo nao deve mudar nada
    twice, missing2, _, missing_inline2 = convert(converted, pal)
    if twice != converted:
        print("ERRO: conversao nao e idempotente", file=sys.stderr)
        return 2

    already = len(RE_DONE.findall(original))
    # somente linhas ATIVAS contam (comentarios comecam com #)
    active_idx = len(
        [ln for ln in original.split("\n")
         if not ln.lstrip().startswith("#") and re.search(r"FOREGROUND=\d+$", ln)]
    )
    print(f"paleta: {len(pal)} cores do Solarized (fonte: {COLORSCHEME.relative_to(REPO_ROOT)})")
    print(f"linhas com cor numerica: {count} | ja convertidas: {already} | ativas com indice 256: {active_idx}")

    if missing:
        print(f"\nERRO: {len(missing)} roles sem mapeamento semantico:", file=sys.stderr)
        for r in missing:
            print(f"  - {r}", file=sys.stderr)
        return 1

    if missing_inline:
        print(f"\nERRO: {len(missing_inline)} indices inline sem mapeamento:", file=sys.stderr)
        for i in missing_inline:
            print(f"  - %{i}F", file=sys.stderr)
        return 1

    if args.check:
        if converted == original:
            print("OK: ja esta totalmente em truecolor hex")
            return 0
        print(f"pendente: {count} linhas ainda com indice 256")
        return 1

    if args.diff:
        for line in difflib.unified_diff(
            original.split("\n"), converted.split("\n"),
            fromfile=str(path), tofile=f"{path} (solarized)", lineterm="",
        ):
            print(line)
        return 0

    path.write_text(converted)
    print(f"OK: {path} convertido para truecolor hex Solarized")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
