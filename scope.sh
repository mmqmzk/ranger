#!/usr/bin/env bash

set -o noclobber -o noglob -o nounset -o pipefail
IFS=$'\n'

## If the option `use_preview_script` is set to `true`,
## then this script will be called and its output will be displayed in ranger.
## ANSI color codes are supported.
## STDIN is disabled, so interactive scripts won't work properly

## This script is considered a configuration file and must be updated manually.
## It will be left untouched if you upgrade ranger.

## Because of some automated testing we do on the script #'s for comments need
## to be doubled up. Code that is commented out, because it's an alternative for
## example, gets only one #.

## Meanings of exit codes:
## code | meaning    | action of ranger
## -----+------------+-------------------------------------------
## 0    | success    | Display stdout as preview
## 1    | no preview | Display no preview at all
## 2    | plain text | Display the plain content of the file
## 3    | fix width  | Don't reload when width changes
## 4    | fix height | Don't reload when height changes
## 5    | fix both   | Don't ever reload
## 6    | image      | Display the image `$IMAGE_CACHE_PATH` points to as an image preview
## 7    | image      | Display the file directly as an image

## Script arguments
FILE_PATH="${1}"         # Full path of the highlighted file
PV_WIDTH="${2}"          # Width of the preview pane (number of fitting characters)
## shellcheck disable=SC2034 # PV_HEIGHT is provided for convenience and unused
# PV_HEIGHT="${3}"       # Height of the preview pane (number of fitting characters)
IMAGE_CACHE_PATH="${4}"  # Full path that should be used to cache image preview
PV_IMAGE_ENABLED="${5}"  # 'True' if image previews are enabled, 'False' otherwise.

FILE_EXTENSION="${FILE_PATH##*.}"
FILE_EXTENSION_LOWER="$(printf "%s" "${FILE_EXTENSION}" | tr '[:upper:]' '[:lower:]')"

## Settings
HIGHLIGHT_SIZE_MAX=524288
HIGHLIGHT_TABWIDTH=${HIGHLIGHT_TABWIDTH:-4}
HIGHLIGHT_STYLE=${HIGHLIGHT_STYLE:-pablo}
if [[ "$( tput colors )" -ge 256 ]]; then
  PYGMENTIZE_FORMAT='terminal256'
  HIGHLIGHT_FORMAT='xterm256'
else
  PYGMENTIZE_FORMAT='terminal'
  HIGHLIGHT_FORMAT='ansi'
fi
HIGHLIGHT_OPTIONS=("--replace-tabs=${HIGHLIGHT_TABWIDTH}" \
  "--style=${HIGHLIGHT_STYLE}" "--out-format=${HIGHLIGHT_FORMAT}" "--force")


PYGMENTIZE_STYLE=${PYGMENTIZE_STYLE:-monokai}
PYGMENTIZE_OPTIONS=("-f" "${PYGMENTIZE_FORMAT}" "-O" "style=${PYGMENTIZE_STYLE}")

# OPENSCAD_IMGSIZE=${RNGR_OPENSCAD_IMGSIZE:-1000,1000}
# OPENSCAD_COLORSCHEME=${RNGR_OPENSCAD_COLORSCHEME:-Tomorrow Night}

view_image() {
  convert "${FILE_PATH}" "${IMAGE_CACHE_PATH}" && img2txt --gamma=0.6 --width="${PV_WIDTH}" -- "${IMAGE_CACHE_PATH}" && exit 4
}

view_icon() {
  convert "${FILE_PATH}[0]" "${IMAGE_CACHE_PATH}" && img2txt --gamma=0.6 --width="${PV_WIDTH}" -- "${IMAGE_CACHE_PATH}" && exit 5
  convert "${FILE_PATH}" "${IMAGE_CACHE_PATH}" && img2txt --gamma=0.6 --width="${PV_WIDTH}" -- "${IMAGE_CACHE_PATH}" && exit 5
}

view_sqlite3() {
  sqlite3 "${FILE_PATH}" "SELECT name FROM sqlite_master WHERE type='table';" \
    | xargs -n1 -I{} bash -c 'echo "{}:";sqlite3 '"${FILE_PATH}" \
    ' -header -column "SELECT * FROM {} limit 10;";echo ""' && exit 5
}

view_docx() {
  pandoc -f docx -t plain "${FILE_PATH}" && exit 5
}

view_doc() {
  catdoc -a "${FILE_PATH}" && exit 5
}

view_tsv() {
  tabulate -f tsv "${FILE_PATH}" && exit 5
}

view_csv() {
  sed 's/,/\t/g' "${FILE_PATH}" | tabulate -f tsv  && exit 5
}

view_xlsx() {
  xlsx2csv -a -d "\t" "${FILE_PATH}" | tabulate -f tsv  && exit 5
}

view_xls() {
  xls2csv "${FILE_PATH}" | tabulate -f tsv  && exit 5
}

view_class() {
  javap "${FILE_PATH}" && exit 2
  runexe javap.exe "${FILE_PATH}" && exit 2
}

handle_extension() {
  case "${FILE_EXTENSION_LOWER}" in
    ## Archive
    a|ace|alz|arc|arj|bz|bz2|cab|cpio|deb|gz|jar|lha|lz|lzh|lzma|lzo|\
    rpm|rz|t7z|tar|tbz|tbz2|tgz|tlz|txz|tZ|tzo|war|xpi|xz|Z|zip)
      atool --list -- "${FILE_PATH}" && exit 5
      bsdtar --list --file "${FILE_PATH}" && exit 5
      exit 1;;
    rar)
      ## Avoid password prompt by providing empty password
      unrar lt -p- -- "${FILE_PATH}" && exit 5
      exit 1;;
    7z|apk|msi|iso)
      ## Avoid password prompt by providing empty password
      7z l -p -- "${FILE_PATH}" && exit 5
      exit 1;;

    ## PDF
    pdf)
      ## Preview as text conversion
      pdftotext -l 10 -nopgbrk -q -- "${FILE_PATH}" - | \
        fmt -w "${PV_WIDTH}" && exit 5
      mutool draw -F txt -i -- "${FILE_PATH}" 1-10 | \
        fmt -w "${PV_WIDTH}" && exit 5
      exiftool "${FILE_PATH}" && exit 5
      exit 1;;

    ## BitTorrent
    torrent)
      transmission-show -- "${FILE_PATH}" && exit 5
      exit 1;;

    ## OpenDocument
    odt|ods|odp|sxw)
      ## Preview as text conversion
      odt2txt "${FILE_PATH}" && exit 5
      ## Preview as markdown conversion
      pandoc -s -t markdown -- "${FILE_PATH}" && exit 5
      exit 1;;

    ## HTML
    htm|html|xhtml)
      ## Preview as text conversion
      elinks -dump -dump-color-mode 1 "${FILE_PATH}" && exit 5
      w3m -dump "${FILE_PATH}" && exit 5
      lynx -dump -- "${FILE_PATH}" && exit 5
      pandoc -s -t markdown -- "${FILE_PATH}" && exit 5
      ;;
    md|markdown)
      # mdv -c "$PV_WIDTH" "${FILE_PATH}" && exit 5
      pandoc -t html "${FILE_PATH}" | elinks -dump -dump-color-mode 1 -force-html && exit 5
      ;;
    epub|tex|org)
      pandoc -t plain "${FILE_PATH}" && exit 5
      ;;
    db|sqlite|db-wal|sqlite-wal|db-shm|sqlite-shm)
      view_sqlite3
      exit 1;;
    doc|dot|rtf)
      view_doc
      exit 1;;
    docx|dotx)
      view_docx
      exit 1;;
    xls|xlt|xla)
      view_xls
      exit 1;;
    xlsx)
      view_xlsx
      exit 1;;
    csv)
      view_csv
      ;;
    tsv)
      view_tsv
      ;;
    class)
      view_class 2> /dev/null
      exit 1;;
    ini|properties|cnf)
      check_highlight_size
      highlight -S ini "${HIGHLIGHT_OPTIONS[@]}" -- "${FILE_PATH}" 2>/dev/null && exit 5
      pygmentize -l ini "${PYGMENTIZE_OPTIONS[@]}" -- "${FILE_PATH}" 2>/dev/null && exit 5
      ;;
    dff|dsf|wv|wvc)
      mediainfo "${FILE_PATH}" && exit 5
      exiftool "${FILE_PATH}" && exit 5
      ;; # Continue with next handler on failure
  esac

  case "$(basename "$FILE_PATH")" in
    *bashrc|*zshrc|*profile|*bash_logout|*zlogout|\
      *bash_login|*zlogin|.bash_history|.zsh_history)
      check_highlight_size
      highlight -S bash "${HIGHLIGHT_OPTIONS[@]}" -- "${FILE_PATH}" 2>/dev/null && exit 5
      pygmentize -l bash "${PYGMENTIZE_OPTIONS[@]}" -- "${FILE_PATH}" 2>/dev/null && exit 5
      ;;
    vimrc|.vimrc|.viminfo)
      check_highlight_size
      highlight -S vim "${HIGHLIGHT_OPTIONS[@]}" -- "${FILE_PATH}" 2>/dev/null && exit 5
      pygmentize -l vim "${PYGMENTIZE_OPTIONS[@]}" -- "${FILE_PATH}" 2>/dev/null && exit 5
      ;;
  esac
}

handle_image() {
  ## Size of the preview if there are multiple options or it has to be
  ## rendered from vector graphics. If the conversion program allows
  ## specifying only one dimension while keeping the aspect ratio, the width
  ## will be used.
  # local DEFAULT_SIZE="1920x1080"

  local mimetype="${1}"
  case "${mimetype}" in
    ## SVG
    # image/svg+xml|image/svg)
    #  convert -- "${FILE_PATH}" "${IMAGE_CACHE_PATH}" && exit 6
    #     exit 1;;

    ## DjVu
    # image/vnd.djvu)
    #   ddjvu -format=tiff -quality=90 -page=1 -size="${DEFAULT_SIZE}" \
    #     - "${IMAGE_CACHE_PATH}" < "${FILE_PATH}" \
    #     && exit 6 || exit 1;;

    ## Image
    image/*)
      local orientation
      orientation="$( identify -format '%[EXIF:Orientation]\n' -- "${FILE_PATH}" )"
      ## If orientation data is present and the image actually
      ## needs rotating ("1" means no rotation)...
      if [[ -n "$orientation" && "$orientation" != 1 ]]; then
        ## ...auto-rotate the image according to the EXIF data.
        convert -- "${FILE_PATH}" -auto-orient "${IMAGE_CACHE_PATH}" && exit 6
      fi

      ## `w3mimgdisplay` will be called for all images (unless overriden
      ## as above), but might fail for unsupported types.
      exit 7;;

      ## Video
      # video/*)
      #   # Thumbnail
      #   ffmpegthumbnailer -i "${FILE_PATH}" -o "${IMAGE_CACHE_PATH}" -s 0 && exit 6
      #   exit 1;;

    ## PDF
    # application/pdf)
    #   pdftoppm -f 1 -l 1 \
    #      -scale-to-x "${DEFAULT_SIZE%x*}" \
    #      -scale-to-y -1 \
    #      -singlefile \
    #      -jpeg -tiffcompression jpeg \
    #      -- "${FILE_PATH}" "${IMAGE_CACHE_PATH%.*}" \
    #     && exit 6 || exit 1;;


    ## ePub, MOBI, FB2 (using Calibre)
    # application/epub+zip|application/x-mobipocket-ebook|\
    # application/x-fictionbook+xml)
    #   # ePub (using https://github.com/marianosimone/epub-thumbnailer)
    #   epub-thumbnailer "${FILE_PATH}" "${IMAGE_CACHE_PATH}" \
    #     "${DEFAULT_SIZE%x*}" && exit 6
    #   ebook-meta --get-cover="${IMAGE_CACHE_PATH}" -- "${FILE_PATH}" \
    #     >/dev/null && exit 6
    #   exit 1;;

    ## Font
    application/font*|application/*opentype)
      preview_png="/tmp/$(basename "${IMAGE_CACHE_PATH%.*}").png"
      if fontimage -o "${preview_png}" \
        --pixelsize "120" \
        --fontname \
        --pixelsize "80" \
        --text "  ABCDEFGHIJKLMNOPQRSTUVWXYZ  " \
        --text "  abcdefghijklmnopqrstuvwxyz  " \
        --text "  0123456789.:,;(*!?') ff fl fi ffi ffl  " \
        --text "  The quick brown fox jumps over the lazy dog.  " \
        "${FILE_PATH}";
      then
        convert -- "${preview_png}" "${IMAGE_CACHE_PATH}" \
          && rm "${preview_png}" \
          && exit 6
      else
        exit 1
      fi
      ;;

    ## Preview archives using the first image inside.
    ## (Very useful for comic book collections for example.)
    # application/zip|application/x-rar|application/x-7z-compressed|\
    #   application/x-xz|application/x-bzip2|application/x-gzip|application/x-tar)
    #   local fn=""; local fe=""
    #   local zip=""; local rar=""; local tar=""; local bsd=""
    #   case "${mimetype}" in
    #     application/zip) zip=1 ;;
    #     application/x-rar) rar=1 ;;
    #     application/x-7z-compressed) ;;
    #     *) tar=1 ;;
    #   esac
    #   { [ "$tar" ] && fn=$(tar --list --file "${FILE_PATH}"); } || \
    #   { fn=$(bsdtar --list --file "${FILE_PATH}") && bsd=1 && tar=""; } || \
    #   { [ "$rar" ] && fn=$(unrar lb -p- -- "${FILE_PATH}"); } || \
    #   { [ "$zip" ] && fn=$(zipinfo -1 -- "${FILE_PATH}"); } || return
    #
    #   fn=$(echo "$fn" | python -c "import sys; import mimetypes as m; \
    #     [ print(l, end='') for l in sys.stdin if \
    #       (m.guess_type(l[:-1])[0] or '').startswith('image/') ]" |\
    #     sort -V | head -n 1)
    #   [ "$fn" = "" ] && return
    #   [ "$bsd" ] && fn=$(printf '%b' "$fn")
    #
    #   [ "$tar" ] && tar --extract --to-stdout \
    #     --file "${FILE_PATH}" -- "$fn" > "${IMAGE_CACHE_PATH}" && exit 6
    #   fe=$(echo -n "$fn" | sed 's/[][*?\]/\\\0/g')
    #   [ "$bsd" ] && bsdtar --extract --to-stdout \
    #     --file "${FILE_PATH}" -- "$fe" > "${IMAGE_CACHE_PATH}" && exit 6
    #   [ "$bsd" ] || [ "$tar" ] && rm -- "${IMAGE_CACHE_PATH}"
    #   [ "$rar" ] && unrar p -p- -inul -- "${FILE_PATH}" "$fn" > \
    #     "${IMAGE_CACHE_PATH}" && exit 6
    #   [ "$zip" ] && unzip -pP "" -- "${FILE_PATH}" "$fe" > \
    #     "${IMAGE_CACHE_PATH}" && exit 6
    #   [ "$rar" ] || [ "$zip" ] && rm -- "${IMAGE_CACHE_PATH}"
    #   ;;
  esac

  # openscad_image() {
  #   TMPPNG="$(mktemp -t XXXXXX.png)"
  #   openscad --colorscheme="${OPENSCAD_COLORSCHEME}" \
  #     --imgsize="${OPENSCAD_IMGSIZE/x/,}" \
  #     -o "${TMPPNG}" "${1}"
  #   mv "${TMPPNG}" "${IMAGE_CACHE_PATH}"
  # }

  # case "${FILE_EXTENSION_LOWER}" in
  # ## 3D models
  # ## OpenSCAD only supports png image output, and ${IMAGE_CACHE_PATH}
  # ## is hardcoded as jpeg. So we make a tempfile.png and just
  # ## move/rename it to jpg. This works because image libraries are
  # ## smart enough to handle it.
  # csg|scad)
  #   openscad_image "${FILE_PATH}" && exit 6
  #   ;;
  # 3mf|amf|dxf|off|stl)
  #   openscad_image <(echo "import(\"${FILE_PATH}\");") && exit 6
  #   ;;
  # esac
}

check_highlight_size() {
  if [[ "$( stat --printf='%s' -- "${FILE_PATH}" )" -gt "${HIGHLIGHT_SIZE_MAX}" ]]; then
    exit 2
  fi
}

handle_mime() {
  local mimetype="${1}"
  case "${mimetype}" in
    ## Text
    text/html|application/xhtml+xml)
      elinks -dump -dump-color-mode 1 -force-html "${FILE_PATH}" && exit 5
      w3m -dump -T "${mimetype}" "${FILE_PATH}" && exit 5
      lynx -dump -- "${FILE_PATH}" && exit 5
      exit 2;;
    */xml)
      check_highlight_size
      highlight -S xml "${HIGHLIGHT_OPTIONS[@]}" -- "${FILE_PATH}" 2>/dev/null && exit 5
      pygmentize -l xml "${PYGMENTIZE_OPTIONS[@]}" -- "${FILE_PATH}" 2>/dev/null && exit 5
      exit 2;;
    text/*|application/x-wine-extension-ini)
      check_highlight_size
      highlight "${HIGHLIGHT_OPTIONS[@]}" -- "${FILE_PATH}" 2>/dev/null && exit 5
      pygmentize "${PYGMENTIZE_OPTIONS[@]}" -- "${FILE_PATH}" 2>/dev/null && exit 5
      exit 2;;

    ## Image
    image/webp|image/svg+xml|image/svg)
      view_image
      exit 1;;
    image/vnd.microsoft.icon|image/x-icon)
      view_icon
      exit 1;;
    image/*)
      ## Preview as text conversion
      img2txt --gamma=0.6 --width="${PV_WIDTH}" -- "${FILE_PATH}" && exit 4
      exiftool "${FILE_PATH}" && exit 2
      exit 1;;

    ## Video and audio
    video/*|audio/*)
      mediainfo "${FILE_PATH}" && exit 5
      exiftool "${FILE_PATH}" && exit 5
      exit 1;;

    application/x-sqlite3)
      view_sqlite3
      exit 1;;
    application/json)
      highlight -S json "${HIGHLIGHT_OPTIONS[@]}" -- "${FILE_PATH}" 2>/dev/null && exit 5
      pygmentize -l json "${PYGMENTIZE_OPTIONS[@]}" -- "${FILE_PATH}" 2>/dev/null && exit 5
      exit 1;;
    application/msword)
      view_doc
      exit 1;;
    application/vnd.openxmlformats-officedocument.wordprocessingml.document|\
      application/vnd.openxmlformats-officedocument.wordprocessingml.template)
      view_docx
      exit 1;;
    application/vnd.ms-excel)
      view_xls
      exit 1;;
    application/vnd.openxmlformats-officedocument.spreadsheetml.sheet)
      view_xlsx
      exit 1;;
    application/x-archive|\
      application/zip|\
      application/gzip|\
      application/x-xz|\
      application/x-bzip2|\
      application/x-gzip|\
      application/x-tar)
      atool --list -- "${FILE_PATH}" && exit 5;
      exit 1;;
    application/x-rar)
      unrar lt -p- -- "${FILE_PATH}" && exit 5
      exit 1;;
    application/x-7z-compressed|\
      application/java-archive|\
      application/x-msi|\
      application/x-iso9660-image)
      7z l -- "${FILE_PATH}" && exit 5
      exit 1;;
    application/x-java-applet)
      view_class 2> /dev/null && exit 5
      exit 1;;
  esac
}

handle_fallback() {
  echo '----- File Type Classification -----' && file --dereference --brief -- "${FILE_PATH}" && exit 5
  exit 1
}


MIMETYPE="$( file --dereference --brief --mime-type -- "${FILE_PATH}" )"
if [[ "${PV_IMAGE_ENABLED}" == 'True' ]]; then
  handle_image "${MIMETYPE}"
fi
handle_extension
handle_mime "${MIMETYPE}"
handle_fallback

exit 1
