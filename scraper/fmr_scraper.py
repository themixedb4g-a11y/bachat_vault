import os
import io
import re
import cloudscraper
import pdfplumber
from bs4 import BeautifulSoup
from thefuzz import process  # The Fuzzy Matching Engine
from supabase import create_client, Client

# --- 1. CONNECTION ---
try:
    from dotenv import load_dotenv

    load_dotenv()
except ImportError:
    pass  # Google Cloud ignores this safely!

SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_KEY = os.environ.get("SUPABASE_KEY")

if not SUPABASE_URL or not SUPABASE_KEY:
    raise ValueError("❌ Connection Error: Keys missing.")

supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

# --- 2. CONFIGURATION ---
MEEZAN_TARGET_FUNDS = {
    "Meezan Islamic Fund": "MIF",
    "Al Meezan Mutual Fund": "AMMF",
    "Meezan Dedicated Equity Fund": "MDEF",
    "Meezan Energy Fund": "MEF",
    "Meezan Asset Allocation Fund": "MAAF",
    "Meezan Dynamic Asset Allocation Fund": "MDAAF",
    "Meezan Balanced Fund": "MBF",  # <-- Added MBF back into the target list
}

FMR_DATE = "2026-04-30"
FUZZY_THRESHOLD = 85  # Minimum confidence score (0-100) to auto-map a stock


# --- 3. THE SCRUBBER & FUZZY MAPPER ---
def clean_company_name(raw_name):
    """Scrub out left-column text that bleeds into the company names."""
    bleed_ins = [
        "Fund Manager Muhammad Asad",
        "Fund Manager",
        "Investment Committee",
        "Pricing Mechanism Forward",
        "Pricing Mechanism",
        "Actual Rate of Management Fee",
        "Management Fee",
        "Front End Load",
        "Back End Load",
        "Trustee",
        "Auditor",
        "AMC Rating",
        "Rating Agency",
        "Unit Type",
        "Leverage",
        "Valuation Days",
        "Subscription",
        "Forward",
    ]
    for bleed in bleed_ins:
        if bleed.lower() in raw_name.lower():
            raw_name = re.split(re.escape(bleed), raw_name, flags=re.IGNORECASE)[-1]
    return raw_name.strip()


def fetch_official_stocks():
    """Fetch master_stocks to build our target matching dictionary."""
    print("🔄 Fetching official PSX stock list from Supabase...")
    res = supabase.table("master_stocks").select("ticker, company_name").execute()

    mapping = {}
    for row in res.data:
        if row.get("company_name"):
            mapping[row["company_name"]] = row["ticker"]
    return mapping


# --- 4. THE EXTRACTION ENGINE ---
def extract_fund_data(text, ticker):
    data = {"ticker": ticker}

    # The Footnote Eraser
    text_clean = re.split(r"(?i)Please be advised that the Sales Load", text)[0]

    # 1. Core Metrics
    std_dev = re.search(r"Standard Deviation\s+([\d\.]+)", text_clean)
    sharpe = re.search(r"Sharpe Ratio\s+([-\d\.]+)", text_clean)
    beta = re.search(r"Beta\s+([-\d\.]+)", text_clean)
    info_ratio = re.search(r"Information Ratio\s+([-\d\.]+)", text_clean)
    turnover = re.search(r"Portfolio Turnover(?: Ratio)?\s+([\d\.]+)", text_clean)

    ter_match = re.search(
        r"Expense Ratio \* Mtd \|\s*([\d\.]+)%\s*Ytd \|\s*([\d\.]+)%", text_clean
    )
    data["ter_mtd"] = float(ter_match.group(1)) if ter_match else None
    data["ter_ytd"] = float(ter_match.group(2)) if ter_match else None

    # 2. Load Metrics
    fel_start = re.search(r"(?i)front\s*[-]?\s*end\s*load", text_clean)
    if fel_start:
        chunk = text_clean[fel_start.end() : fel_start.end() + 100]
        chunk = re.split(r"(?i)\n|back\s*[-]?\s*end|leverage|valuation", chunk)[
            0
        ].strip()
        chunk = re.sub(r"^[:\s]+", "", chunk)

        pct = re.search(r"(?i)(Upto\s+[\d\.]+%|[\d\.-]+%|Nil)", chunk.replace(" ", ""))
        if pct:
            data["fel"] = (
                pct.group(1).capitalize()
                if "nil" in pct.group(1).lower()
                else pct.group(1)
            )
        else:
            data["fel"] = chunk.split("%")[0] + "%" if "%" in chunk else chunk
    else:
        data["fel"] = None

    bel_start = re.search(r"(?i)back\s*[-]?\s*end\s*load", text_clean)
    if bel_start:
        chunk = text_clean[bel_start.end() : bel_start.end() + 100]
        chunk = re.split(
            r"(?i)\n|leverage|valuation|management|pricing|eexxppeennses", chunk
        )[0].strip()
        chunk = re.sub(r"^[:\s]+", "", chunk)

        if "nil" in chunk.lower():
            data["bel"] = "Nil"
        else:
            data["bel"] = re.sub(r"(?:\s*\d){5,}.*", "", chunk).strip()
    else:
        data["bel"] = None

    # MDEF VERTICAL BLENDER BYPASS
    if ticker == "MDEF" and not data["bel"]:
        if "Class B" in text_clean:
            data["bel"] = "2%"

    # 3. Fund Manager
    manager = re.search(
        r"Fund Manager\s+(.*?)(?=\n|Investment Committee|Actual)",
        text_clean,
        re.IGNORECASE,
    )
    if manager:
        mgr_clean = manager.group(1).strip()
        mgr_clean = mgr_clean.split(",")[0].strip()
        mgr_clean = re.sub(
            r"(Oil|The Hub|Lucky|Mari|Fauji|Engro|Systems|Pakistan|Pricing).*",
            "",
            mgr_clean,
        ).strip()
        data["fund_manager"] = mgr_clean if len(mgr_clean) > 3 else None
    else:
        data["fund_manager"] = None

    data["standard_deviation"] = float(std_dev.group(1)) if std_dev else None
    data["sharpe_ratio"] = float(sharpe.group(1)) if sharpe else None
    data["beta"] = float(beta.group(1)) if beta else None
    data["info_ratio"] = float(info_ratio.group(1)) if info_ratio else None
    data["portfolio_turnover"] = float(turnover.group(1)) if turnover else None

    # 4. Holdings & Asset Allocation
    holdings = []
    total_equity_percentage = 0.0

    # THE FIX: Completely bypass Top Equity Holdings extraction for MBF
    if ticker != "MBF":
        start_idx = re.search(
            r"(Top|TToopp).*?(Holding|Hldoin|Hlodli|Equity|Equqiu|Asset|Asssse|Ten)",
            text_clean,
            re.IGNORECASE,
        )

        if start_idx:
            search_area = text_clean[start_idx.end() : start_idx.end() + 2500]

            for line in search_area.split("\n"):
                match = re.search(r"(.{10,})\s+([\d\.]+)(?:%)?\s*$", line.strip())
                if match:
                    raw_company = match.group(1).strip()
                    if "%" in raw_company:
                        raw_company = raw_company.split("%")[-1].strip()
                    if ")" in raw_company:
                        raw_company = raw_company.split(")")[-1].strip()

                    for delimiter in [
                        ") ",
                        "% ",
                        ", ",
                        "CFA ",
                        "Forward ",
                        "Friday ",
                        "Idrees ",
                    ]:
                        if delimiter in raw_company:
                            raw_company = raw_company.split(delimiter)[-1].strip()

                    raw_company = clean_company_name(raw_company)

                    if raw_company.isupper():
                        continue
                    if len(raw_company.split()) > 7:
                        continue
                    if re.search(r"\d,\d{3}", raw_company):
                        continue

                    bad_words = [
                        "return",
                        "average",
                        "ratio",
                        "asset",
                        "equity",
                        "cash",
                        "total",
                        "allocation",
                        "month",
                        "year",
                        "dividend",
                        "category",
                        "page",
                        "beta",
                        "kse",
                        "index",
                        "turnover",
                        "deviation",
                        "sharpe",
                        "peer",
                        "mar'",
                        "apr'",
                        "may'",
                        "jun'",
                        "jul'",
                        "aug'",
                        "sep'",
                        "oct'",
                        "nov'",
                        "dec'",
                        "jan'",
                        "feb'",
                        "reit",
                        "minimum",
                        "should",
                        "net",
                        "rs.",
                    ]

                    if (
                        not any(bw in raw_company.lower() for bw in bad_words)
                        and len(raw_company) > 3
                        and not raw_company.replace(".", "").isdigit()
                    ):
                        percentage = float(match.group(2))
                        total_equity_percentage += percentage
                        holdings.append(
                            {
                                "company_name_raw": raw_company,
                                "holding_percentage": percentage,
                            }
                        )

    data["top_holdings"] = holdings

    # 5. Extract Cash & Other Receivables (Still runs for MBF)
    cash_match = re.search(r"Cash\s+[\d\.]+%\s+([\d\.]+)%", text_clean)
    if not cash_match:
        cash_match = re.search(r"Cash\s+([\d\.]+)%", text_clean)
    cash_val = float(cash_match.group(1)) if cash_match else 0.0

    other_rec_match = re.search(
        r"Other Receivables\s+[\d\.]+%\s+([\d\.]+)%", text_clean
    )
    if not other_rec_match:
        other_rec_match = re.search(r"Other Receivables\s+([\d\.]+)%", text_clean)
    other_rec_val = float(other_rec_match.group(1)) if other_rec_match else 0.0

    data["cash_percentage"] = round(cash_val + other_rec_val, 2)
    data["other_percentage"] = round(
        100.0 - total_equity_percentage - data["cash_percentage"], 2
    )

    return data


# --- 5. MAIN EXECUTION ---
def run_al_meezan_fmr():
    print("🚀 Firing up the Enterprise FMR Processing Engine...")

    official_stocks_dict = fetch_official_stocks()
    official_company_names = list(official_stocks_dict.keys())

    scraper = cloudscraper.create_scraper(
        browser={"browser": "chrome", "platform": "windows", "desktop": True}, delay=10
    )
    url = "https://www.almeezangroup.com/download-category/fund-manager-reports/"

    try:
        response = scraper.get(url, timeout=30)
        if response.status_code != 200:
            print("❌ Failed to access FMR page.")
            return

        soup = BeautifulSoup(response.text, "lxml")
        links = soup.find_all("a", href=True)
        pdf_links = [link["href"] for link in links if ".pdf" in link["href"].lower()]

        if not pdf_links:
            return

        latest_pdf_url = pdf_links[0]
        print(f"📥 Downloading FMR: {latest_pdf_url.split('/')[-1]}...")

        pdf_response = scraper.get(latest_pdf_url, timeout=45)
        extracted_results = []
        targets_left = MEEZAN_TARGET_FUNDS.copy()

        with pdfplumber.open(io.BytesIO(pdf_response.content)) as pdf:
            for i, page in enumerate(pdf.pages):
                text = page.extract_text()
                if not text:
                    continue

                for fund_name, ticker in list(targets_left.items()):
                    if (
                        fund_name in text
                        and "Fund Type" in text
                        and "Launch Date" in text
                    ):
                        print(f"   🎯 Extracted {ticker} (Page {i+1})")
                        extracted_results.append(extract_fund_data(text, ticker))
                        del targets_left[fund_name]
                        break
                if not targets_left:
                    break

        print("\n" + "=" * 50)
        print("💾 PUSHING TO SUPABASE DATABASE...")
        print("=" * 50)

        holdings_batch = []

        for res in extracted_results:
            ticker = res["ticker"]

            # Update Performance Stats
            stats_payload = {
                "standard_deviation": res.get("standard_deviation"),
                "sharpe_ratio": res.get("sharpe_ratio"),
                "beta": res.get("beta"),
                "info_ratio": res.get("info_ratio"),
                "portfolio_turnover": res.get("portfolio_turnover"),
                "ter_mtd": res.get("ter_mtd"),
                "ter_ytd": res.get("ter_ytd"),
                "fel": res.get("fel"),
                "bel": res.get("bel"),
                "fund_manager": res.get("fund_manager"),
            }

            if stats_payload["beta"] is None and ticker != "MBF":
                print(
                    f"   ⚠️ WARNING: Core metrics missing for {ticker}. Skipping stats update."
                )
            else:
                # Upsert is safer here, changing from update() to upsert() to ensure it inserts if missing
                payload_with_ticker = stats_payload.copy()
                payload_with_ticker["ticker"] = ticker
                supabase.table("performance_stats").upsert(
                    payload_with_ticker, on_conflict="ticker"
                ).execute()

            # Prepare Holdings Batch (Completely skipped for MBF)
            if ticker != "MBF":
                for h in res["top_holdings"]:
                    raw_name = h["company_name_raw"]

                    best_match, score = process.extractOne(
                        raw_name, official_company_names
                    )

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
                            f"   🚨 UNMAPPED: '{raw_name}'. Best guess was '{best_match}' (Score: {score}%). Too low!"
                        )

                # Add CASH and OTHER
                if res.get("cash_percentage", 0) > 0:
                    holdings_batch.append(
                        {
                            "fund_ticker": ticker,
                            "stock_ticker": "CASH",
                            "holding_percentage": res["cash_percentage"],
                            "fmr_date": FMR_DATE,
                        }
                    )
                if res.get("other_percentage", 0) > 0:
                    holdings_batch.append(
                        {
                            "fund_ticker": ticker,
                            "stock_ticker": "OTHER",
                            "holding_percentage": res["other_percentage"],
                            "fmr_date": FMR_DATE,
                        }
                    )

        if holdings_batch:
            unique_holdings = {}
            for h in holdings_batch:
                key = (h["fund_ticker"], h["stock_ticker"], h["fmr_date"])

                if (
                    key not in unique_holdings
                    or h["holding_percentage"]
                    > unique_holdings[key]["holding_percentage"]
                ):
                    unique_holdings[key] = h

            final_batch = list(unique_holdings.values())

            supabase.table("fund_holdings").upsert(
                final_batch, on_conflict="fund_ticker,stock_ticker,fmr_date"
            ).execute()
            print(
                f"\n✅ Successfully Deduped and Inserted {len(final_batch)} holdings into database."
            )

    except Exception as e:
        print(f"❌ Error occurred: {e}")


if __name__ == "__main__":
    run_al_meezan_fmr()
