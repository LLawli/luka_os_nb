# luka_os_nb shell config
# Only load for interactive shells
case $- in
  *i*) ;;
  *) return 0 2>/dev/null || exit 0 ;;
esac

# ── zoxide: powers the cd command ────────────────────────────────────────────
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init bash --cmd cd)"
fi

# ── eza: powers ls ───────────────────────────────────────────────────────────
if command -v eza >/dev/null 2>&1; then
  unalias ls ll la 2>/dev/null
  alias ls='eza --group-directories-first'
  alias ll='eza -lh --group-directories-first --git'
  alias la='eza -lah --group-directories-first --git'
  alias lt='eza --tree'
  alias lta='eza --tree -a --ignore-glob=".git"'
fi

# ── fd: short alias ──────────────────────────────────────────────────────────
if command -v fd >/dev/null 2>&1; then
  alias f='fd'
fi

# ── cdf: cd + fzf fuzzy jump ─────────────────────────────────────────────────
if command -v fzf >/dev/null 2>&1 && command -v zoxide >/dev/null 2>&1; then
  cdf() {
    local dir
    dir="$(zoxide query -l | fzf --height 40% --reverse --border --prompt='jump > ')" || return
    [ -n "$dir" ] && cd "$dir"
  }
fi

# ── extract: descompacta qualquer formato ────────────────────────────────────
extract() {
  if [ -z "${1:-}" ]; then
    echo "usage: extract <arquivo>"
    return 1
  fi
  if ! [ -f "$1" ]; then
    echo "extract: '$1' não é um arquivo"
    return 1
  fi

  # ouch abstrai tudo — usa se disponível
  if command -v ouch >/dev/null 2>&1; then
    ouch decompress "$1"
    return
  fi

  # fallback por extensão
  case "$1" in
    *.tar.gz|*.tgz)   tar xzf "$1"  ;;
    *.tar.xz)         tar xJf "$1"  ;;
    *.tar.bz2)        tar xjf "$1"  ;;
    *.tar.zst)        tar --zstd -xf "$1" ;;
    *.tar)            tar xf  "$1"  ;;
    *.gz)             gunzip  "$1"  ;;
    *.xz)             unxz    "$1"  ;;
    *.bz2)            bunzip2 "$1"  ;;
    *.zst)            zstd -d "$1"  ;;
    *.zip)            unzip   "$1"  ;;
    *.7z)             7z x    "$1"  ;;
    *.rar)            unrar x "$1"  ;;
    *)
      echo "extract: formato não reconhecido: $1"
      return 1
      ;;
  esac
}
