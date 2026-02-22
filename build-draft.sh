#!/usr/bin/env bash
set -euo pipefail

# Build and lint an Internet-Draft from mmark markdown.
# Usage:
#   ./build-draft.sh [draft-md-file]
#
# Defaults to:
#   draft-irtf-cfrg-additive-cryptography-00.md

DRAFT_MD="${1:-draft-irtf-cfrg-additive-cryptography-00.md}"

if [[ ! -f "$DRAFT_MD" ]]; then
  echo "error: markdown draft not found: $DRAFT_MD" >&2
  exit 1
fi

if ! command -v mmark >/dev/null 2>&1; then
  echo "error: mmark is required but not installed" >&2
  exit 1
fi
if ! command -v xml2rfc >/dev/null 2>&1; then
  echo "error: xml2rfc is required but not installed" >&2
  exit 1
fi
if ! command -v idnits >/dev/null 2>&1; then
  echo "error: idnits is required but not installed" >&2
  exit 1
fi

BASE="${DRAFT_MD%.md}"
DRAFT_XML="${BASE}.xml"
DRAFT_TXT="${BASE}.txt"
DRAFT_HTML="${BASE}.html"
DRAFT_PDF="${BASE}.pdf"
DOCS_DIR="docs"
HAVE_PDF=0

DOCNAME="$(basename "$BASE")"

echo "[1/7] Generating XML with mmark"
mmark "$DRAFT_MD" > "$DRAFT_XML"

echo "[2/7] Patching XML metadata for submission compatibility"
# mmark currently emits submissionType="IETF" and may omit docName.
# Patch the root <rfc ...> tag to ensure:
#   submissionType="IRTF"
#   docName="<draft-name>"
perl -i -pe '
  if (!$done && /<rfc version="3"/) {
    s/submissionType="[^"]+"/submissionType="IRTF"/;
    s/<rfc version="3" /<rfc version="3" docName="'"$DOCNAME"'" / unless /docName="/;
    $done = 1;
  }
' "$DRAFT_XML"

echo "[3/7] Rendering TXT with xml2rfc"
xml2rfc --v3 --text "$DRAFT_XML"

echo "[4/7] Rendering HTML with xml2rfc"
xml2rfc --v3 --html "$DRAFT_XML"

echo "[5/7] Rendering PDF with xml2rfc"
if xml2rfc --v3 --pdf "$DRAFT_XML"; then
  HAVE_PDF=1
else
  echo "warning: PDF generation skipped (xml2rfc PDF deps unavailable)." >&2
fi

echo "[6/7] Publishing artifacts to $DOCS_DIR/"
mkdir -p "$DOCS_DIR"
cp "$DRAFT_XML" "$DOCS_DIR/${DOCNAME}.xml"
cp "$DRAFT_TXT" "$DOCS_DIR/${DOCNAME}.txt"
cp "$DRAFT_HTML" "$DOCS_DIR/${DOCNAME}.html"
if [[ "$HAVE_PDF" -eq 1 ]]; then
  cp "$DRAFT_PDF" "$DOCS_DIR/${DOCNAME}.pdf"
fi
cp "$DRAFT_HTML" "$DOCS_DIR/index.html"

echo "[7/7] Running idnits"
# Keep idnits aux files in the repo (ignored via .gitignore).
HOME="$(pwd)" idnits "$DRAFT_TXT"

echo
echo "Build complete:"
echo "  XML: $DRAFT_XML"
echo "  TXT: $DRAFT_TXT"
echo "  HTML: $DRAFT_HTML"
if [[ "$HAVE_PDF" -eq 1 ]]; then
  echo "  PDF: $DRAFT_PDF"
else
  echo "  PDF: (not generated; install xml2rfc PDF dependencies)"
fi
echo "  Pages: $DOCS_DIR/index.html"
