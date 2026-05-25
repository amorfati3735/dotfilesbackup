function bank --description "Parse bank statement PDFs into Obsidian markdown (and decrypt the PDFs in place)"
    set -l dir $argv[1]
    if test -z "$dir"
        set dir .
    end

    set -l vault "/mnt/windows/Users/DELL/Dropbox/DropsyncFiles/lesser amygdala"
    set -l password "PRATI17032006"
    set -l python ~/scripts/.bank-venv/bin/python3
    set -l script ~/scripts/bank-parse.py
    set -l count 0

    if not test -d "$dir"
        echo "❌ Not a directory: $dir"
        return 1
    end

    # Process GPay statements first (to build entity dictionary),
    # then SBI statements (which use the dictionary to resolve names)
    set -l gpay_pdfs
    set -l other_pdfs
    for pdf in $dir/*.pdf
        if not test -f "$pdf"
            continue
        end
        if string match -qi "*gpay*" (basename "$pdf")
            set -a gpay_pdfs "$pdf"
        else
            set -a other_pdfs "$pdf"
        end
    end

    for pdf in $gpay_pdfs $other_pdfs
        echo "📄 Processing: $pdf"

        set -l tmp_out (mktemp --suffix=.md)
        set -l tmp_err (mktemp)

        # Try with password first, then without
        $python "$script" "$pdf" "$password" > "$tmp_out" 2>"$tmp_err"
        if test ! -s "$tmp_out"
            $python "$script" "$pdf" > "$tmp_out" 2>"$tmp_err"
        end

        if test ! -s "$tmp_out"
            rm -f "$tmp_out" "$tmp_err"
            echo "   ⚠️  No transactions found, skipping"
            continue
        end

        # Extract suggested filename from stderr (e.g. "FILENAME:apr spend")
        set -l fname (grep '^FILENAME:' "$tmp_err" | string replace -r '^FILENAME:' '')
        if test -z "$fname"
            set fname (basename "$pdf" .pdf)
        end

        set -l outfile "$vault/$fname.md"
        mv "$tmp_out" "$outfile"
        rm -f "$tmp_err"

        echo "   ✅ → $outfile"

        # Decrypt the source PDF in place (strip the password)
        $python -c "
import sys
from pypdf import PdfReader, PdfWriter
path, pw = sys.argv[1], sys.argv[2]
r = PdfReader(path)
if r.is_encrypted:
    if r.decrypt(pw) == 0:
        sys.exit(0)  # wrong password; leave as is
    w = PdfWriter()
    for p in r.pages:
        w.add_page(p)
    with open(path, 'wb') as f:
        w.write(f)
    print('   🔓 password removed', file=sys.stderr)
" "$pdf" "$password" 2>&1 | grep -v '^$'

        set count (math $count + 1)
    end

    if test $count -eq 0
        echo "No PDFs found in $dir"
    else
        echo ""
        echo "🏦 Done! $count statement(s) → vault"
    end
end
