import os
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

# --- THE FIX: PAGINATION HELPER ---
def fetch_all_data(table_name, columns):
    all_data = []
    offset = 0
    limit = 1000
    while True:
        res = supabase.table(table_name).select(columns).range(offset, offset + limit - 1).execute()
        data = res.data
        if not data:
            break
        all_data.extend(data)
        if len(data) < limit:
            break
        offset += limit
    return pd.DataFrame(all_data)

def run_optimized_brain():
    print("🧠 Starting Optimized Brain Engine...")
    start_time = datetime.now()

    # 1. BULK FETCH ALL DATA (Bypassing the 1000 row limit)
    print("📦 Downloading historical data safely...")
    nav_data = fetch_all_data("daily_nav", "ticker, validity_date, nav")
    bench_data = fetch_all_data("benchmarks", "ticker, validity_date, value")
    payout_data = fetch_all_data("payout_history", "ticker, payout_date, payout_amount, ex_nav")

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
    if not payout_data.empty:
        payout_data['payout_date'] = pd.to_datetime(payout_data['payout_date'])

    # 2. GET TICKERS
    all_tickers = all_prices['ticker'].unique()
    final_stats = []

    # 3. CALCULATE IN MEMORY (Fast!)
    for ticker in all_tickers:
        ticker_prices = all_prices[all_prices['ticker'] == ticker].sort_values('validity_date', ascending=False)
        if ticker_prices.empty: continue

        anchor_row = ticker_prices.iloc[0]
        anchor_date = anchor_row['validity_date']
        latest_nav = anchor_row['nav']

        stats_update = {
            "ticker": ticker, 
            "last_updated": datetime.now(pytz.timezone('Asia/Karachi')).isoformat(),
            "last_validity_date": anchor_date.strftime('%Y-%m-%d')
        }

        # Pre-filter payouts for this ticker
        ticker_payouts = payout_data[payout_data['ticker'] == ticker] if not payout_data.empty else pd.DataFrame()

        for col, days in PERIODS.items():
            target_date = anchor_date - timedelta(days=days)
            
            # Find closest price on or before target date
            past_prices = ticker_prices[ticker_prices['validity_date'] <= target_date]
            
            if past_prices.empty:
                stats_update[col] = None
                continue

            past_row = past_prices.iloc[0]
            past_nav = past_row['nav']
            past_date = past_row['validity_date']

            # Total Return Calculation
            units = 1.0
            if not ticker_payouts.empty:
                # Get relevant payouts between past_date and anchor_date
                rel_payouts = ticker_payouts[(ticker_payouts['payout_date'] > past_date) & 
                                             (ticker_payouts['payout_date'] <= anchor_date)].sort_values('payout_date')
                
                for _, p_row in rel_payouts.iterrows():
                    if p_row['ex_nav'] > 0:
                        units += (units * p_row['payout_amount']) / p_row['ex_nav']

            multiplier = (latest_nav * units) / past_nav
            stats_update[col] = round(float(multiplier), 4)

        final_stats.append(stats_update)

    # 4. BULK UPSERT TO SUPABASE (One single network call!)
    if final_stats:
        supabase.table("performance_stats").upsert(final_stats, on_conflict="ticker").execute()
        print(f"✅ Calculated and updated {len(final_stats)} tickers.")

    print(f"🎉 Brain Sync Complete. Total Time: {datetime.now() - start_time}")

if __name__ == "__main__":
    run_optimized_brain()