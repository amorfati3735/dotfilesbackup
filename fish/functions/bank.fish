function bank --description "Parse bank statement PDFs into Obsidian markdown"
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
        set -l basename (basename "$pdf" .pdf)
        set -l outfile "$vault/$basename.md"

        echo "📄 Processing: $pdf"

        # Try with password first, then without
        $python "$script" "$pdf" "$password" > "$outfile" 2>/dev/null
        if test ! -s "$outfile"
            $python "$script" "$pdf" > "$outfile" 2>/dev/null
        end

        if test ! -s "$outfile"
            rm -f "$outfile"
            echo "   ⚠️  No transactions found, skipping"
            continue
        end
        set count (math $count + 1)
        echo "   ✅ → $outfile"
    end

    if test $count -eq 0
        echo "No PDFs found in $dir"
    else
        echo ""
        echo "🏦 Done! $count statement(s) → vault"
    end
end
