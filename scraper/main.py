import os
import requests
from bs4 import BeautifulSoup
from lxml import html
import re
from supabase import create_client
from datetime import datetime, timedelta
import pytz
import urllib3
import sys
from concurrent.futures import ThreadPoolExecutor
import yfinance as yf
import functions_framework  # <-- Google Cloud requirement

session = requests.Session()
session.headers.update(
    {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    }
)

# Suppress SSL Warnings
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# --- 1. CONNECTION ---
SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_KEY = os.environ.get("SUPABASE_KEY")

if not SUPABASE_URL or not SUPABASE_KEY:
    print("❌ ERROR: Supabase Keys are missing from Environment Variables!")
    sys.exit(1)
supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

# --- PRE-FETCH FUND MASTER DATA FOR GUARDRAILS ---
master_res = (
    supabase.table("master_funds")
    .select("ticker, category, return_logic, fund_id_mufap, amc_website_name")
    .execute()
)
FUND_LOGIC_MAP = {
    row["ticker"]: row.get("return_logic", "Absolute") for row in master_res.data
}
FUND_CATEGORY_MAP = {row["ticker"]: row.get("category", "") for row in master_res.data}


# --- THE GUARDRAILS ---
def is_valid_date(date_str, ticker):
    try:
        dt = datetime.strptime(date_str, "%Y-%m-%d").date()
        today_pk = datetime.now(pytz.timezone("Asia/Karachi")).date()

        ticker_logic = FUND_LOGIC_MAP.get(ticker, "Absolute")

        if ticker_logic == "Annualized":
            return True

        if ticker_logic == "Absolute":
            if dt > today_pk:
                print(f"   🛡️ Guardrail active: Skipped {ticker} (Future Date {dt})")
                return False

            weekend_exceptions = [
                "BTC",
                "ETH",
                "SOL",
                "BTC-USD",
                "ETH-USD",
                "SOL-USD",
                "CPI_PK",
                "GOLD_24K",
                "GOLD_24K_LOCAL",
                "GOLD_XAU",
                "USDPKR",
            ]

            if dt.weekday() >= 5 and ticker not in weekend_exceptions:
                print(f"   🛡️ Guardrail active: Skipped {ticker} (Weekend Date {dt})")
                return False

        return True

    except Exception as e:
        print(f"   ⚠️ Date parsing error for {ticker}: {e}")
        return False


# --- THE FINAL BOSS HIERARCHY ---
def filter_protected_entries(batch, table_name, date_col="validity_date"):
    if not batch:
        return []
    try:
        dates = list(set([item[date_col] for item in batch]))

        res = (
            supabase.table(table_name)
            .select(f"ticker, {date_col}, source")
            .in_(date_col, dates)
            .execute()
        )

        existing_map = {
            (r["ticker"], r[date_col]): (r.get("source") or "") for r in res.data
        }

        filtered_batch = []
        for item in batch:
            key = (item["ticker"], item[date_col])
            existing_source = existing_map.get(key, "")
            incoming_source = item.get("source") or ""

            # 1. Manual is God Mode. Nothing can overwrite it.
            if existing_source == "Manual":
                continue

            # 2. MUFAP is the safety net. It can never overwrite AMC_Website.
            if incoming_source == "MUFAP" and existing_source == "AMC_Website":
                continue

            filtered_batch.append(item)

        skipped = len(batch) - len(filtered_batch)
        if skipped > 0:
            print(
                f"   🛡️ Hierarchy Guardrail: Protected {skipped} higher-priority records."
            )

        return filtered_batch
    except Exception as e:
        print(f"   ⚠️ Could not check protected entries, proceeding carefully: {e}")
        return batch


# --- TASK A: PSX INDICES (UPDATED FOR LDCP & EOD TIMING) ---
def sync_psx_indices():
    now_pk = datetime.now(pytz.timezone("Asia/Karachi"))
    if 8 <= now_pk.hour < 17:
        print("📈 Skipping PSX Indices (EOD) - Market is open.")
        return

    print("📈 Syncing PSX Indices...")
    try:
        response = session.get("https://dps.psx.com.pk", timeout=15)
        tree = html.fromstring(response.content)

        # Grab all stats blocks for LDCP mapping
        stats_elements = tree.xpath("//div[@class='stats_value']")

        batch = []
        for ticker, xp_idx in [("KSE100", 1), ("KMI30", 5)]:
            val_result = tree.xpath(f"//*[@id='indicesTabs']/div[2]/div[{xp_idx}]/h1")
            date_result = tree.xpath(
                f"//*[@id='indicesTabs']/div[2]/div[{xp_idx}]/div[1]"
            )

            if val_result and date_result:
                val = float(
                    val_result[0].text_content().strip().replace(",", "").split(" ")[0]
                )

                # --- LDCP Extraction Logic ---
                ldcp_val = None
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
                    print(f"   ⚠️ Could not parse LDCP for {ticker}: {e}")

                raw_date_text = date_result[0].text_content().strip()
                date_match = re.search(r"([A-Za-z]+\s\d{1,2},\s\d{4})", raw_date_text)

                if date_match:
                    date_str = date_match.group(1)
                    try:
                        web_date = datetime.strptime(date_str, "%b %d, %Y").strftime(
                            "%Y-%m-%d"
                        )
                    except ValueError:
                        web_date = datetime.strptime(date_str, "%B %d, %Y").strftime(
                            "%Y-%m-%d"
                        )
                else:
                    web_date = datetime.now(pytz.timezone("Asia/Karachi")).strftime(
                        "%Y-%m-%d"
                    )

                batch.append(
                    {
                        "ticker": ticker,
                        "value": val,
                        "ldcp": ldcp_val,  # NEW
                        "validity_date": web_date,
                        "source": "PSX",
                    }
                )

        if batch:
            safe_batch = filter_protected_entries(batch, "benchmarks")
            if safe_batch:
                supabase.table("benchmarks").upsert(
                    safe_batch, on_conflict="ticker,validity_date"
                ).execute()
                print(f"   ✅ PSX Indices updated (including LDCP).")
    except Exception as e:
        print(f"   ❌ PSX Error: {e}")


# --- TASK B1: LOCAL GOLD (Portfolio Tracker) ---
def sync_gold_rates():
    print("💰 Syncing Local Gold (Portfolio)...")
    try:
        soup = BeautifulSoup(
            session.get("https://gold.pk/gold-rates-pakistan.php", timeout=15).text,
            "lxml",
        )
        gold_el = soup.find("p", class_="goldratehome")
        if gold_el:
            val = float(
                re.search(
                    r"(\d+\.\d+|\d+)", gold_el.text.replace("Rs.", "").replace(",", "")
                ).group(1)
            )
            if val > 1000000:
                val = float(str(int(val))[:6])

            now_pk = datetime.now(pytz.timezone("Asia/Karachi"))
            if now_pk.hour < 15:
                assigned_date = (now_pk - timedelta(days=1)).strftime("%Y-%m-%d")
            else:
                assigned_date = now_pk.strftime("%Y-%m-%d")

            gold_data = [
                {
                    "ticker": "GOLD_24K_LOCAL",
                    "value": val,
                    "validity_date": assigned_date,
                    "source": "Gold.pk",
                }
            ]
            safe_batch = filter_protected_entries(gold_data, "benchmarks")

            if safe_batch:
                supabase.table("benchmarks").upsert(
                    safe_batch, on_conflict="ticker,validity_date"
                ).execute()
                print(f"   ✅ Local Gold updated.")
    except Exception as e:
        print(f"   ❌ Local Gold Error: {e}")


# --- TASK B2: INTERNATIONAL GOLD (UPDATED FOR LDCP) ---
def sync_international_gold():
    print("🌍 Syncing International Gold (XAU & PKR Benchmark)...")
    try:
        # Fetch last 6 days to ensure the 5th day has an accurate "previous close" (LDCP)
        xau_data = yf.Ticker("GC=F").history(period="6d")
        pkr_data = yf.Ticker("PKR=X").history(period="6d")

        batch = []

        xau_dict = {
            index.strftime("%Y-%m-%d"): float(row["Close"])
            for index, row in xau_data.iterrows()
        }
        pkr_dict = {
            index.strftime("%Y-%m-%d"): float(row["Close"])
            for index, row in pkr_data.iterrows()
        }

        # Find matching dates and sort them sequentially
        common_dates = sorted(
            list(set(xau_dict.keys()).intersection(set(pkr_dict.keys())))
        )

        # Start from index 1 so we can look back to index 0 for the exact LDCP
        for i in range(1, len(common_dates)):
            date_str = common_dates[i]
            prev_date = common_dates[i - 1]

            # Current Values
            xau_val = xau_dict[date_str]
            pkr_val = pkr_dict[date_str]
            gold_24k_benchmark_val = xau_val * pkr_val * 11.6638 / 31.1035

            # Previous Close (LDCP) Values
            xau_ldcp = xau_dict[prev_date]
            pkr_ldcp = pkr_dict[prev_date]
            gold_24k_ldcp = xau_ldcp * pkr_ldcp * 11.6638 / 31.1035

            batch.append(
                {
                    "ticker": "GOLD_XAU",
                    "value": xau_val,
                    "ldcp": xau_ldcp,
                    "validity_date": date_str,
                    "source": "Yahoo Finance",
                }
            )
            batch.append(
                {
                    "ticker": "USDPKR",
                    "value": pkr_val,
                    "ldcp": pkr_ldcp,
                    "validity_date": date_str,
                    "source": "Yahoo Finance",
                }
            )
            batch.append(
                {
                    "ticker": "GOLD_24K",
                    "value": gold_24k_benchmark_val,
                    "ldcp": gold_24k_ldcp,
                    "validity_date": date_str,
                    "source": "Yahoo Finance",
                }
            )

        if batch:
            safe_batch = filter_protected_entries(batch, "benchmarks")
            if safe_batch:
                supabase.table("benchmarks").upsert(
                    safe_batch, on_conflict="ticker,validity_date"
                ).execute()
                print(
                    f"   ✅ {len(safe_batch)} International Gold & FX records synced (with LDCP)."
                )
    except Exception as e:
        print(f"   ❌ International Gold Error: {e}")


# --- TASK C: PSX ETFs (UPDATED FOR DUAL-WRITE & LDCP) ---
def fetch_etf(ticker):
    try:
        soup = BeautifulSoup(
            session.get(f"https://dps.psx.com.pk/etf/{ticker}", timeout=10).text, "lxml"
        )

        # 1. Grab Live Price
        price = float(
            re.findall(r"\d+\.\d+", soup.find("div", class_="quote__price").text)[0]
        )

        # 2. Grab LDCP (from the first stats_value element, mirroring index 1 in Google Sheets)
        ldcp = None
        stats_divs = soup.find_all("div", class_="stats_value")
        if stats_divs:
            ldcp_text = stats_divs[0].text.replace(",", "").strip()
            ldcp_match = re.search(r"[\d\.]+", ldcp_text)
            if ldcp_match:
                ldcp = float(ldcp_match.group())

        # 3. Grab Date
        date_match = re.search(
            r"[A-Z][a-z]{2}\s\d{1,2},\s\d{4}",
            soup.find("div", class_="quote__date").text,
        ).group()
        web_date = datetime.strptime(date_match, "%b %d, %Y").strftime("%Y-%m-%d")

        if is_valid_date(web_date, ticker):
            return {
                # Payload for daily_nav (Historical Charts)
                "daily_nav": {
                    "ticker": ticker,
                    "nav": price,
                    "ldcp": ldcp,
                    "validity_date": web_date,
                    "source": "PSX",
                },
                # Payload for live_stock_prices (Portfolio Tracker)
                "live_stock": {
                    "ticker": ticker,
                    "current_price": price,
                    "ldcp": ldcp,
                    "last_updated": datetime.now(
                        pytz.timezone("Asia/Karachi")
                    ).isoformat(),
                },
            }
        return None
    except Exception as e:
        # print(f"Error fetching ETF {ticker}: {e}") # Optional debugging
        return None


def sync_psx_etfs():
    now_pk = datetime.now(pytz.timezone("Asia/Karachi"))
    if 8 <= now_pk.hour < 17:
        print("📊 Skipping PSX ETFs (EOD) - Market is open.")
        return

    print("📊 Syncing ETFs from PSX...")
    psx_etf_tickers = []
    for ticker, category in FUND_CATEGORY_MAP.items():
        if "Exchange Traded Fund" in str(category):
            # Exclude HBLTETF (MUFAP specific)
            if FUND_LOGIC_MAP.get(ticker) != "Annualized" and ticker != "HBLTETF":
                psx_etf_tickers.append(ticker)

    with ThreadPoolExecutor(max_workers=8) as executor:
        results = list(filter(None, executor.map(fetch_etf, psx_etf_tickers)))

    if results:
        # Separate the dual-payloads
        daily_nav_batch = [res["daily_nav"] for res in results]
        live_stock_batch = [res["live_stock"] for res in results]

        # 1. Write to daily_nav
        safe_batch = filter_protected_entries(daily_nav_batch, "daily_nav")
        if safe_batch:
            supabase.table("daily_nav").upsert(
                safe_batch, on_conflict="ticker,validity_date"
            ).execute()
            print(f"   ✅ {len(safe_batch)} ETFs historically updated (daily_nav).")

        # 2. Dual-Write to live_stock_prices
        if live_stock_batch:
            supabase.table("live_stock_prices").upsert(
                live_stock_batch, on_conflict="ticker"
            ).execute()
            print(
                f"   ✅ {len(live_stock_batch)} ETFs live snapshot updated (live_stock_prices)."
            )


# --- TASK D: TARGETED MUFAP ---
def sync_mufap_master():
    print("🏛️ Syncing MUFAP (Targeted)...")
    psx_exclusive_etfs = set()
    for ticker, category in FUND_CATEGORY_MAP.items():
        if (
            "Exchange Traded Fund" in str(category)
            and FUND_LOGIC_MAP.get(ticker) != "Annualized"
        ):
            psx_exclusive_etfs.add(ticker)

    # THE FIX: We removed the `amc_direct_tickers` ban.
    # MUFAP now acts as a safety net for ALL funds.
    excluded_tickers = psx_exclusive_etfs

    target_ids = {
        str(int(float(row["fund_id_mufap"])))
        for row in master_res.data
        if row.get("fund_id_mufap") and row["ticker"] not in excluded_tickers
    }
    id_to_ticker = {
        str(int(float(row["fund_id_mufap"]))): row["ticker"]
        for row in master_res.data
        if row.get("fund_id_mufap") and row["ticker"] not in excluded_tickers
    }

    batch = []
    try:
        soup = BeautifulSoup(
            session.get(
                "https://www.mufap.com.pk/Industry/IndustryStatDaily?tab=3",
                verify=False,
                timeout=15,
            ).text,
            "lxml",
        )
        for row in soup.find_all("tr"):
            cells = row.find_all("td")
            if len(cells) < 9:
                continue
            link = cells[2].find("a", href=True)
            if link:
                m_id = re.search(r"FundID=(\d+)", link["href"]).group(1)
                if m_id in target_ids:
                    ticker = id_to_ticker[m_id]
                    try:
                        dt_str = datetime.strptime(
                            cells[8].text.strip().title(), "%b %d, %Y"
                        ).strftime("%Y-%m-%d")
                        if is_valid_date(dt_str, ticker):
                            batch.append(
                                {
                                    "ticker": ticker,
                                    "nav": float(cells[7].text.replace(",", "")),
                                    "validity_date": dt_str,
                                    "source": "MUFAP",
                                }
                            )
                    except:
                        continue
        if batch:
            safe_batch = filter_protected_entries(batch, "daily_nav")
            if safe_batch:
                supabase.table("daily_nav").upsert(
                    safe_batch, on_conflict="ticker,validity_date"
                ).execute()
            print(f"   ✅ {len(batch)} MUFAP funds updated.")
    except Exception as e:
        print(f"   ❌ MUFAP Error: {e}")


# --- TASK E: UBL AMC (Priority Overwrite) ---
def sync_ubl_amc_refined():
    print("🏦 Syncing UBL AMC (Priority)...")

    def clean_text(text):
        if not text:
            return ""
        return (
            text.lower().replace("-", " ").replace("*", "").replace("  ", " ").strip()
        )

    ubl_map = {
        clean_text(r["amc_website_name"]): r["ticker"]
        for r in master_res.data
        if r.get("amc_website_name")
    }
    pension_map = {
        ("money market", 1): "UBLRSF-MMSF",
        ("debt", 1): "UBLRSF-DSF",
        ("equity", 1): "UBLRSF-ESF",
        ("commodity", 1): "UBLRSF-GSF",
        ("money market", 2): "ALAIRSF-MMSF",
        ("debt", 2): "ALAIRSF-DSF",
        ("equity", 2): "ALAIRSF-ESF",
    }

    batch = []
    try:
        url = "https://www.ublfunds.com.pk/resources-tools/fund-performance-tools/latest-fund-prices/"
        soup = BeautifulSoup(session.get(url, verify=False, timeout=15).text, "lxml")

        for table_id in [
            "conventional-mutual-fund-schemes",
            "islamic-mutual-fund-schemes",
        ]:
            table = soup.find("table", id=table_id)
            if not table:
                continue
            for row in table.find_all("tr"):
                cells = row.find_all("td")
                if len(cells) >= 4:
                    raw_name = cells[0].get_text(strip=True)
                    ticker = ubl_map.get(clean_text(raw_name))
                    if ticker:
                        try:
                            dt_str = datetime.strptime(
                                cells[1].text.strip(), "%d-%b-%Y"
                            ).strftime("%Y-%m-%d")
                            if is_valid_date(dt_str, ticker):
                                batch.append(
                                    {
                                        "ticker": ticker,
                                        "nav": float(cells[3].text.replace(",", "")),
                                        "validity_date": dt_str,
                                        "source": "AMC_Website",
                                    }
                                )
                        except:
                            continue

        pension_table = soup.find("table", id="pension-schemes")
        if pension_table:
            seen_counts = {}
            for row in pension_table.find_all("tr"):
                cells = row.find_all("td")
                if len(cells) >= 4:
                    raw_name = cells[0].get_text(strip=True).lower()
                    fund_type = None
                    if "money market" in raw_name:
                        fund_type = "money market"
                    elif "debt" in raw_name:
                        fund_type = "debt"
                    elif "equity" in raw_name:
                        fund_type = "equity"
                    elif "commodity" in raw_name:
                        fund_type = "commodity"

                    if fund_type:
                        seen_counts[fund_type] = seen_counts.get(fund_type, 0) + 1
                        ticker = pension_map.get((fund_type, seen_counts[fund_type]))
                        if ticker:
                            try:
                                dt_str = datetime.strptime(
                                    cells[1].text.strip(), "%d-%b-%Y"
                                ).strftime("%Y-%m-%d")
                                if is_valid_date(dt_str, ticker):
                                    batch.append(
                                        {
                                            "ticker": ticker,
                                            "nav": float(
                                                cells[3].text.replace(",", "")
                                            ),
                                            "validity_date": dt_str,
                                            "source": "AMC_Website",
                                        }
                                    )
                            except:
                                continue

        if batch:
            unique_batch = {
                (item["ticker"], item["validity_date"]): item for item in batch
            }
            final_batch = list(unique_batch.values())
            safe_batch = filter_protected_entries(final_batch, "daily_nav")
            if safe_batch:
                supabase.table("daily_nav").upsert(
                    safe_batch, on_conflict="ticker,validity_date"
                ).execute()
                print(
                    f"   ✅ {len(safe_batch)} UBL funds updated (Priority, including Pensions!)."
                )
    except Exception as e:
        print(f"   ❌ UBL Error: {e}")


# --- TASK E2: ABL AMC (Priority Overwrite) ---
def sync_abl_amc():
    print("🏦 Syncing ABL AMC (Priority)...")

    def clean_text(text):
        if not text:
            return ""
        return (
            text.lower().replace("-", " ").replace("*", "").replace("  ", " ").strip()
        )

    abl_map = {
        clean_text(r["amc_website_name"]): r["ticker"]
        for r in master_res.data
        if r.get("amc_website_name")
    }
    batch = []
    try:
        soup = BeautifulSoup(
            session.get("https://ablfunds.com/nav", verify=False, timeout=15).text,
            "lxml",
        )
        table = soup.find("table")
        if not table:
            return

        for row in table.find_all("tr"):
            cells = row.find_all("td")
            if len(cells) >= 5:
                ticker = abl_map.get(clean_text(cells[0].get_text(strip=True)))
                if ticker:
                    try:
                        dt_str = datetime.strptime(
                            cells[4].text.strip(), "%d-%b-%Y"
                        ).strftime("%Y-%m-%d")
                        if is_valid_date(dt_str, ticker):
                            nav_text = cells[1].text.replace(",", "").strip()
                            if nav_text:
                                batch.append(
                                    {
                                        "ticker": ticker,
                                        "nav": float(nav_text),
                                        "validity_date": dt_str,
                                        "source": "AMC_Website",
                                    }
                                )
                    except:
                        continue

        if batch:
            unique_batch = {
                (item["ticker"], item["validity_date"]): item for item in batch
            }
            safe_batch = filter_protected_entries(
                list(unique_batch.values()), "daily_nav"
            )
            if safe_batch:
                supabase.table("daily_nav").upsert(
                    safe_batch, on_conflict="ticker,validity_date"
                ).execute()
                print(f"   ✅ {len(safe_batch)} ABL funds updated (Priority).")
    except Exception as e:
        print(f"   ❌ ABL Error: {e}")


# --- TASK E3: NBP FUNDS (Priority Overwrite) ---
def sync_nbp_amc():
    print("🏦 Syncing NBP Funds (Priority)...")

    def clean_text(text):
        if not text:
            return ""
        return (
            text.lower().replace("-", " ").replace("*", "").replace("  ", " ").strip()
        )

    nbp_map = {
        clean_text(r["amc_website_name"]): r["ticker"]
        for r in master_res.data
        if r.get("amc_website_name")
    }
    batch = []
    try:
        soup = BeautifulSoup(
            session.get(
                "https://www.nbpfunds.com/fund-prices/fund-nav-view/",
                verify=False,
                timeout=15,
            ).text,
            "lxml",
        )
        table = soup.find("table")
        if not table:
            return

        for row in table.find_all("tr"):
            cells = row.find_all("td")
            if len(cells) >= 4:
                ticker = nbp_map.get(clean_text(cells[0].get_text(strip=True)))
                if ticker:
                    try:
                        raw_date = re.sub(r"\s+", " ", cells[3].text.strip())
                        dt_str = datetime.strptime(raw_date, "%b %d, %Y").strftime(
                            "%Y-%m-%d"
                        )
                        if is_valid_date(dt_str, ticker):
                            nav_text = cells[2].text.replace(",", "").strip()
                            if nav_text:
                                batch.append(
                                    {
                                        "ticker": ticker,
                                        "nav": float(nav_text),
                                        "validity_date": dt_str,
                                        "source": "AMC_Website",
                                    }
                                )
                    except:
                        continue

        if batch:
            unique_batch = {
                (item["ticker"], item["validity_date"]): item for item in batch
            }
            safe_batch = filter_protected_entries(
                list(unique_batch.values()), "daily_nav"
            )
            if safe_batch:
                supabase.table("daily_nav").upsert(
                    safe_batch, on_conflict="ticker,validity_date"
                ).execute()
                print(f"   ✅ {len(safe_batch)} NBP funds updated (Priority).")
    except Exception as e:
        print(f"   ❌ NBP Error: {e}")


# --- TASK E4: HBL AMC (Priority Overwrite) ---
def sync_hbl_amc():
    print("🏦 Syncing HBL AMC (Priority)...")

    def clean_text(text):
        if not text:
            return ""
        return (
            text.lower().replace("-", " ").replace("*", "").replace("  ", " ").strip()
        )

    hbl_map = {
        clean_text(r["amc_website_name"]): r["ticker"]
        for r in master_res.data
        if r.get("amc_website_name")
    }
    batch = []
    try:
        soup = BeautifulSoup(
            session.get(
                "https://hblasset.com/fund-prices/", verify=False, timeout=15
            ).text,
            "lxml",
        )
        table = soup.find("table")
        if not table:
            return

        for row in table.find_all("tr"):
            cells = row.find_all("td")
            if len(cells) >= 4:
                ticker = hbl_map.get(clean_text(cells[0].get_text(strip=True)))
                if ticker:
                    try:
                        raw_date = re.sub(r"\s+", " ", cells[3].text.strip())
                        dt_str = None
                        for fmt in [
                            "%d-%b-%Y",
                            "%d-%b-%y",
                            "%d-%B-%Y",
                            "%d/%m/%Y",
                            "%b %d, %Y",
                            "%B %d, %Y",
                            "%Y-%m-%d",
                        ]:
                            try:
                                dt_str = datetime.strptime(raw_date, fmt).strftime(
                                    "%Y-%m-%d"
                                )
                                break
                            except ValueError:
                                pass
                        if not dt_str:
                            continue

                        if is_valid_date(dt_str, ticker):
                            nav_text = cells[2].text.replace(",", "").strip()
                            if nav_text:
                                batch.append(
                                    {
                                        "ticker": ticker,
                                        "nav": float(nav_text),
                                        "validity_date": dt_str,
                                        "source": "AMC_Website",
                                    }
                                )
                    except:
                        continue

        if batch:
            unique_batch = {
                (item["ticker"], item["validity_date"]): item for item in batch
            }
            safe_batch = filter_protected_entries(
                list(unique_batch.values()), "daily_nav"
            )
            if safe_batch:
                supabase.table("daily_nav").upsert(
                    safe_batch, on_conflict="ticker,validity_date"
                ).execute()
                print(f"   ✅ {len(safe_batch)} HBL funds updated (Priority).")
    except Exception as e:
        print(f"   ❌ HBL Error: {e}")


# --- TASK F: MUFAP PAYOUTS ---
def sync_mufap_payouts():
    print("💸 Syncing MUFAP Payouts...")
    target_ids = {
        str(int(float(row["fund_id_mufap"])))
        for row in master_res.data
        if row.get("fund_id_mufap")
    }
    id_to_ticker = {
        str(int(float(row["fund_id_mufap"]))): row["ticker"]
        for row in master_res.data
        if row.get("fund_id_mufap")
    }

    batch = []
    try:
        soup = BeautifulSoup(
            session.get(
                "https://www.mufap.com.pk/Industry/IndustryStatDaily?tab=4",
                verify=False,
                timeout=15,
            ).text,
            "lxml",
        )
        for row in soup.find_all("tr"):
            cells = row.find_all("td")
            if len(cells) < 8:
                continue
            link = cells[2].find("a", href=True)
            if link and "FundID=" in link["href"]:
                m_id = re.search(r"FundID=(\d+)", link["href"]).group(1)
                if m_id in target_ids:
                    try:
                        payout_amount_str = cells[5].text.replace(",", "").strip()
                        ex_nav_str = cells[6].text.replace(",", "").strip()
                        raw_date = re.sub(r"\s+", " ", cells[7].text.strip())

                        if not payout_amount_str or payout_amount_str == "-":
                            continue
                        payout_amount = float(payout_amount_str)
                        ex_nav = (
                            float(ex_nav_str)
                            if ex_nav_str and ex_nav_str != "-"
                            else 0.0
                        )

                        dt_str = None
                        for fmt in [
                            "%b %d, %Y",
                            "%d-%b-%Y",
                            "%d-%b-%y",
                            "%d/%m/%Y",
                            "%B %d, %Y",
                        ]:
                            try:
                                dt_str = datetime.strptime(raw_date, fmt).strftime(
                                    "%Y-%m-%d"
                                )
                                break
                            except ValueError:
                                pass
                        if not dt_str:
                            continue

                        batch.append(
                            {
                                "ticker": id_to_ticker[m_id],
                                "payout_date": dt_str,
                                "payout_amount": payout_amount,
                                "ex_nav": ex_nav,
                                "source": "MUFAP",  # ADDED FOR HIERARCHY
                            }
                        )
                    except:
                        continue

        if batch:
            unique_batch = {
                (item["ticker"], item["payout_date"]): item for item in batch
            }
            final_batch = list(unique_batch.values())

            # Use the updated filter to protect MANUAL entries based on payout_date
            safe_batch = filter_protected_entries(
                final_batch, "payout_history", date_col="payout_date"
            )

            if safe_batch:
                supabase.table("payout_history").upsert(
                    safe_batch, on_conflict="ticker,payout_date"
                ).execute()
                print(f"   ✅ {len(safe_batch)} Payouts synced (Manual protected).")
    except Exception as e:
        print(f"   ❌ Payouts Error: {e}")


# --- TASK G: MUFAP TER ---
def sync_mufap_ter():
    print("📊 Syncing MUFAP TER...")
    target_ids = {
        str(int(float(row["fund_id_mufap"])))
        for row in master_res.data
        if row.get("fund_id_mufap")
    }
    id_to_ticker = {
        str(int(float(row["fund_id_mufap"]))): row["ticker"]
        for row in master_res.data
        if row.get("fund_id_mufap")
    }

    batch = []
    try:
        soup = BeautifulSoup(
            session.get(
                "https://www.mufap.com.pk/Industry/IndustryStatDaily?tab=5",
                verify=False,
                timeout=15,
            ).text,
            "lxml",
        )
        for row in soup.find_all("tr"):
            cells = row.find_all("td")
            if len(cells) < 10:
                continue
            link = cells[2].find("a", href=True)
            if link and "FundID=" in link["href"]:
                m_id = re.search(r"FundID=(\d+)", link["href"]).group(1)
                if m_id in target_ids:
                    try:
                        ter_mtd_str = (
                            cells[8].text.replace("%", "").replace(",", "").strip()
                        )
                        ter_ytd_str = (
                            cells[9].text.replace("%", "").replace(",", "").strip()
                        )
                        ter_mtd = (
                            float(ter_mtd_str)
                            if ter_mtd_str and ter_mtd_str != "-"
                            else 0.0
                        )
                        ter_ytd = (
                            float(ter_ytd_str)
                            if ter_ytd_str and ter_ytd_str != "-"
                            else 0.0
                        )
                        batch.append(
                            {
                                "ticker": id_to_ticker[m_id],
                                "ter_mtd": ter_mtd,
                                "ter_ytd": ter_ytd,
                            }
                        )
                    except:
                        continue

        if batch:
            supabase.table("performance_stats").upsert(
                batch, on_conflict="ticker"
            ).execute()
            print(f"   ✅ {len(batch)} TER stats synced.")
    except Exception as e:
        print(f"   ❌ TER Error: {e}")


# --- TASK H: CRYPTO DAILY ---
def sync_crypto_rates():
    print("🪙 Syncing Crypto (Daily Routine)...")
    try:
        batch = []
        for t in ["BTC-USD", "ETH-USD", "SOL-USD"]:
            data = yf.Ticker(t).history(period="5d")
            if not data.empty:
                clean_ticker = t.split("-")[0]
                for index, row in data.iterrows():
                    batch.append(
                        {
                            "ticker": clean_ticker,
                            "value": float(row["Close"]),
                            "validity_date": index.strftime("%Y-%m-%d"),
                            "source": "Yahoo Finance",
                        }
                    )

        if batch:
            safe_batch = filter_protected_entries(batch, "benchmarks")
            if safe_batch:
                supabase.table("benchmarks").upsert(
                    safe_batch, on_conflict="ticker,validity_date"
                ).execute()
                print(f"   ✅ {len(batch)} Recent Crypto rates synced.")
    except Exception as e:
        print(f"   ❌ Crypto Error: {e}")


# ==========================================
# Google Cloud Function Entry Point
# ==========================================
@functions_framework.http
def run_scraper(request):
    """HTTP Cloud Function to trigger the scraping tasks."""

    request_args = request.args
    target = request_args.get("target", "all").lower()

    start_time = datetime.now()
    print(f"🚀 Initializing Scraper via Google Cloud (Target: {target.upper()})")

    if target == "psx":
        sync_psx_indices()
        sync_psx_etfs()
    elif target == "mufap":
        sync_mufap_master()
        sync_ubl_amc_refined()
        sync_abl_amc()
        sync_nbp_amc()
        sync_hbl_amc()
    elif target == "gold_ter":
        sync_gold_rates()
        sync_international_gold()
        sync_mufap_payouts()
        sync_mufap_ter()
    elif target == "market":
        sync_psx_indices()
        sync_psx_etfs()
        sync_gold_rates()
        sync_international_gold()
        sync_crypto_rates()
    else:  # Default 'all'
        sync_psx_indices()
        sync_gold_rates()
        sync_international_gold()
        sync_psx_etfs()
        sync_mufap_master()
        sync_ubl_amc_refined()
        sync_abl_amc()
        sync_nbp_amc()
        sync_hbl_amc()
        sync_mufap_payouts()
        sync_mufap_ter()
        sync_crypto_rates()

    total_time = datetime.now() - start_time
    completion_msg = f"🎉 SYNC COMPLETE. Total Time: {total_time}"
    print(completion_msg)

    import requests
    import google.auth.transport.requests
    import google.oauth2.id_token

    # WAKE UP THE BRAIN SECURELY!
    print("🧠 Scraper finished. Generating IAM Token and Triggering Brain Engine...")
    target_audience = "https://bachat-brain-395873114094.us-central1.run.app"

    try:
        # 1. Generate a secure Google Cloud Identity Token
        auth_req = google.auth.transport.requests.Request()
        id_token = google.oauth2.id_token.fetch_id_token(auth_req, target_audience)

        # 2. Attach the token to the Authorization header
        headers = {"Authorization": f"Bearer {id_token}"}

        # 3. Fire the secure request
        requests.get(target_audience, headers=headers, timeout=1)

    except requests.exceptions.ReadTimeout:
        # The Brain takes a while to run, so a timeout is normal and expected.
        pass
    except Exception as e:
        print(f"   ⚠️ Could not trigger Brain securely: {e}")

    return completion_msg, 200
