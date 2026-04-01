function no-ocr --description "Convert PDF to image-based PDF (no selectable text)"
    if test (count $argv) -eq 0
        echo "Usage: no-ocr <input.pdf>"
        return 1
    end

    set input $argv[1]
    if not test -f "$input"
        echo "File not found: $input"
        return 1
    end

    set output (string replace -r '\.pdf$' '_noocr.pdf' $input)
    set tmpdir (mktemp -d)

    echo "Rasterizing pages at 300 DPI..."
    pdftoppm -png -r 300 "$input" "$tmpdir/page"

    echo "Reassembling into $output..."
    img2pdf $tmpdir/page-*.png -o "$output"

    rm -rf "$tmpdir"
    echo "Done → $output"
end
