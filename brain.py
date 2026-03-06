import os
import pandas as pd
from datetime import datetime, timedelta
from supabase import create_client
from concurrent.futures import ThreadPoolExecutor

# --- 1. CONNECTION PATH FOR GITHUB ---
# This reads from the secure GitHub Secrets you will set up
SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_KEY = os.environ.get("SUPABASE_KEY")

if not SUPABASE_URL or not SUPABASE_KEY:
    print("❌ Connection Error: SUPABASE_URL or SUPABASE_KEY is missing from environment.")
else:
    supabase = create_client(SUPABASE_URL, SUPABASE_KEY)
    print("🚀 Connection Path established successfully!")

# --- CONFIGURATION ---
PERIODS = {
    "return_1d": 1, "return_30d": 30, "return_1y": 365,
    "return_3y": 1095, "return_5y": 1825, "return_10y": 3650, 
    "return_15y": 5475, "return_20y": 7300
}

def process_single_ticker(ticker):
    try:
        # 1. GET LATEST ANCHOR
        latest_res = supabase.table("daily_nav").select("validity_date, nav")\
            .eq("ticker", ticker).gt("nav", 0).order("validity_date", desc=True).limit(1).execute().data
        
        if not latest_res:
            latest_res = supabase.table("benchmarks").select("validity_date, value")\
                .eq("ticker", ticker).gt("value", 0).order("validity_date", desc=True).limit(1).execute().data
            if latest_res: latest_res[0]['nav'] = latest_res[0]['value']
        
        if not latest_res: return f"⏩ {ticker}: No data"

        anchor_date = pd.to_datetime(latest_res[0]['validity_date'])
        latest_nav = latest_res[0]['nav']

        stats_update = {
            "ticker": ticker, 
            "last_updated": datetime.now().isoformat(),
            "last_validity_date": anchor_date.strftime('%Y-%m-%d')
        }

        # 2. PAYOUTS (Increased limit for Daily Dividend Funds)
        payouts = supabase.table("payout_history").select("payout_date, payout_amount, ex_nav")\
            .eq("ticker", ticker).order("payout_date", desc=False).limit(20000).execute().data
        p_df = pd.DataFrame(payouts) if payouts else pd.DataFrame()
        if not p_df.empty: p_df['payout_date'] = pd.to_datetime(p_df['payout_date'])

        # 3. SNIPE PERIODS (Absolute Multipliers)
        for col, days in PERIODS.items():
            target_date = (anchor_date - timedelta(days=days)).strftime('%Y-%m-%d')
            
            past_res = supabase.table("daily_nav").select("validity_date, nav")\
                .eq("ticker", ticker).lte("validity_date", target_date)\
                .gt("nav", 0).order("validity_date", desc=True).limit(1).execute().data
            
            if not past_res:
                past_res = supabase.table("benchmarks").select("validity_date, value")\
                    .eq("ticker", ticker).lte("validity_date", target_date)\
                    .gt("value", 0).order("validity_date", desc=True).limit(1).execute().data
                if past_res: past_res[0]['nav'] = past_res[0]['value']

            if not past_res:
                stats_update[col] = None
                continue

            past_nav = past_res[0]['nav']
            past_date = pd.to_datetime(past_res[0]['validity_date'])

            # Total Return Multiplier
            units = 1.0
            if not p_df.empty:
                rel_payouts = p_df[(p_df['payout_date'] > past_date) & (p_df['payout_date'] <= anchor_date)]
                for _, p_row in rel_payouts.iterrows():
                    if p_row['ex_nav'] > 0:
                        units += (units * p_row['payout_amount']) / p_row['ex_nav']

            multiplier = (latest_nav * units) / past_nav
            stats_update[col] = round(float(multiplier), 4)

        supabase.table("performance_stats").upsert(stats_update, on_conflict="ticker").execute()
        return f"✅ {ticker}: Absolute Multiplier Calculated."

    except Exception as e:
        return f"❌ {ticker}: {str(e)}"

def run_speed_engine_v10_1():
    print("🚀 Starting V10.1: Multi-Threaded Absolute Snipe...")
    
    # Check connection before starting
    if not supabase:
        print("❌ Supabase client not initialized. Aborting.")
        return

    funds = supabase.table("master_funds").select("ticker").execute().data
    benchmarks = supabase.table("benchmarks").select("ticker").execute().data
    all_tickers = list(set([f['ticker'] for f in funds] + [b['ticker'] for b in benchmarks]))

    # ThreadPoolExecutor for speed
    with ThreadPoolExecutor(max_workers=10) as executor:
        results = list(executor.map(process_single_ticker, all_tickers))
    
    for r in results:
        print(r)
    
    print("\n" + "="*30 + "\nSync Complete. Check performance_stats table.")

if __name__ == "__main__":
    run_speed_engine_v10_1()