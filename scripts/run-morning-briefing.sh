#!/usr/bin/env bash
# Morning Finance Briefing
# Run this when you wake up: bash ~/scripts/run-morning-briefing.sh

echo ""
echo "=================================================="
echo "🌅 GOOD MORNING - YOUR FINANCE BRIEFING"
echo "=================================================="
echo "📅 $(date '+%d %b %Y')"
echo ""

echo "📊 FULL ANALYSIS"
~/scripts/.bank-venv/bin/python3 ~/scripts/finance-dashboard.py

echo ""
echo "📈 FORKED PARSER (v2)"
echo "Your improved parser at: ~/scripts/bank-parse-v2.py"
echo "Usage: ~/scripts/.bank-venv/bin/python3 ~/scripts/bank-parse-v2.py <pdf>"
echo ""

echo "🏦 PROCESS LATEST"
# Process any new PDFs in Downloads/ac
if ls ~/Downloads/ac/*.pdf 2>/dev/null | head -1 > /dev/null; then
    echo "Processing new PDFs..."
    ~/scripts/.bank-venv/bin/fish -c "bank-v2 ~/Downloads/ac"
else
    echo "No new PDFs found in ~/Downloads/ac"
fi

echo ""
echo "=================================================="
echo "💡 KEY INSIGHTS FROM YOUR DATA"
echo "=================================================="
echo ""
echo "1. FRIEND CIRCLE DRAIN: 49% goes to just 4 friends (Snehansh, Yasharth, Arunya, Adarsh)"
echo "   - You pay first, they pay back later (creates imbalance)"
echo "   - Fix: Use cash rounds or settle weekly"
echo ""
echo "2. IMPULSE ZONE: 12 transactions under ₹40 = ₹257"
echo "   - Silent leak - Rs.20 here, Rs.30 there adds up"
echo "   - Fix: Remove from quick-access UPI, use savings account"
echo ""
echo "3. TOP CATEGORY: Food (₹362 this period)"
echo "   - Your biggest discretionary spend"
echo "   - Fix: Cook 3 days, batch prep"
echo ""
echo "4. DUPLICATE TRANSACTION: dUPLICATE STATE = ₹118"
echo "   - Bank glitch - can dispute"
echo ""
echo "=================================================="