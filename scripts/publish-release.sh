#!/usr/bin/env bash
set -euo pipefail

# Script para publicar release no GitHub
# Pré-requisitos:
#   - gh CLI instalado e autenticado (gh auth login)
#   - git tag criada: git tag vX.Y.Z && git push origin vX.Y.Z

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$REPO_ROOT/dist"
NAME="EFI-X99-CD4"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Funções auxiliares
log_info() {
    # enviar logs para stderr para não poluir capturas de comando
    echo -e "${GREEN}[INFO]${NC} $*" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# Verifica se gh CLI está instalado
if ! command -v gh &> /dev/null; then
    log_error "gh CLI não está instalado. Instale com: brew install gh"
    exit 1
fi

# Verifica se está autenticado
if ! gh auth status &> /dev/null; then
    log_error "gh CLI não está autenticado. Execute: gh auth login"
    exit 1
fi

# Extrai informações da EFI
get_hardware_info() {
    local info_file="$REPO_ROOT/README.md"
    
    # Extrai hardware do README (se existir)
    if [[ -f "$info_file" ]]; then
        log_info "Informações extraídas do README.md"
    fi
    
    # Extrai versão do OpenCore do NVRAM ou VERSION.txt
    local version="unknown"
    if command -v nvram &> /dev/null; then
        # Captura somente o valor final e sanitiza (remove newlines e mensagens de log)
        version=$(nvram 4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:opencore-version 2>/dev/null | tr -d '\r\n' | awk '{print $NF}' || true)
        # remover possíveis mensagens de log que tenham sido escritas em stdout
        version=$(echo "$version" | sed 's/\[INFO\].*//g' | xargs)
    fi
    if [[ -z "$version" || "$version" == *"opencore-version"* ]]; then
        version=$(head -n1 "$REPO_ROOT/VERSION.txt" 2>/dev/null || echo "unknown")
    fi

    # sanitizar versão: manter apenas caracteres seguros para tag (alfa-num, dot, dash)
    version=$(echo "$version" | tr -cd '[:alnum:].-_')
    echo "$version"
}

# Gera body da release
generate_release_body() {
    local version="$1"
    local zip_file="$2"
    local checksum_file="$3"
    local checksum
    local macOSVersion
    
    checksum=$(cat "$checksum_file" 2>/dev/null || echo "N/A")
    macOSVersion=$(sw_vers -productVersion)
    
    cat <<EOF
### Versão do OpenCore
\`$version\`

### Versão do MacOS
\`$macOSVersion\`
EOF
}

# Normaliza a versão do OpenCore para formato semântico (ex: REL-106-2025-11-03 -> 1.0.6)
normalize_version() {
    local v="$1"
    # Se já estiver em formato X.Y ou X.Y.Z, retorna o primeiro match
    if echo "$v" | grep -Eo '[0-9]+\.[0-9]+(\.[0-9]+)?' >/dev/null 2>&1; then
        echo "$(echo "$v" | grep -Eo '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1)"
        return 0
    fi

    # Procurar padrão REL seguido por 3 dígitos (ex: REL-106 ou REL106)
    if [[ "$v" =~ REL[-_]?([0-9]{3}) ]]; then
        local num="${BASH_REMATCH[1]}"
        if [[ ${#num} -eq 3 ]]; then
            echo "${num:0:1}.${num:1:1}.${num:2:1}"
            return 0
        fi
    fi

    # Se for apenas 3 dígitos, converte 106 -> 1.0.6
    if [[ "$v" =~ ^([0-9]{3})$ ]]; then
        local num="${BASH_REMATCH[1]}"
        echo "${num:0:1}.${num:1:1}.${num:2:1}"
        return 0
    fi

    # Fallback: remover caracteres não permitidos e retornar
    echo "$(echo "$v" | tr -cd '[:alnum:].-_')"
}

# Obtém tag mais recente
get_latest_tag() {
    git describe --tags --abbrev=0 2>/dev/null || echo ""
}

# Cria uma tag annotada com a versão detectada se não existir
create_tag_if_missing() {
    local provided_tag="$1"
    if [[ -n "$provided_tag" ]]; then
        log_info "Tag já fornecida: $provided_tag"
        TAG="$provided_tag"
        return 0
    fi

    # tenta derivar uma tag a partir da versão detectada (v1.0.6)
    local version="$OC_VERSION"
    version=$(echo "$version" | xargs || true)
    if [[ -z "$version" || "$version" == "unknown" ]]; then
        log_warn "Não foi possível determinar versão para criar tag"
        return 1
    fi

    # construir candidate tag e sanitizar
    local candidate_tag="${version}"
    candidate_tag=$(echo "$candidate_tag" | tr -cd '[:alnum:].-_')
    # Encontrar tags antigas que contenham REL ou o valor cru (OC_VERSION_RAW)
    old_tags=$(git tag --list | egrep -i "REL|${OC_VERSION_RAW:-}" || true)

    # Se já existir a candidate_tag, usar direto
    if git rev-parse "$candidate_tag" >/dev/null 2>&1; then
        log_info "Tag local $candidate_tag já existe"
        TAG="$candidate_tag"
        return 0
    fi

    # Se houver tags antigas, migrar todas para a candidate_tag (apontando para o commit da primeira encontrada)
    if [[ -n "$old_tags" ]]; then
        # Pegar a primeira tag antiga para obter o commit alvo
        first_old_tag=$(echo "$old_tags" | head -n1)
        log_warn "Tags antigas detectadas: $(echo "$old_tags" | tr '\n' ' ') — migrando para $candidate_tag"
        # Criar nova tag apontando para mesmo commit da antiga
        if git tag -a "$candidate_tag" "$first_old_tag" -m "Release ${candidate_tag} (migrated from ${first_old_tag})"; then
            log_info "Tag $candidate_tag criada a partir de $first_old_tag"
            if git push origin "$candidate_tag"; then
                log_info "Tag $candidate_tag enviada ao remote"
                TAG="$candidate_tag"
                # Remover as tags antigas local e remote (silencioso em falha)
                for t in $(echo "$old_tags"); do
                    git tag -d "$t" >/dev/null 2>&1 || true
                    git push origin :refs/tags/$t >/dev/null 2>&1 || true
                    log_info "Tentativa de remoção da tag antiga $t executada"
                done
                return 0
            else
                log_warn "Falha ao enviar nova tag $candidate_tag para remote; mantendo tags antigas"
            fi
        else
            log_warn "Falha ao criar tag $candidate_tag a partir de $first_old_tag"
        fi
    fi

    # Caso não haja tags antigas, criar a candidate_tag a partir do HEAD
    log_info "Criando tag $candidate_tag no HEAD"
    git tag -a "$candidate_tag" -m "Release ${candidate_tag}"
    if git push origin "$candidate_tag"; then
        log_info "Tag $candidate_tag criada e enviada ao remote"
        TAG="$candidate_tag"
        return 0
    else
        log_error "Falha ao enviar tag $candidate_tag para o remote. Verifique conexão/permissões."
        return 1
    fi

    # Criar tag annotada no HEAD
    log_info "Criando tag $candidate_tag no HEAD"
    git tag -a "$candidate_tag" -m "Release ${candidate_tag}"
    if git push origin "$candidate_tag"; then
        log_info "Tag $candidate_tag criada e enviada ao remote"
        TAG="$candidate_tag"
        return 0
    else
        log_error "Falha ao enviar tag $candidate_tag para o remote. Verifique conexão/permissões."
        return 1
    fi
}

# Garante que a tag local exista no remote (push se necessário)
ensure_tag_pushed() {
    local tag="$1"
    # Verifica no remote
    if git ls-remote --tags origin | awk '{print $2}' | grep -qx "refs/tags/$tag"; then
        log_info "Tag $tag já existe no remote"
        return 0
    fi

    log_info "Tag $tag existe localmente, enviando para origin..."
    if git push origin "$tag"; then
        log_info "Tag $tag enviada para origin"
        return 0
    else
        log_error "Falha ao enviar tag $tag para origin. Verifique permissões/conexão."
        return 1
    fi
}

# Valida ZIP
validate_zip() {
    local zip_file="$1"
    
    if [[ ! -f "$zip_file" ]]; then
        log_error "Arquivo ZIP não encontrado: $zip_file"
        return 1
    fi
    
    # Testa integridade do ZIP
    if ! unzip -t "$zip_file" &>/dev/null; then
        log_error "ZIP corrompido ou inválido: $zip_file"
        return 1
    fi
    
    log_info "ZIP validado com sucesso"
    return 0
}

# Main
main() {
    log_info "Iniciando publicação de release no GitHub..."
    
    # Obtém versão do OpenCore (precisa antes para possivelmente criar tag)
    OC_VERSION_RAW=$(get_hardware_info)
    OC_VERSION=$(normalize_version "$OC_VERSION_RAW")
    log_info "Versão OpenCore: $OC_VERSION (raw: $OC_VERSION_RAW)"

    # Verifica se há tag
    TAG=$(get_latest_tag)
    if [[ -z "$TAG" ]]; then
        log_warn "Nenhuma tag encontrada. Tentando criar uma tag a partir da versão detectada ($OC_VERSION)..."
        if ! create_tag_if_missing ""; then
            log_error "Não foi possível criar tag automaticamente. Crie uma tag manualmente e execute novamente."
            exit 1
        fi
        log_info "Tag criada: $TAG"
    else
        log_info "Tag detectada: $TAG"
    fi
    
    # Garantir que a tag esteja no remote (push se necessário)
    if ! ensure_tag_pushed "$TAG"; then
        log_error "A tag $TAG não está presente no remote e não pôde ser enviada. Abortando."
        exit 1
    fi
    
    # Encontra arquivo ZIP
    ZIP_FILE="$DIST/${NAME}-*.zip"
    ZIP_FOUND=$(find "$DIST" -maxdepth 1 -name "${NAME}-*.zip" ! -name "*latest*" | sort -V | tail -n1)
    
    if [[ -z "$ZIP_FOUND" ]]; then
        log_error "Nenhum arquivo ZIP encontrado em $DIST"
        log_warn "Execute primeiro: bash scripts/release.sh"
        exit 1
    fi
    
    ZIP_FILE="$ZIP_FOUND"
    CHECKSUM_FILE="${ZIP_FILE}.sha256"
    
    log_info "ZIP encontrado: $(basename "$ZIP_FILE")"
    
    # Valida ZIP
    if ! validate_zip "$ZIP_FILE"; then
        exit 1
    fi
    
    # Valida checksum
    if [[ ! -f "$CHECKSUM_FILE" ]]; then
        log_warn "Arquivo checksum não encontrado, gerando..."
        shasum -a 256 "$ZIP_FILE" | awk '{print $1}' > "$CHECKSUM_FILE"
    fi
    
    # Gera body da release
    BODY=$(generate_release_body "$OC_VERSION" "$ZIP_FILE" "$CHECKSUM_FILE")
    
    log_info "Criando release $TAG no GitHub..."
    
    # Verifica se release já existe
    if gh release view "$TAG" &>/dev/null; then
        log_warn "Release $TAG já existe. Atualizando..."
        gh release delete "$TAG" --yes
    fi
    
    # Cria release (usar a versão do OpenCore como título)
    if gh release create "$TAG" \
        --title "$OC_VERSION" \
        --notes "$BODY" \
        "$ZIP_FILE" "$CHECKSUM_FILE"; then
        log_info "Release publicada com sucesso!"
        log_info "URL: $(gh release view "$TAG" --json url -q .url)"
    else
        log_error "Erro ao publicar release"
        exit 1
    fi
}

# Executa main
main "$@"
