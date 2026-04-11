function bank-v2 --description "Parse bank statements with behavioural insights (v2)"
    set -l dir $argv[1]
    if test -z "$dir"
        set dir .
    end

    set -l vault "/mnt/windows/Users/DELL/Dropbox/DropsyncFiles/lesser amygdala"
    set -l password "PRATI17032006"
    set -l script ~/scripts/bank-parse-v2.py
    set -l python ~/scripts/.bank-venv/bin/python3
    set -l count 0

    if not test -d "$dir"
        echo "❌ Not a directory: $dir"
        return 1
    end

    # Sort PDFs by modification time (newest first)
    for pdf in (ls -t $dir/*.pdf 2>/dev/null)
        if not test -f "$pdf"
            continue
        end

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
        echo ""
        echo "💡 New in v2:"
        echo "   • Entity name resolution"
        echo "   • Category breakdown"  
        echo "   • Behavioural insights"
        echo "   • Impulse spend tracking"
    end
end