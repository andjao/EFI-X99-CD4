#!/usr/bin/env bash
set -euo pipefail

# Script para criar um ZIP de release contendo as pastas EFI e USBMaps
# Gera arquivo em dist/ com timestamp, cria checksum SHA256 e um link 'latest'

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$REPO_ROOT/dist"
NAME="EFI-X99-CD4"

# Extrai número de versão de strings como "REL-106-2025-11-03" -> "1.0.6"
extract_version_number() {
	local v="$1"
	# Se contém "REL-", extrai o número após REL- (ex: REL-106 -> 1.0.6)
	if [[ "$v" =~ REL-([0-9]+) ]]; then
		local num="${BASH_REMATCH[1]}"
		# Converte: 106 -> 1.0.6
		echo "$num" | sed 's/\([0-9]\)\([0-9]\)\([0-9]\)/\1.\2.\3/'
		return 0
	fi
	# Caso contrário, retorna como está
	echo "$v"
}

# Tenta extrair a versão do OpenCore
get_oc_version() {
	# 1) Variável de ambiente OC_VERSION (maior prioridade)
	if [[ -n "${OC_VERSION-}" ]]; then
		echo "$OC_VERSION"
		return 0
	fi

	# 2) NVRAM (sistema macOS/Linux com EFI) - mais confiável
	if command -v nvram &> /dev/null; then
		local v
		v=$(nvram 4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:opencore-version 2>/dev/null | awk '{print $NF}') || true
		if [[ -n "$v" && "$v" != "4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:opencore-version" ]]; then
			v=$(extract_version_number "$v")
			echo "$v"
			return 0
		fi
	fi

	# 3) Arquivo VERSION.txt na raiz do repo
	local version_file="$REPO_ROOT/VERSION.txt"
	if [[ -f "$version_file" ]]; then
		local v
		v=$(head -n1 "$version_file" | xargs) || true
		if [[ -n "$v" ]]; then
			echo "$v"
			return 0
		fi
	fi

	# 4) Fallback: unknown
	echo "unknown"
}

VERSION=$(get_oc_version)
OUT="$DIST/${NAME}-${VERSION}.zip"
CHECKSUM_FILE="$OUT.sha256"

mkdir -p "$DIST"

echo "Criando release ZIP: $OUT"

pushd "$REPO_ROOT" >/dev/null

# Incluir apenas as pastas EFI e USBMaps. Excluir .git, dist e .DS_Store
zip -r "$OUT" EFI USBMaps -x "*/.git/*" "dist/*" "*.DS_Store" >/dev/null

popd >/dev/null

echo "Gerando checksum SHA256 em: $CHECKSUM_FILE"
shasum -a 256 "$OUT" | awk '{print $1}' > "$CHECKSUM_FILE"

echo "Release criada com sucesso: $OUT"
echo "Checksum: $(cat "$CHECKSUM_FILE")"

exit 0
