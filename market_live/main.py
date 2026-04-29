import os
import requests
from bs4 import BeautifulSoup
from lxml import html
import re
from supabase import create_client
from datetime import datetime
import pytz
import urllib3
import sys
import functions_framework

session = requests.Session()
session.headers.update(
    {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    }
)

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_KEY = os.environ.get("SUPABASE_KEY")

if not SUPABASE_URL or not SUPABASE_KEY:
    print("❌ ERROR: Supabase Keys are missing!")
    sys.exit(1)
supabase = create_client(SUPABASE_URL, SUPABASE_KEY)


def clean_ticker(raw_ticker):
    ticker = raw_ticker.strip().upper()
    return re.sub(r"(XD|XB|XR)+$", "", ticker)


def to_float(val_str):
    if not val_str or str(val_str).strip() in ["-", "", "N/A"]:
        return 0.0
    clean_str = str(val_str).replace(",", "").replace("%", "").strip()
    try:
        return float(clean_str)
    except ValueError:
        return 0.0


# --- LIVE INDICES SCRAPER ---
def sync_live_indices():
    print("📈 Syncing Live PSX Indices (KSE100 & KMI30)...")
    try:
        response = session.get("https://dps.psx.com.pk", timeout=15)
        tree = html.fromstring(response.content)

        stats_elements = tree.xpath("//div[@class='stats_value']")

        batch = []
        for ticker, xp_idx in [("KSE100", 1), ("KMI30", 5)]:
            val_result = tree.xpath(f"//*[@id='indicesTabs']/div[2]/div[{xp_idx}]/h1")

            if val_result:
                current_val = float(
                    val_result[0].text_content().strip().replace(",", "").split(" ")[0]
                )

                ldcp_val = 0.0
                try:
                    if ticker == "KSE100" and len(stats_elements) > 3:
                        ldcp_text = (
                            stats_elements[3].text_content().strip().replace(",", "")
                        )
                        ldcp_val = float(re.search(r"[\d\.]+", ldcp_text).group())
                    elif ticker == "KMI30" and len(stats_elements) > 27:
                        ldcp_text = (
                            stats_elements[27].text_content().strip().replace(",", "")
                        )
                        ldcp_val = float(re.search(r"[\d\.]+", ldcp_text).group())
                except Exception as e:
                    pass

                change = current_val - ldcp_val
                change_pct = (change / ldcp_val * 100) if ldcp_val > 0 else 0.0

                batch.append(
                    {
                        "ticker": ticker,
                        "current_price": current_val,
                        "ldcp": ldcp_val,
                        "change": change,
                        "change_percent": change_pct,
                        "last_updated": datetime.now(
                            pytz.timezone("Asia/Karachi")
                        ).isoformat(),
                    }
                )

        if batch:
            supabase.table("live_stock_prices").upsert(
                batch, on_conflict="ticker"
            ).execute()
            print(f"   ✅ Live Indices updated.")
    except Exception as e:
        print(f"   ❌ Live Indices Error: {e}")


# --- THE CORE STOCK/ETF SCRAPER ---
def sync_live_markets():
    print("📈 Initiating Live Market Scrape (Stocks & ETFs)...")

    try:
        master_res = supabase.table("master_stocks").select("ticker").execute()
        valid_tickers = {row["ticker"] for row in master_res.data}
    except Exception as e:
        print(f"❌ Error fetching master_stocks: {e}")
        return

    indices = [
        ("ALLSHR", "https://dps.psx.com.pk/indices/ALLSHR", None),
        ("KSE100", "https://dps.psx.com.pk/indices/KSE100", "kse100_weight"),
        ("KMI30", "https://dps.psx.com.pk/indices/KMI30", "kmi30_weight"),
        ("PSXDIV20", "https://dps.psx.com.pk/indices/PSXDIV20", "psxdiv20_weight"),
    ]

    master_stocks_dict = {}
    current_time_pk = datetime.now(pytz.timezone("Asia/Karachi")).isoformat()

    for index_name, url, weight_col in indices:
        try:
            print(f"   -> Fetching {index_name} Components...")
            response = session.get(url, timeout=15)
            soup = BeautifulSoup(response.content, "lxml")

            table = soup.find("table")
            if not table:
                continue

            headers = [th.text.strip().upper() for th in table.find_all("th")]

            col_idx = {
                "symbol": next((i for i, h in enumerate(headers) if "SYMBOL" in h), 0),
                "ldcp": next((i for i, h in enumerate(headers) if "LDCP" in h), -1),
                "current": next(
                    (i for i, h in enumerate(headers) if "CURRENT" in h), -1
                ),
                "change": next(
                    (
                        i
                        for i, h in enumerate(headers)
                        if "CHANGE" in h and "%" not in h
                    ),
                    -1,
                ),
                "change_percent": next(
                    (i for i, h in enumerate(headers) if "CHANGE" in h and "%" in h), -1
                ),
                "weight": next(
                    (
                        i
                        for i, h in enumerate(headers)
                        if "WTG" in h or "WGT" in h or "WEIGHT" in h
                    ),
                    -1,
                ),
                "volume": next((i for i, h in enumerate(headers) if "VOLUME" in h), -1),
                "market_cap": next(
                    (i for i, h in enumerate(headers) if "MARKET CAP" in h), -1
                ),
            }

            rows = table.find_all("tr")[1:]

            for row in rows:
                cells = row.find_all("td")
                if len(cells) < 5:
                    continue

                raw_ticker = cells[col_idx["symbol"]].text.strip()
                base_ticker = clean_ticker(raw_ticker)

                ldcp = (
                    to_float(cells[col_idx["ldcp"]].text)
                    if col_idx["ldcp"] != -1
                    else 0.0
                )
                current = (
                    to_float(cells[col_idx["current"]].text)
                    if col_idx["current"] != -1
                    else 0.0
                )
                change = (
                    to_float(cells[col_idx["change"]].text)
                    if col_idx["change"] != -1
                    else 0.0
                )
                change_pct = (
                    to_float(cells[col_idx["change_percent"]].text)
                    if col_idx["change_percent"] != -1
                    else 0.0
                )
                weight = (
                    to_float(cells[col_idx["weight"]].text)
                    if col_idx["weight"] != -1
                    else 0.0
                )
                volume = (
                    to_float(cells[col_idx["volume"]].text)
                    if col_idx["volume"] != -1
                    else 0.0
                )
                mkt_cap = (
                    to_float(cells[col_idx["market_cap"]].text)
                    if col_idx["market_cap"] != -1
                    else 0.0
                )

                if base_ticker not in master_stocks_dict:
                    master_stocks_dict[base_ticker] = {
                        "ticker": base_ticker,
                        "current_price": current,
                        "ldcp": ldcp,
                        "change": change,
                        "change_percent": change_pct,
                        "volume": volume,
                        "market_cap_m": mkt_cap,
                        "kse100_weight": 0.0,
                        "kmi30_weight": 0.0,
                        "psxdiv20_weight": 0.0,
                        "last_updated": current_time_pk,
                    }

                if weight_col and col_idx["weight"] != -1:
                    master_stocks_dict[base_ticker][weight_col] = weight

        except Exception as e:
            print(f"   ❌ Error scraping {index_name}: {e}")

    final_batch = [
        data for ticker, data in master_stocks_dict.items() if ticker in valid_tickers
    ]

    if final_batch:
        try:
            chunk_size = 50
            for i in range(0, len(final_batch), chunk_size):
                chunk = final_batch[i : i + chunk_size]
                supabase.table("live_stock_prices").upsert(
                    chunk, on_conflict="ticker"
                ).execute()
            print(
                f"✅ Successfully synced {len(final_batch)} total unique stocks/ETFs to database."
            )
        except Exception as e:
            print(f"❌ Supabase Upsert Error: {e}")


@functions_framework.http
def run_live_market(request):
    start_time = datetime.now()

    sync_live_indices()
    sync_live_markets()

    total_time = datetime.now() - start_time
    completion_msg = f"⏱️ LIVE MARKET SYNC COMPLETE. Total Time: {total_time}"
    print(completion_msg)

    return completion_msg, 200
