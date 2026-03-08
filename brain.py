import os
import math
import pandas as pd
from datetime import datetime, timedelta
from supabase import create_client
import pytz

# --- 1. CONNECTION ---
SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_KEY = os.environ.get("SUPABASE_KEY")

if not SUPABASE_URL or not SUPABASE_KEY:
    print("❌ Connection Error: Keys missing.")
    exit(1)

supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

# --- CONFIGURATION ---
PERIODS = {
    "return_1d": 1, "return_30d": 30, "return_1y": 365,
    "return_3y": 1095, "return_5y": 1825, "return_10y": 3650, 
    "return_15y": 5475, "return_20y": 7300
}

# --- PAGINATION HELPER ---
def fetch_all_data(table_name, columns):
    all_data = []
    offset = 0
    limit = 1000
    while True:
        # NEW FIX: Added .order('ticker') to guarantee stable pagination!
        res = supabase.table(table_name).select(columns).order("ticker").range(offset, offset + limit - 1).execute()
        data = res.data
        if not data:
            break
        all_data.extend(data)
        if len(data) < limit:
            break
        offset += limit
    return pd.DataFrame(all_data)

def run_optimized_brain():
    print("🧠 Starting Institutional Brain Engine...")
    start_time = datetime.now()

    # 1. BULK FETCH ALL DATA
    print("📦 Downloading historical data safely...")
    nav_data = fetch_all_data("daily_nav", "ticker, validity_date, nav")
    bench_data = fetch_all_data("benchmarks", "ticker, validity_date, value")
    payout_data = fetch_all_data("payout_history", "ticker, payout_date, payout_amount, ex_nav")
    # NEW: Fetch inception dates
    funds_data = fetch_all_data("master_funds", "ticker, inception_date")

    if nav_data.empty and bench_data.empty:
        print("❌ No price data found. Aborting.")
        return

    # Standardize Column Names and Dates
    if not bench_data.empty:
        bench_data = bench_data.rename(columns={'value': 'nav'})
        all_prices = pd.concat([nav_data, bench_data])
    else:
        all_prices = nav_data

    all_prices['validity_date'] = pd.to_datetime(all_prices['validity_date'])
    
    # --- DEDUPLICATION SAFETY NET ---
    # Sort by date (newest first) and drop any duplicate dates for the same ticker
    all_prices = all_prices.sort_values(by=['ticker', 'validity_date'], ascending=[True, False])
    all_prices = all_prices.drop_duplicates(subset=['ticker', 'validity_date'], keep='first')

    if not payout_data.empty:
        payout_data['payout_date'] = pd.to_datetime(payout_data['payout_date'])
    
    # Safely convert inception dates, coercing errors to NaT
    if not funds_data.empty:
        funds_data['inception_date'] = pd.to_datetime(funds_data['inception_date'], errors='coerce')

    # 2. GET TICKERS
    all_tickers = all_prices['ticker'].unique()
    final_stats = []

    # 3. CALCULATE IN MEMORY
    for ticker in all_tickers:
        ticker_prices = all_prices[all_prices['ticker'] == ticker].sort_values('validity_date', ascending=False)
        if ticker_prices.empty: continue

        anchor_row = ticker_prices.iloc[0]
        anchor_date = anchor_row['validity_date']
        latest_nav = anchor_row['nav']
        
        # Guard against zero/corrupt latest NAV
        if pd.isna(latest_nav) or latest_nav <= 0:
            continue

        stats_update = {
            "ticker": ticker, 
            "last_updated": datetime.now(pytz.timezone('Asia/Karachi')).isoformat(),
            "last_validity_date": anchor_date.strftime('%Y-%m-%d')
        }

        # Get inception date for this ticker
        ticker_fund_info = funds_data[funds_data['ticker'] == ticker] if not funds_data.empty else pd.DataFrame()
        inception_date = None
        if not ticker_fund_info.empty and pd.notna(ticker_fund_info.iloc[0]['inception_date']):
            inception_date = ticker_fund_info.iloc[0]['inception_date']

        # Pre-filter payouts
        ticker_payouts = payout_data[payout_data['ticker'] == ticker] if not payout_data.empty else pd.DataFrame()

        for col, days in PERIODS.items():
            target_date = anchor_date - timedelta(days=days)
            
            # --- NEW FIX: The Inception Guard ---
            if inception_date and target_date < inception_date:
                stats_update[col] = None
                continue
            
            past_prices = ticker_prices[ticker_prices['validity_date'] <= target_date]
            
            if past_prices.empty:
                stats_update[col] = None
                continue

            # --- NEW FIX: The 7-Day Fallback ---
            valid_past_row = None
            # Look at the closest 7 rows to the target date
            for _, row in past_prices.head(7).iterrows():
                if pd.notna(row['nav']) and row['nav'] > 0:
                    valid_past_row = row
                    break
            
            # If we still didn't find a valid >0 price after looking back 7 days, give up.
            if valid_past_row is None:
                stats_update[col] = None
                continue

            past_nav = valid_past_row['nav']
            past_date = valid_past_row['validity_date']

            # Total Return Calculation
            units = 1.0
            if not ticker_payouts.empty:
                rel_payouts = ticker_payouts[(ticker_payouts['payout_date'] > past_date) & 
                                             (ticker_payouts['payout_date'] <= anchor_date)].sort_values('payout_date')
                
                for _, p_row in rel_payouts.iterrows():
                    if p_row['ex_nav'] > 0:
                        units += (units * p_row['payout_amount']) / p_row['ex_nav']

            multiplier = (latest_nav * units) / past_nav
            
            # Final JSON Safety check
            if pd.isna(multiplier) or math.isinf(multiplier):
                stats_update[col] = None
            else:
                stats_update[col] = round(float(multiplier), 4)

        final_stats.append(stats_update)

    # 4. BULK UPSERT TO SUPABASE
    if final_stats:
        supabase.table("performance_stats").upsert(final_stats, on_conflict="ticker").execute()
        print(f"✅ Calculated and updated {len(final_stats)} tickers.")

    print(f"🎉 Brain Sync Complete. Total Time: {datetime.now() - start_time}")

if __name__ == "__main__":
    run_optimized_brain()