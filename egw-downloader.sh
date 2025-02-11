#!/bin/bash

# shellcheck disable=SC2034

# ==============================================================================
# REFERENCE:
# https://www.tobias-schwarz.com/en/posts/10/
# https://stackoverflow.com/questions/10238363/how-to-get-wc-l-to-print-just-the-number-of-lines-without-file-name#10239606
# https://www.linuxuprising.com/2019/07/how-to-edit-pdf-metadata-tags-on-linux.html
# https://stackoverflow.com/questions/52668550/pass-variable-as-options-to-curl-in-shell-script-linux#52668615
# https://stackoverflow.com/questions/5142429/unix-how-to-delete-files-listed-in-a-file#21848934
# https://unix.stackexchange.com/questions/385357/cat-files-in-specific-order-based-on-number-in-filename#516714
# https://wkhtmltopdf.org/usage/wkhtmltopdf.txt
# https://exiftool.org/TagNames/PDF.html#Info
# https://legacy.imagemagick.org/Usage/annotating/
#
# https://m.egwwritings.org/en
# https://text.egwwritings.org/allCollection/en
#
# curl -s 'https://ellenwhite.org/search/docs?search_text=&offset=0&limit=2000&filters=%7B%22types%22%3A%7B%22publication%22%3A%7B%22controllers%22%3A%7B%22lang%22%3A%7B%22value%22%3A%5B%22English%22%5D%7D%2C%22type_id%22%3A%7B%22value%22%3A%5B2%2C6%2C15%2C22%5D%7D%7D%7D%7D%2C%22media_types%22%3A%7B%7D%2C%22sort%22%3A%22contentSequence%22%7D&publications_fulltext=false' | jq | grep -Po 'https.*?\.(epub|mobi|pdf|zip)' > dl.list
#
# IDS=; IDS=(13961 14052 14053 14054 14055 14056 14057 14058 14059 14060 14061 14062 14063 14064 14065 14066 14067 14068 14069 14070 14071 14072 14073 14074 14075)
# echo ${#IDS[@]}; echo ${IDS[@]}; for ID in ${IDS[@]}; do egw-downloader "${ID}"; done
# OR:
# IDS=; declare -a IDS="$(curl -s 'https://text.egwwritings.org/allCollection/en/1277' | grep -Po '/b\K[\d]+')"
# echo "${IDS[@]}" | wc -l; echo ${IDS[@]}; for ID in ${IDS[@]}; do egw-downloader "${ID}"; done
#
# ==============================================================================
# TESTS:
# Book title contains a forward slash: https://m.egwwritings.org/en/book/34/info
# Book code contains a forward slash: https://m.egwwritings.org/en/book/1302/info
# Book with no cover: https://m.egwwritings.org/en/book/1290/info
# Book with cover: https://m.egwwritings.org/en/book/14266/info
# Book with PDF: https://m.egwwritings.org/en/book/1613/info
#
# ==============================================================================
# USER SETTINGS:
DEFAULT_OUTPUT_DIRECTORY="${HOME}/Downloads/egw-downloader"
PDF_CREATOR='EGW Downloader - github.com/clove3am/egw-downloader'
PDF_PRODUCER='clove3am'
PING_IP_ADDRESS='1.1.1.1' # IP address to ping to check for internet connection
CURL_OPTS=(--fail --retry 3 --retry-all-errors --retry-delay 10 --silent --user-agent "${UA}" --cookie "")
MAX_SLEEP_TIME=10 # Maximum sleep time in seconds between page downloads
UA='Firefox'      # User-agent string
# ==============================================================================

if [ -t 1 ]; then
  TEXT_RESET='\e[0m'
  TEXT_BOLD='\e[1m'
  TEXT_BLACK='\e[0;30m'
  TEXT_RED='\e[0;31m'
  TEXT_GREEN='\e[0;32m'
  TEXT_GREEN_BOLD='\e[1;32m'
  TEXT_YELLOW='\e[0;33m'
  TEXT_BLUE='\e[0;34m'
  TEXT_PURPLE='\e[0;35m'
  TEXT_PURPLE_BOLD='\e[1;35m'
  TEXT_CYAN='\e[0;36m'
fi

check-input() (
  [[ -n "${1}" ]] ||
    {
      echo -e "${TEXT_BOLD}==> USAGE:${TEXT_RESET} ${0} ${TEXT_BLUE}<book_id>${TEXT_RESET} ${TEXT_BLUE}[output_directory]${TEXT_RESET}"
      false
    }
)
depends() (
  ERR=0
  # shellcheck disable=SC2068
  for DEPENDS in $@; do
    command -v "${DEPENDS}" >/dev/null ||
      {
        echo -e "${TEXT_RED}--> ${DEPENDS} is not installed${TEXT_RESET}"
        ERR=1
      }
  done
  [[ "${ERR}" -eq 0 ]] || false
)
test-ping() (
  ping -q -c 1 "${PING_IP_ADDRESS}" >/dev/null ||
    {
      echo -e "${TEXT_RED}--> No internet connection detected${TEXT_RESET}"
      false
    }
)

check-input "${1}" || exit 1
BOOK_ID="${1}"
depends convert curl exiftool wkhtmltopdf xidel || exit 1
test-ping || exit 1

# ==============================================================================
# Create required directories
TMP="$(mktemp -d)"
OUT_DIR="${2:-"${DEFAULT_OUTPUT_DIRECTORY}"}"
install -d "${OUT_DIR}"

# Get main webpage for book
echo -ne "\n${TEXT_PURPLE_BOLD}==> Downloading book information...${TEXT_RESET}"
curl "${CURL_OPTS[@]}" "https://text.egwwritings.org/book/b${BOOK_ID}" \
  >"${TMP}/online.html" || {
  echo -e "${TEXT_RED}--> Error downloading webpage${TEXT_RESET}"
  exit 1
}
if grep -q 'Page Not Found' "${TMP}/online.html"; then
  echo -e "${TEXT_RED}--> Book ID not found${TEXT_RESET}"
  exit 1
fi
echo -e "${TEXT_GREEN} DONE${TEXT_RESET}"

# Extract and display book information
PAGES="$(grep -Po 'href="/read/\K[\d.]+' "${TMP}/online.html" | uniq)"
TOTAL_PAGES="$(wc -l <<<"${PAGES}")"
echo -e "${TEXT_BOLD}TMP Directory:${TEXT_RESET}     ${TMP}"
echo -e "${TEXT_BOLD}Output Directory:${TEXT_RESET}  ${OUT_DIR}"
echo -e "${TEXT_BOLD}Book URL (Mobile):${TEXT_RESET} https://m.egwwritings.org/en/book/${BOOK_ID}/info"
echo -e "${TEXT_BOLD}Book URL (Text):${TEXT_RESET}   https://text.egwwritings.org/book/b${BOOK_ID}"
PDF_URL="$(xidel -s "${TMP}/online.html" -e '//a[ends-with(@href, ".pdf")]/@href')" # Check if PDF is available to download
if [[ -z "${PDF_URL}" ]]; then PDF_DL='NO'; else PDF_DL="YES (${PDF_URL})"; fi
echo -e "${TEXT_BOLD}PDF Available:${TEXT_RESET}     ${PDF_DL}"
# NB: Download huge image. https://a.egwwritings.org/swagger/index.html?urls.primaryName=Covers%20API
# COVER_URL="$(xidel -s "${TMP}/online.html" -e '/html/head/meta[@property="og:image"]/@content' | sed 's/_s/_k/')" || \
#   { echo -e "${TEXT_RED}--> No book cover available${TEXT_RESET}"; exit 1; }
COVER_URL="https://media1.egwwritings.org/covers/${BOOK_ID}_k.jpg"
echo -e "${TEXT_BOLD}Cover URL:${TEXT_RESET}         ${COVER_URL}"
echo -e "${TEXT_BOLD}Book ID:${TEXT_RESET}           ${BOOK_ID}"
# NB: Some Book codes contain a forward shash. eg; https://m.egwwritings.org/en/book/1302/info
BOOK_CODE="$(grep -Po '>Book code: \K[^<]*' "${TMP}/online.html" | tr '/' '-')" ||
  {
    echo -e "${TEXT_RED}--> No book code available${TEXT_RESET}"
    exit 1
  }
echo -e "${TEXT_BOLD}Book Code:${TEXT_RESET}         ${BOOK_CODE}"
# NB: Some Book titles contain a forward shash. eg; https://m.egwwritings.org/en/book/34/info
TITLE="$(xidel -s "${TMP}/online.html" -e '/html/head/meta[@property="og:title"]/@content' | tr '/' '-')" ||
  {
    echo -e "${TEXT_RED}--> No book title available${TEXT_RESET}"
    exit 1
  }
echo -e "${TEXT_BOLD}Title:${TEXT_RESET}             ${TITLE}"
AUTHOR="$(xidel -s "${TMP}/online.html" -e '/html/head/meta[@property="og:book:author"]/@content' 2>/dev/null)"
echo -e "${TEXT_BOLD}Author:${TEXT_RESET}            ${AUTHOR}"
DESCRIPTION="$(xidel -s "${TMP}/online.html" -e '/html/head/meta[@property="og:description"]/@content' 2>/dev/null)"
echo -e "${TEXT_BOLD}Description:${TEXT_RESET}       ${DESCRIPTION}"
# OUT_NAME="$(echo "${BOOK_CODE} - ${TITLE}.pdf" | tr ' ' '_')"
OUT_NAME="${BOOK_CODE} - ${TITLE}.pdf"

if [[ -z "${PDF_URL}" ]]; then
  # Download book cover
  echo -ne "\n${TEXT_PURPLE_BOLD}==> Downloading book cover...${TEXT_RESET}"
  download-cover() (
    curl "${CURL_OPTS[@]}" "${1}" --output "${TMP}/cover.jpg" ||
      {
        echo -e "${TEXT_RED}--> Error downloading cover${TEXT_RESET}"
        false
      }
  )
  # CHECK_COVER_URL="$(curl "${COVER_URL}" -ILso '/dev/null' -w "%{url_effective}" || \
  #   { echo -e "${TEXT_RED}--> Error checking cover url${TEXT_RESET}"; exit 1; })"
  # if grep -q 'no_cover' <<<"${CHECK_COVER_URL}"; then # Create cover
  COVER_RAW_URL="$(xidel -s "${TMP}/online.html" -e '/html/head/meta[@property="og:image"]/@content')"
  if curl -s "${COVER_RAW_URL}" | grep -q 'Cover not found'; then # Create cover
    # COVER_URL='https://egwwritings-a.akamaihd.net/covers/no_cover_k.jpg'
    COVER_URL='https://media1.egwwritings.org/covers/no_cover_k.jpg'
    download-cover "${COVER_URL}" || exit 1
    COVER_WIDTH=$(($(identify -format %w "${TMP}/cover.jpg") - 20))
    convert -background '#0000' -fill white -gravity center -size ${COVER_WIDTH}x200 -pointsize 30 \
      caption:"${TITLE}" "${TMP}/cover.jpg" +swap -gravity north -composite "${TMP}/cover.jpg"
    convert -background '#0000' -fill white -gravity center -size ${COVER_WIDTH}x200 -pointsize 30 \
      caption:"${AUTHOR}" "${TMP}/cover.jpg" +swap -gravity south -composite "${TMP}/cover.jpg"
  else
    download-cover "${COVER_URL}" || exit 1
  fi
  echo -e "${TEXT_GREEN} DONE${TEXT_RESET}"
  echo '<style>img{max-width: 100%; height: auto;}</style><img src="cover.jpg">' >"${TMP}/cover.html"

  # Download webpages of book
  echo -e "\n${TEXT_PURPLE_BOLD}==> Downloading book webpages...${TEXT_RESET}"
  echo '<style>*{font-family:sans-serif}p{text-align:justify}.egwlink,.refCode{font-style:italic;color:grey}</style>' \
    >"${TMP}/book.html" # Setup pdf formating
  PAGE_NUM=1
  while IFS= read -r PAGE; do
    echo -ne "${TEXT_BLUE}--> Downloading webpage (${PAGE}) ${PAGE_NUM} of ${TOTAL_PAGES} ...${TEXT_RESET}"
    { curl "${CURL_OPTS[@]}" "https://text.egwwritings.org/read/${PAGE}" | xidel -s --html - -e '//*[@id="r-pl"]' >"${TMP}/page-${PAGE_NUM}.html"; } ||
      {
        echo -e "${TEXT_RED}--> Error downloading webpage${TEXT_RESET}"
        exit 1
      }
    sed -i 's/^[ \t]*//' "${TMP}/page-${PAGE_NUM}.html"                                                             # Remove space/tab at beginning of lines to help detect duplicate pages
    echo '<div style="display:block; clear:both; page-break-after:always;"></div>' >>"${TMP}/page-${PAGE_NUM}.html" # Insert page break
    if [[ ${PAGE_NUM} -gt 1 ]]; then                                                                                # Deal with duplicate pages
      if diff -aq "${TMP}/page-$((${PAGE_NUM} - 1)).html" "${TMP}/page-${PAGE_NUM}.html" >/dev/null; then
        echo "${TMP}/page-${PAGE_NUM}.html" >>"${TMP}/remove.list"
        echo -e "${TEXT_CYAN} SKIPPING DUPLICATE${TEXT_RESET}"
      else
        echo -e "${TEXT_GREEN} DONE${TEXT_RESET}"
      fi
    else
      echo -e "${TEXT_GREEN} DONE${TEXT_RESET}"
    fi
    ((PAGE_NUM++))
    sleep $(shuf -i 1-${MAX_SLEEP_TIME} -n 1) # Be nice to server
  done <<<"${PAGES}"
  if [[ -f "${TMP}/remove.list" ]]; then # Delete duplicate pages
    while IFS= read -r FILE_PATH; do rm -- "${FILE_PATH}"; done <"${TMP}/remove.list"
  fi
  ls -v "${TMP}/"page-*.html | xargs cat >>"${TMP}/book.html" # Combine html pages

  # Convert HTML to PDF
  echo -e "\n${TEXT_PURPLE_BOLD}==> Converting HTML to PDF...${TEXT_RESET}"
  wkhtmltopdf --page-size A5 \
    --margin-left 15 --margin-right 15 --margin-top 15 --margin-bottom 15 \
    --enable-local-file-access --encoding 'UTF-8' --outline \
    --footer-center "[page]" --footer-line --footer-spacing 5 \
    --title "${BOOK_CODE} - ${TITLE}" \
    cover "${TMP}/cover.html" \
    toc "${TMP}/book.html" \
    "${OUT_DIR}/${OUT_NAME}"
else
  # Download available PDF
  echo -e "\n${TEXT_PURPLE_BOLD}==> Downloading available PDF...${TEXT_RESET}"
  curl -# --retry 3 --retry-all-errors --retry-delay 10 -fA "${UA}" -b "" "${PDF_URL}" \
    --output "${OUT_DIR}/${OUT_NAME}" ||
    {
      echo -e "${TEXT_RED}--> Error downloading PDF${TEXT_RESET}"
      exit 1
    }
fi

# Add metadata to PDF
echo -e "\n${TEXT_PURPLE_BOLD}==> Adding metadata to PDF...${TEXT_RESET}"
exiftool -overwrite_original -verbose \
  -Title="${BOOK_CODE} (${BOOK_ID}) - ${TITLE}" \
  -Author="${AUTHOR}" \
  -Subject="${DESCRIPTION}" \
  -Creator="${PDF_CREATOR}" \
  -Producer="${PDF_PRODUCER}" \
  "${OUT_DIR}/${OUT_NAME}"
# exiftool -a -G1 "${OUT_DIR}/${OUT_NAME}" # Show PDF metadata

echo -e "\n${TEXT_GREEN_BOLD}==> DONE :)${TEXT_RESET}"
echo -e "${TEXT_BOLD}--> Your book is here:${TEXT_RESET} ${OUT_DIR}/${OUT_NAME}"
