import os
import math
import time
import pandas as pd
from datetime import datetime, timedelta
from supabase import create_client
import pytz
import functions_framework  # <-- Google Cloud requirement

# --- 1. CONNECTION ---
SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_KEY = os.environ.get("SUPABASE_KEY")

if not SUPABASE_URL or not SUPABASE_KEY:
    print("❌ Connection Error: Keys missing.")
    exit(1)

supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

# --- CONFIGURATION ---
PERIODS = {
    "return_1d": 1,
    "return_30d": 30,
    "return_1y": 365,
    "return_3y": 1095,
    "return_5y": 1825,
    "return_10y": 3650,
    "return_15y": 5475,
    "return_20y": 7300,
}


# --- PAGINATION HELPER (FIXED FOR DYNAMIC COLUMNS) ---
def fetch_all_data(table_name, columns, date_col="validity_date"):
    all_data = []
    offset = 0
    limit = 50000
    print(f"  -> Fetching table: {table_name}...")

    while True:
        retries = 3
        data = None

        for attempt in range(retries):
            try:
                query = supabase.table(table_name).select(columns).order("ticker")
                if date_col:
                    query = query.order(date_col, desc=True)

                res = query.range(offset, offset + limit - 1).execute()
                data = res.data
                break
            except Exception as e:
                print(f"     ⚠️ Error fetching data: {e}. Retrying in 2 seconds...")
                time.sleep(2)

        if data is None:
            print(f"❌ Failed to fetch {table_name}. Aborting.")
            break

        if not data:
            break

        all_data.extend(data)
        print(f"     ... downloaded {len(all_data)} rows so far")

        if len(data) < limit:
            break

        offset += limit
        time.sleep(0.1)

    return pd.DataFrame(all_data)


def run_optimized_brain():
    print("🧠 Starting Institutional Brain Engine (High Precision)...")
    start_time = datetime.now()

    print("📦 Downloading historical data safely...")
    # --- CHANGED: Added 'ldcp' to the fetch queries ---
    nav_data = fetch_all_data(
        "daily_nav", "ticker, validity_date, nav, ldcp", date_col="validity_date"
    )
    bench_data = fetch_all_data(
        "benchmarks", "ticker, validity_date, value, ldcp", date_col="validity_date"
    )
    payout_data = fetch_all_data(
        "payout_history",
        "ticker, payout_date, payout_amount, ex_nav",
        date_col="payout_date",
    )
    funds_data = fetch_all_data("master_funds", "ticker, inception_date", date_col=None)

    if nav_data.empty and bench_data.empty:
        print("❌ No price data found. Aborting.")
        return

    if not bench_data.empty:
        bench_data = bench_data.rename(columns={"value": "nav"})
        all_prices = pd.concat([nav_data, bench_data])
    else:
        all_prices = nav_data

    all_prices["validity_date"] = pd.to_datetime(all_prices["validity_date"])

    all_prices = all_prices.sort_values(
        by=["ticker", "validity_date"], ascending=[True, False]
    )
    all_prices = all_prices.drop_duplicates(
        subset=["ticker", "validity_date"], keep="first"
    )

    if not payout_data.empty:
        payout_data["payout_date"] = pd.to_datetime(payout_data["payout_date"])

    if not funds_data.empty:
        funds_data["inception_date"] = pd.to_datetime(
            funds_data["inception_date"], errors="coerce"
        )

    all_tickers = all_prices["ticker"].unique()
    final_stats = []

    for ticker in all_tickers:
        ticker_prices = all_prices[all_prices["ticker"] == ticker].sort_values(
            "validity_date", ascending=False
        )
        if ticker_prices.empty:
            continue

        anchor_row = ticker_prices.iloc[0]
        anchor_date = anchor_row["validity_date"]
        latest_nav = anchor_row["nav"]

        if pd.isna(latest_nav) or latest_nav <= 0:
            continue

        stats_update = {
            "ticker": ticker,
            "last_updated": datetime.now(pytz.timezone("Asia/Karachi")).isoformat(),
            "last_validity_date": anchor_date.strftime("%Y-%m-%d"),
        }

        ticker_fund_info = (
            funds_data[funds_data["ticker"] == ticker]
            if not funds_data.empty
            else pd.DataFrame()
        )
        inception_date = None
        if not ticker_fund_info.empty and pd.notna(
            ticker_fund_info.iloc[0]["inception_date"]
        ):
            inception_date = ticker_fund_info.iloc[0]["inception_date"]

        ticker_payouts = (
            payout_data[payout_data["ticker"] == ticker]
            if not payout_data.empty
            else pd.DataFrame()
        )

        first_day_of_anchor_month = anchor_date.replace(day=1)
        mtd_target_date = first_day_of_anchor_month - timedelta(days=1)

        if anchor_date.month >= 7:
            fytd_target_date = pd.Timestamp(year=anchor_date.year, month=6, day=30)
        else:
            fytd_target_date = pd.Timestamp(year=anchor_date.year - 1, month=6, day=30)

        custom_periods = {
            "return_mtd": mtd_target_date,
            "return_fytd": fytd_target_date,
        }

        for col, target_date in custom_periods.items():
            if inception_date and target_date < inception_date:
                stats_update[col] = None
                continue

            past_prices = ticker_prices[ticker_prices["validity_date"] <= target_date]
            if past_prices.empty:
                stats_update[col] = None
                continue

            valid_past_row = None
            for _, row in past_prices.head(7).iterrows():
                if pd.notna(row["nav"]) and row["nav"] > 0:
                    valid_past_row = row
                    break

            if valid_past_row is None:
                stats_update[col] = None
                continue

            past_nav = valid_past_row["nav"]
            past_date = valid_past_row["validity_date"]

            units = 1.0
            if not ticker_payouts.empty:
                rel_payouts = ticker_payouts[
                    (ticker_payouts["payout_date"] > past_date)
                    & (ticker_payouts["payout_date"] <= anchor_date)
                ].sort_values("payout_date")
                for _, p_row in rel_payouts.iterrows():
                    if p_row["ex_nav"] > 0:
                        units += (units * p_row["payout_amount"]) / p_row["ex_nav"]

            multiplier = (latest_nav * units) / past_nav

            # --- ANOMALY DETECTOR GUARDRAIL ---
            # If the fund moves more than +/- 30% in any given period, it's likely bad data.
            if pd.isna(multiplier) or math.isinf(multiplier):
                stats_update[col] = None
            elif multiplier > 1.30 or multiplier < 0.70:
                print(
                    f"🚨 ANOMALY DETECTED for {ticker}: {col} multiplier {multiplier} out of bounds. Skipping to protect app UI."
                )
                stats_update[col] = None
            else:
                stats_update[col] = round(float(multiplier), 8)
            # ----------------------------------

        for col, days in PERIODS.items():
            # --- CHANGED: THE 1D RETURN LDCP FAST-TRACK ---
            # If we are calculating 1D return, AND this row has an official LDCP, use it instantly!
            if (
                col == "return_1d"
                and "ldcp" in anchor_row
                and pd.notna(anchor_row["ldcp"])
                and anchor_row["ldcp"] > 0
            ):
                past_nav = float(anchor_row["ldcp"])
                past_date = anchor_date - timedelta(
                    days=1
                )  # Proxy date for payout filtering
            else:
                # --- THE OLD WAY: Time-travel lookup (Used for Mutual Funds and 30D, 1Y, 3Y, etc.) ---
                target_date = anchor_date - timedelta(days=days)

                if inception_date and target_date < inception_date:
                    stats_update[col] = None
                    continue

                past_prices = ticker_prices[
                    ticker_prices["validity_date"] <= target_date
                ]

                if past_prices.empty:
                    stats_update[col] = None
                    continue

                valid_past_row = None
                for _, row in past_prices.head(7).iterrows():
                    if pd.notna(row["nav"]) and row["nav"] > 0:
                        valid_past_row = row
                        break

                if valid_past_row is None:
                    stats_update[col] = None
                    continue

                past_nav = valid_past_row["nav"]
                past_date = valid_past_row["validity_date"]
            # ------------------------------------------------

            units = 1.0
            if not ticker_payouts.empty:
                rel_payouts = ticker_payouts[
                    (ticker_payouts["payout_date"] > past_date)
                    & (ticker_payouts["payout_date"] <= anchor_date)
                ].sort_values("payout_date")

                for _, p_row in rel_payouts.iterrows():
                    if p_row["ex_nav"] > 0:
                        units += (units * p_row["payout_amount"]) / p_row["ex_nav"]

            multiplier = (latest_nav * units) / past_nav

            # --- ANOMALY DETECTOR GUARDRAIL ---
            # If the fund moves more than +/- 30% in any given period, it's likely bad data.
            if pd.isna(multiplier) or math.isinf(multiplier):
                stats_update[col] = None
            elif multiplier > 1.30 or multiplier < 0.70:
                print(
                    f"🚨 ANOMALY DETECTED for {ticker}: {col} multiplier {multiplier} out of bounds. Skipping to protect app UI."
                )
                stats_update[col] = None
            else:
                stats_update[col] = round(float(multiplier), 8)
            # ----------------------------------

        final_stats.append(stats_update)

    if final_stats:
        chunk_size = 100
        print(f"📤 Uploading {len(final_stats)} calculated records...")
        for i in range(0, len(final_stats), chunk_size):
            chunk = final_stats[i : i + chunk_size]
            supabase.table("performance_stats").upsert(
                chunk, on_conflict="ticker"
            ).execute()

        print(
            f"✅ Calculated and updated {len(final_stats)} tickers with high precision."
        )

    print(f"🎉 Brain Sync Complete. Total Time: {datetime.now() - start_time}")


# ==========================================
# Google Cloud Function Entry Point
# ==========================================
@functions_framework.http
def run_brain(request):
    """HTTP Cloud Function to trigger the brain calculations."""
    run_optimized_brain()
    return "✅ Brain Sync Complete.", 200
