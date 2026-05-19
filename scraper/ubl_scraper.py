import os
import re
import ssl
import cloudscraper
import urllib3
from bs4 import BeautifulSoup
from thefuzz import process
from supabase import create_client, Client

# Mute the SSL warnings
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# --- 1. SUPABASE CONNECTION ---
SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_KEY = os.environ.get("SUPABASE_KEY")

if not SUPABASE_URL or not SUPABASE_KEY:
    print("❌ ERROR: Supabase Keys are missing from Environment Variables!")
    exit(1)

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

# --- 2. CONFIGURATION ---
FMR_DATE = "2026-04-30"
FUZZY_THRESHOLD = 85

UBL_URLS = [
    "https://online.ublfunds.com/FMR/Funds/Islamic?Year=2026&Mon=Apr",
    "https://online.ublfunds.com/FMR/Funds/Conventional?Year=2026&Mon=Apr",
]

UBL_TARGET_FUNDS = {
    "AL-AMEEN ISLAMIC ASSET ALLOCATION FUND": "ALAIAAF",
    "AL-AMEEN ISLAMIC ENERGY FUND": "ALAIEF",
    "AL-AMEEN SHARIAH STOCK FUND": "ALASSF",
    "UBL ASSET ALLOCATION FUND": "UBLAAF",
    "UBL STOCK ADVANTAGE FUND": "UBLSAF",
    "UBL FINANCIAL SECTOR FUND": "UBLFSF",
}


def fetch_official_stocks():
    print("🔄 Fetching official PSX stock list from Supabase...")
    res = supabase.table("master_stocks").select("ticker, company_name").execute()
    mapping = {}
    for row in res.data:
        if row.get("company_name"):
            mapping[row["company_name"]] = row["ticker"]
    return mapping


# --- 3. HTML EXTRACTION ENGINE ---
def get_isolated_fund_soup(soup, fund_name):
    fund_name_clean = re.sub(r"[^a-z0-9]", "", fund_name.lower())
    start_tag = None

    for tag_name in ["h2", "h3", "h4", "h1", "strong", "div"]:
        for tag in soup.find_all(tag_name):
            text_clean = re.sub(r"[^a-z0-9]", "", tag.get_text(strip=True).lower())

            if (
                fund_name_clean in text_clean
                and len(text_clean) < len(fund_name_clean) + 30
            ):
                if not tag.find_parent(["nav", "header", "ul", "select", "table", "a"]):
                    start_tag = tag
                    break
        if start_tag:
            break

    if not start_tag:
        return None

    full_html = str(soup)
    start_idx = full_html.find(str(start_tag))
    end_idx = len(full_html)

    for other_name in UBL_TARGET_FUNDS.keys():
        if other_name.lower() == fund_name.lower():
            continue

        other_clean = re.sub(r"[^a-z0-9]", "", other_name.lower())
        for tag_name in ["h2", "h3", "h4", "h1", "strong", "div"]:
            for tag in soup.find_all(tag_name):
                text_clean = re.sub(r"[^a-z0-9]", "", tag.get_text(strip=True).lower())
                if (
                    other_clean in text_clean
                    and len(text_clean) < len(other_clean) + 30
                ):
                    if not tag.find_parent(
                        ["nav", "header", "ul", "select", "table", "a"]
                    ):
                        idx = full_html.find(str(tag))
                        if start_idx < idx < end_idx:
                            end_idx = idx
                            break

    chunk = full_html[start_idx:end_idx]
    return BeautifulSoup(chunk, "lxml")


def extract_metric(fund_soup, label_regex):
    for tr in fund_soup.find_all("tr"):
        cols = tr.find_all(["td", "th"])
        for i, col in enumerate(cols):
            text = col.get_text(separator=" ", strip=True)
            if re.search(label_regex, text, re.IGNORECASE):
                if i + 1 < len(cols):
                    val = cols[i + 1].get_text(separator=" ", strip=True)
                    if not val or val.lower() in ["-", "n/a", "nil", ""]:
                        return None
                    return val
    return None


def extract_ubl_fund_data(fund_soup, ticker):
    data = {"ticker": ticker}

    # 1. Core Metrics
    data["standard_deviation"] = extract_metric(fund_soup, r"Standard Deviation")
    data["sharpe_ratio"] = extract_metric(fund_soup, r"Sharpe Ratio")
    data["beta"] = extract_metric(fund_soup, r"Beta")
    data["info_ratio"] = extract_metric(fund_soup, r"Information Ratio")
    data["portfolio_turnover"] = extract_metric(fund_soup, r"Portfolio Turnover")
    data["ter_mtd"] = extract_metric(fund_soup, r"Total Expense Ratio.*?MTD")
    data["ter_ytd"] = extract_metric(fund_soup, r"Total Expense Ratio.*?FYTD")

    # 2. Loads (THE FIX: Wall-based Regex to strictly isolate Front vs Back)
    load_text = extract_metric(fund_soup, r"^Load")
    data["fel"], data["bel"] = None, None

    if load_text:
        # Looks backwards from "(Front" until it hits a pipe, comma, or parenthesis
        fel_match = re.search(r"([^\|\,\)]*?)\s*\(Front", load_text, re.IGNORECASE)
        if fel_match:
            data["fel"] = re.sub(
                r"^[\s\|,:;-]+|[\s\|,:;-]+$", "", fel_match.group(1)
            ).strip()

        # Looks backwards from "(Back" until it hits a pipe, comma, or parenthesis
        bel_match = re.search(r"([^\|\,\)]*?)\s*\(Back", load_text, re.IGNORECASE)
        if bel_match:
            data["bel"] = re.sub(
                r"^[\s\|,:;-]+|[\s\|,:;-]+$", "", bel_match.group(1)
            ).strip()

    # Fallback to direct row searches if the unified "Load" row doesn't exist
    if not data["fel"]:
        data["fel"] = extract_metric(fund_soup, r"Front[- ]?End")
    if not data["bel"]:
        data["bel"] = extract_metric(fund_soup, r"Back[- ]?End")

    # 3. Fund Manager
    manager_text = extract_metric(fund_soup, r"Fund Manager")
    if manager_text:
        eq_manager = re.search(
            r"([A-Za-z\s\.]+)\s*\((?:Equity|Asset Allocation|Balanced)",
            manager_text,
            re.IGNORECASE,
        )
        data["fund_manager"] = (
            eq_manager.group(1).strip()
            if eq_manager
            else manager_text.split("(")[0].strip()
        )
    else:
        data["fund_manager"] = None

    # 4. Top Equity Holdings
    holdings = []
    total_equity_percentage = 0.0
    equity_table = None

    for tag in fund_soup.find_all(True):
        if tag.name in ["script", "style", "nav"]:
            continue
        text = tag.get_text(separator=" ", strip=True).lower()
        if "equity holding" in text and len(text) < 50:
            equity_table = tag.find_parent("table") or tag.find_next("table")
            if equity_table:
                break

    if equity_table:
        for row in equity_table.find_all("tr"):
            cols = row.find_all(["td", "th"])
            if len(cols) >= 2:
                raw_company = cols[0].get_text(separator=" ", strip=True)
                val_text = (
                    cols[1]
                    .get_text(separator=" ", strip=True)
                    .replace("%", "")
                    .replace(",", "")
                )

                if raw_company.lower() in [
                    "company",
                    "company name",
                    "holding",
                    "holding %",
                    "name",
                    "asset",
                    "asset class",
                ]:
                    continue

                if raw_company and val_text and not raw_company.isnumeric():
                    try:
                        percentage = float(val_text)
                        total_equity_percentage += percentage
                        holdings.append(
                            {
                                "company_name_raw": raw_company,
                                "holding_percentage": percentage,
                            }
                        )
                    except ValueError:
                        continue
    data["top_holdings"] = holdings

    # 5. Asset Allocation (Cash + GOP + Term Finance)
    asset_table = None
    cash_total = 0.0

    for tag in fund_soup.find_all(True):
        if tag.name in ["script", "style", "nav"]:
            continue
        text = tag.get_text(separator=" ", strip=True).lower()
        if "asset allocation" in text and len(text) < 50:
            candidate_table = tag.find_parent("table") or tag.find_next("table")
            if (
                candidate_table
                and "cash"
                in candidate_table.get_text(separator=" ", strip=True).lower()
            ):
                asset_table = candidate_table
                break

    if asset_table:
        for row in asset_table.find_all("tr"):
            cols = row.find_all(["td", "th"])
            if len(cols) >= 2:
                asset_type = cols[0].get_text(separator=" ", strip=True).lower()
                val_text = (
                    cols[1]
                    .get_text(separator=" ", strip=True)
                    .replace("%", "")
                    .replace(",", "")
                )

                keywords = [
                    "cash",
                    "ijarah sukuk",
                    "finance certificates",
                    "term finance",
                ]
                if any(kw in asset_type for kw in keywords):
                    try:
                        cash_total += float(val_text)
                    except ValueError:
                        pass

    data["cash_percentage"] = round(cash_total, 2)
    data["other_percentage"] = round(
        100.0 - total_equity_percentage - data["cash_percentage"], 2
    )

    return data


def clean_float(val):
    if val is None or val == "":
        return None
    if isinstance(val, float):
        return val
    match = re.search(r"[-+]?\d*\.\d+|\d+", str(val).replace(",", ""))
    return float(match.group()) if match else None


# --- 4. MAIN RUNNER ---
def run_ubl_fmr():
    print("🚀 Firing up the UBL Funds Processing Engine...")
    official_stocks_dict = fetch_official_stocks()
    official_company_names = list(official_stocks_dict.keys())

    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE

    scraper = cloudscraper.create_scraper(
        browser={"browser": "chrome", "platform": "windows", "desktop": True},
        delay=5,
        ssl_context=ctx,
    )

    extracted_results = []
    targets_left = UBL_TARGET_FUNDS.copy()

    for url in UBL_URLS:
        print(f"\n📥 Fetching UBL FMR Page: {url}")
        response = scraper.get(url, timeout=30, verify=False)

        if response.status_code != 200:
            print(f"❌ Failed to load {url}")
            continue

        soup = BeautifulSoup(response.text, "lxml")

        for fund_name, ticker in list(targets_left.items()):
            fund_soup = get_isolated_fund_soup(soup, fund_name)

            if fund_soup:
                print(f"   🎯 Found and Isolated {ticker}...")

                fund_data = extract_ubl_fund_data(fund_soup, ticker)
                print(
                    f"      - Captured {len(fund_data['top_holdings'])} Equity Holdings"
                )
                extracted_results.append(fund_data)
                del targets_left[fund_name]

    print("\n" + "=" * 50)
    print("💾 PREPARING DATABASE BATCH...")
    print("=" * 50)

    holdings_batch = []
    stats_batch = []

    for res in extracted_results:
        ticker = res["ticker"]

        stats_batch.append(
            {
                "ticker": ticker,
                "standard_deviation": clean_float(res.get("standard_deviation")),
                "sharpe_ratio": clean_float(res.get("sharpe_ratio")),
                "beta": clean_float(res.get("beta")),
                "info_ratio": clean_float(res.get("info_ratio")),
                "portfolio_turnover": clean_float(res.get("portfolio_turnover")),
                "ter_mtd": clean_float(res.get("ter_mtd")),
                "ter_ytd": clean_float(res.get("ter_ytd")),
                "fel": str(res.get("fel")) if res.get("fel") else None,
                "bel": str(res.get("bel")) if res.get("bel") else None,
                "fund_manager": (
                    str(res.get("fund_manager")) if res.get("fund_manager") else None
                ),
            }
        )

        for h in res["top_holdings"]:
            raw_name = h["company_name_raw"]
            best_match, score = process.extractOne(raw_name, official_company_names)

            if score >= FUZZY_THRESHOLD:
                stock_ticker = official_stocks_dict[best_match]
                print(
                    f"   🔍 Mapped: '{raw_name}' -> {stock_ticker} (Confidence: {score}%)"
                )
                holdings_batch.append(
                    {
                        "fund_ticker": ticker,
                        "stock_ticker": stock_ticker,
                        "holding_percentage": h["holding_percentage"],
                        "fmr_date": FMR_DATE,
                    }
                )
            else:
                print(
                    f"   🚨 UNMAPPED: '{raw_name}'. Best guess: '{best_match}' (Score: {score}%)"
                )

        if res.get("cash_percentage", 0) > 0:
            holdings_batch.append(
                {
                    "fund_ticker": ticker,
                    "stock_ticker": "CASH",
                    "holding_percentage": res.get("cash_percentage"),
                    "fmr_date": FMR_DATE,
                }
            )
        if res.get("other_percentage", 0) > 0:
            holdings_batch.append(
                {
                    "fund_ticker": ticker,
                    "stock_ticker": "OTHER",
                    "holding_percentage": res.get("other_percentage"),
                    "fmr_date": FMR_DATE,
                }
            )

    if not stats_batch:
        print("⚠️ No data was successfully processed.")
        return

    # PUSH TO SUPABASE
    if stats_batch:
        supabase.table("performance_stats").upsert(
            stats_batch, on_conflict="ticker"
        ).execute()
        print(f"\n✅ Upserted stats for {len(stats_batch)} funds.")

    if holdings_batch:
        unique_holdings = {}
        for h in holdings_batch:
            key = (h["fund_ticker"], h["stock_ticker"], h["fmr_date"])
            if (
                key not in unique_holdings
                or h["holding_percentage"] > unique_holdings[key]["holding_percentage"]
            ):
                unique_holdings[key] = h

        final_batch = list(unique_holdings.values())
        supabase.table("fund_holdings").upsert(
            final_batch, on_conflict="fund_ticker,stock_ticker,fmr_date"
        ).execute()
        print(f"✅ Deduped and Inserted {len(final_batch)} holdings into database.")


if __name__ == "__main__":
    run_ubl_fmr()
