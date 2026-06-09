#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-$(pwd)}"
cd "$ROOT_DIR"

MIGRATION="supabase/migrations/20260609150000_puls_core_company_profile_edit.sql"
DOC="docs/product/17_1_d_company_profile_edit.md"
README="docs/product/README.md"
ADAPTER="src/lib/data/setup/company.ts"
ADAPTER_TEST="src/lib/data/setup/company.test.ts"
INDEX="src/lib/data/index.ts"
ROUTE="src/routes/_app/sirket-kurulum.tsx"
TR_LOCALE="src/i18n/locales/tr-TR.json"
EN_LOCALE="src/i18n/locales/en-US.json"

fail() {
  echo "PR17.1D verify failed: $*" >&2
  exit 1
}

require_file() {
  [[ -f "$1" ]] || fail "missing file: $1"
}

require_pattern() {
  local file="$1"
  local pattern="$2"
  grep -Fq "$pattern" "$file" || fail "missing pattern in $file: $pattern"
}

reject_pattern() {
  local file="$1"
  local pattern="$2"
  if grep -Fq "$pattern" "$file"; then
    fail "forbidden pattern in $file: $pattern"
  fi
}

for file in "$MIGRATION" "$DOC" "$README" "$ADAPTER" "$ADAPTER_TEST" "$INDEX" "$ROUTE" "$TR_LOCALE" "$EN_LOCALE"; do
  require_file "$file"
done

require_pattern "$MIGRATION" "update_company_profile"
require_pattern "$MIGRATION" "PULS_COMPANY_PROFILE_FORBIDDEN"
require_pattern "$MIGRATION" "PULS_COMPANY_PROFILE_INVALID_NAME"
require_pattern "$MIGRATION" "PULS_COMPANY_PROFILE_INVALID_INDUSTRY"
require_pattern "$MIGRATION" "PULS_COMPANY_PROFILE_INVALID_LOCALE"
require_pattern "$MIGRATION" "PULS_COMPANY_PROFILE_INVALID_TIMEZONE"
require_pattern "$MIGRATION" "safe_company_profile_audit"
require_pattern "$MIGRATION" "GRANT EXECUTE ON FUNCTION puls_core.update_company_profile(TEXT, TEXT, TEXT, TEXT) TO authenticated, service_role"

reject_pattern "$MIGRATION" "tax_no ="
reject_pattern "$MIGRATION" "plan_name ="
reject_pattern "$MIGRATION" "DELETE FROM puls_core.tenants"
reject_pattern "$MIGRATION" "raw_payload"
reject_pattern "$MIGRATION" "credential_value"
reject_pattern "$MIGRATION" "source writeback"
reject_pattern "$MIGRATION" "provider call"

require_pattern "$ADAPTER" "updateCompanyProfile"
require_pattern "$ADAPTER" "mapCompanyProfileMutationError"
require_pattern "$ADAPTER" "COMPANY_PROFILE_LOCALE_OPTIONS"
require_pattern "$ADAPTER" "COMPANY_PROFILE_TIMEZONE_OPTIONS"
require_pattern "$ADAPTER_TEST" "normalizeCompanyProfileInput"
require_pattern "$ADAPTER_TEST" "isCompanyProfileFormDirty"
require_pattern "$INDEX" "updateCompanyProfile"
require_pattern "$INDEX" "COMPANY_PROFILE_TIMEZONE_OPTIONS"

require_pattern "$ROUTE" "company-profile-form"
require_pattern "$ROUTE" "companySetup.edit.open"
require_pattern "$ROUTE" "updateCompanyProfile"
require_pattern "$ROUTE" "isSetupAdmin"
require_pattern "$ROUTE" "settings-overview"
require_pattern "$ROUTE" "COMPANY_PROFILE_LOCALE_OPTIONS"
require_pattern "$ROUTE" "COMPANY_PROFILE_TIMEZONE_OPTIONS"

require_pattern "$TR_LOCALE" "Şirket bilgileri güncellendi."
require_pattern "$TR_LOCALE" "invalidTimezone"
require_pattern "$EN_LOCALE" "Company information updated."
require_pattern "$EN_LOCALE" "invalidTimezone"

require_pattern "$DOC" "Company Profile Edit"
require_pattern "$DOC" "No tax ID edit"
require_pattern "$README" "PR17.1D Company profile edit"
require_pattern "$README" "17_1_d_company_profile_edit.md"

echo "PR17.1D company profile edit verification passed."
