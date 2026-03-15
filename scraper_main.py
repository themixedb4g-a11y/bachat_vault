import os
import requests
from bs4 import BeautifulSoup
from lxml import html
import re
from supabase import create_client
from datetime import datetime
import pytz
import urllib3
import argparse
import sys
from concurrent.futures import ThreadPoolExecutor
import yfinance as yf

session = requests.Session()
session.headers.update({'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'})

# Suppress SSL Warnings
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# --- 1. CONNECTION ---
SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_KEY = os.environ.get("SUPABASE_KEY")

if not SUPABASE_URL or not SUPABASE_KEY:
    print("❌ ERROR: Supabase Keys are missing from GitHub Secrets!")
    sys.exit(1)
supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

# --- PRE-FETCH FUND MASTER DATA FOR GUARDRAILS ---
# We fetch this once globally so all tasks can access the logic and categories
master_res = supabase.table("master_funds").select("ticker, category, return_logic, fund_id_mufap, amc_website_name").execute()
FUND_LOGIC_MAP = {row['ticker']: row.get('return_logic', 'Absolute') for row in master_res.data}
FUND_CATEGORY_MAP = {row['ticker']: row.get('category', '') for row in master_res.data}

# --- THE GUARDRAILS ---
def is_valid_date(date_str, ticker):
    try:
        dt = datetime.strptime(date_str, '%Y-%m-%d').date()
        today_pk = datetime.now(pytz.timezone('Asia/Karachi')).date()
        
        # Determine the logic. If it's not in the map, default to strict 'Absolute' to be safe.
        ticker_logic = FUND_LOGIC_MAP.get(ticker, 'Absolute')
        
        # RULE 1: Annualized funds accrue daily. They are immune to future/weekend blocks.
        if ticker_logic == 'Annualized':
            return True
            
        # RULE 2: Absolute funds must pass the strict tests.
        if ticker_logic == 'Absolute':
            
            # Guardrail A: Block Future Dates (No Absolute fund can predict tomorrow)
            if dt > today_pk:
                print(f"   🛡️ Guardrail active: Skipped {ticker} (Future Date {dt})")
                return False
                
            # Guardrail B: Block Weekends, EXCEPT for our VIP 24/7/Static list
            weekend_exceptions = ['BTC', 'ETH', 'SOL', 'BTC-USD', 'ETH-USD', 'SOL-USD', 'CPI_PK', 'GOLD_24K']
            
            if dt.weekday() >= 5 and ticker not in weekend_exceptions:
                print(f"   🛡️ Guardrail active: Skipped {ticker} (Weekend Date {dt})")
                return False
                
        # If it passed all the tests (or was a VIP on a weekend), let it through!
        return True
        
    except Exception as e:
        print(f"   ⚠️ Date parsing error for {ticker}: {e}")
        return False

def filter_manual_entries(batch, table_name):
    """Checks the database and removes any items from the batch that were manually updated."""
    if not batch: return []
    try:
        # Grab all the unique dates currently in our scraper's hands
        dates = list(set([item['validity_date'] for item in batch]))
        
        # Ask Supabase which of these dates were updated manually
        res = supabase.table(table_name).select('ticker, validity_date')\
            .in_('validity_date', dates)\
            .ilike('source', '%Manual%').execute() # Uses ilike to catch "Manual" or "manual"
            
        # Create a fast lookup set of the manual items
        manual_set = {(r['ticker'], r['validity_date']) for r in res.data}
        
        # Build a new batch that ONLY includes items NOT in the manual set
        filtered_batch = [item for item in batch if (item['ticker'], item['validity_date']) not in manual_set]
        
        skipped = len(batch) - len(filtered_batch)
        if skipped > 0:
            print(f"   🛡️ Protected {skipped} manually updated records from being overwritten.")
            
        return filtered_batch
    except Exception as e:
        print(f"   ⚠️ Could not check manual entries, proceeding carefully: {e}")
        return batch

# --- TASK A: PSX INDICES ---
def sync_psx_indices():
    print("📈 Syncing PSX Indices...")
    try:
        response = session.get("https://dps.psx.com.pk", timeout=15)
        tree = html.fromstring(response.content)
        raw_date_text = tree.xpath("//div[@class='market-status']//span/text()")
        web_date = next((datetime.strptime(re.search(r'[A-Z][a-z]{2}\s\d{2},\s\d{4}', item).group(), '%b %d, %Y').strftime('%Y-%m-%d') 
                         for item in raw_date_text if re.search(r'[A-Z][a-z]{2}\s\d{2},\s\d{4}', item)), 
                        datetime.now(pytz.timezone('Asia/Karachi')).strftime('%Y-%m-%d'))

        batch = []
        for ticker, xp_idx in [('KSE100', 1), ('KMI30', 5)]:
            result = tree.xpath(f"//*[@id='indicesTabs']/div[2]/div[{xp_idx}]/h1")
            if result:
                val = float(result[0].text_content().strip().replace(',', '').split(' ')[0])
                batch.append({"ticker": ticker, "value": val, "validity_date": web_date, "source": "PSX"})
        
        if batch:

            safe_batch = filter_manual_entries(batch, "benchmarks")
            
            if safe_batch:
                supabase.table("benchmarks").upsert(safe_batch, on_conflict="ticker,validity_date").execute()
            print(f"   ✅ PSX Indices updated.")
    except Exception as e: print(f"   ❌ PSX Error: {e}")

# --- TASK B: GOLD ---
def sync_gold_rates():
    print("💰 Syncing Gold...")
    try:
        soup = BeautifulSoup(session.get("https://gold.pk/gold-rates-pakistan.php", timeout=15).text, 'lxml')
        gold_el = soup.find('p', class_='goldratehome')
        if gold_el:
            val = float(re.search(r'(\d+\.\d+|\d+)', gold_el.text.replace('Rs.', '').replace(',', '')).group(1))
            if val > 1000000: val = float(str(int(val))[:6])
            today_pk = datetime.now(pytz.timezone('Asia/Karachi')).strftime('%Y-%m-%d')
            
            # Format as a list containing one dictionary
            gold_data = [{"ticker": "GOLD_24K", "value": val, "validity_date": today_pk, "source": "Gold.pk"}]
            safe_batch = filter_manual_entries(gold_data, "benchmarks")
            
            if safe_batch:
                supabase.table("benchmarks").upsert(safe_batch, on_conflict="ticker,validity_date").execute()
                print(f"   ✅ Gold updated.")
    except Exception as e: print(f"   ❌ Gold Error: {e}")

# --- TASK C: PSX ETFs ---
def fetch_etf(ticker):
    try:
        soup = BeautifulSoup(session.get(f"https://dps.psx.com.pk/etf/{ticker}", timeout=10).text, 'lxml')
        price = float(re.findall(r'\d+\.\d+', soup.find('div', class_='quote__price').text)[0])
        date_match = re.search(r'[A-Z][a-z]{2}\s\d{2},\s\d{4}', soup.find('div', class_='quote__date').text).group()
        web_date = datetime.strptime(date_match, '%b %d, %Y').strftime('%Y-%m-%d')
        
        # Guardrail Check for ETFs
        if is_valid_date(web_date, ticker):
            return {"ticker": ticker, "nav": price, "validity_date": web_date, "source": "PSX"}
        return None
    except: return None

def sync_psx_etfs():
    print("📊 Syncing ETFs from PSX...")
    
    psx_etf_tickers = []
    for ticker, category in FUND_CATEGORY_MAP.items():
        if 'Exchange Traded Fund' in str(category):
            if FUND_LOGIC_MAP.get(ticker) != 'Annualized':
                psx_etf_tickers.append(ticker)

    with ThreadPoolExecutor(max_workers=8) as executor:
        results = list(filter(None, executor.map(fetch_etf, psx_etf_tickers)))
        
    if results:
        # Pass 'results' into the filter instead of 'batch'
        safe_batch = filter_manual_entries(results, "daily_nav")
        
        if safe_batch:
            supabase.table("daily_nav").upsert(safe_batch, on_conflict="ticker,validity_date").execute()
            print(f"   ✅ {len(safe_batch)} ETFs updated from PSX.")

# --- TASK D: TARGETED MUFAP ---
def sync_mufap_master():
    print("🏛️ Syncing MUFAP (Targeted)...")
    
    # Guardrail 3 Enforcement: Identify ETFs that MUST be scraped from PSX (Absolute Logic)
    psx_exclusive_etfs = set()
    for ticker, category in FUND_CATEGORY_MAP.items():
        if 'Exchange Traded Fund' in str(category) and FUND_LOGIC_MAP.get(ticker) != 'Annualized':
            psx_exclusive_etfs.add(ticker)

    target_ids = {str(int(float(row['fund_id_mufap']))) for row in master_res.data if row.get('fund_id_mufap') and row['ticker'] not in psx_exclusive_etfs}
    id_to_ticker = {str(int(float(row['fund_id_mufap']))): row['ticker'] for row in master_res.data if row.get('fund_id_mufap') and row['ticker'] not in psx_exclusive_etfs}
    
    batch = []
    try:
        soup = BeautifulSoup(session.get("https://www.mufap.com.pk/Industry/IndustryStatDaily?tab=3", verify=False, timeout=15).text, 'lxml')
        for row in soup.find_all('tr'):
            cells = row.find_all('td')
            if len(cells) < 9: continue
            link = cells[2].find('a', href=True)
            if link:
                m_id = re.search(r'FundID=(\d+)', link['href']).group(1)
                if m_id in target_ids:
                    ticker = id_to_ticker[m_id]
                    try:
                        dt_str = datetime.strptime(cells[8].text.strip().title(), '%b %d, %Y').strftime('%Y-%m-%d')
                        if is_valid_date(dt_str, ticker):
                            batch.append({"ticker": ticker, "nav": float(cells[7].text.replace(',', '')), "validity_date": dt_str, "source": "MUFAP"})
                    except: continue
        if batch:
            safe_batch = filter_manual_entries(batch, "daily_nav")
            
            if safe_batch:
                supabase.table("daily_nav").upsert(safe_batch, on_conflict="ticker,validity_date").execute()
            print(f"   ✅ {len(batch)} MUFAP funds updated.")
    except Exception as e: print(f"   ❌ MUFAP Error: {e}")

# --- TASK E: UBL AMC (Priority Overwrite) ---
def sync_ubl_amc_refined():
    print("🏦 Syncing UBL AMC (Priority)...")
    
    # Helper function to remove dashes, asterisks, and make text lowercase for perfect matching
    def clean_text(text):
        if not text: return ""
        return text.lower().replace('-', ' ').replace('*', '').replace('  ', ' ').strip()
    
    # Standard map for Conventional & Islamic tables (Now fuzzy-matched!)
    ubl_map = {clean_text(r['amc_website_name']): r['ticker'] for r in master_res.data if r.get('amc_website_name')}
    
    # Custom map for Pension funds (Simplified to just keywords)
    pension_map = {
        ('money market', 1): 'UBLRSF-MMSF',
        ('debt', 1): 'UBLRSF-DSF',
        ('equity', 1): 'UBLRSF-ESF',
        ('commodity', 1): 'UBLRSF-GSF',
        ('money market', 2): 'ALAIRSF-MMSF',
        ('debt', 2): 'ALAIRSF-DSF',
        ('equity', 2): 'ALAIRSF-ESF'
    }
    
    batch = []
    try:
        url = "https://www.ublfunds.com.pk/resources-tools/fund-performance-tools/latest-fund-prices/"
        soup = BeautifulSoup(session.get(url, verify=False, timeout=15).text, 'lxml')
        
        # --- 1. Process Normal Tables (Conventional & Islamic) ---
        for table_id in ['conventional-mutual-fund-schemes', 'islamic-mutual-fund-schemes']:
            table = soup.find('table', id=table_id)
            if not table: continue
            for row in table.find_all('tr'):
                cells = row.find_all('td')
                if len(cells) >= 4:
                    raw_name = cells[0].get_text(strip=True)
                    # Use our clean_text function to bypass typos
                    ticker = ubl_map.get(clean_text(raw_name))
                    if ticker:
                        try:
                            dt_str = datetime.strptime(cells[1].text.strip(), '%d-%b-%Y').strftime('%Y-%m-%d')
                            if is_valid_date(dt_str, ticker):
                                batch.append({"ticker": ticker, "nav": float(cells[3].text.replace(',', '')), "validity_date": dt_str, "source": "AMC_Website"})
                        except: continue

        # --- 2. Process Pension Table (Using Keyword extraction) ---
        pension_table = soup.find('table', id='pension-schemes')
        if pension_table:
            seen_counts = {} 
            
            for row in pension_table.find_all('tr'):
                cells = row.find_all('td')
                if len(cells) >= 4:
                    raw_name = cells[0].get_text(strip=True).lower()
                    
                    # Look for the keywords inside the messy text
                    fund_type = None
                    if 'money market' in raw_name: fund_type = 'money market'
                    elif 'debt' in raw_name: fund_type = 'debt'
                    elif 'equity' in raw_name: fund_type = 'equity'
                    elif 'commodity' in raw_name: fund_type = 'commodity'
                    
                    if fund_type:
                        seen_counts[fund_type] = seen_counts.get(fund_type, 0) + 1
                        occurrence = seen_counts[fund_type]
                        ticker = pension_map.get((fund_type, occurrence))
                        
                        if ticker:
                            try:
                                dt_str = datetime.strptime(cells[1].text.strip(), '%d-%b-%Y').strftime('%Y-%m-%d')
                                if is_valid_date(dt_str, ticker):
                                    batch.append({"ticker": ticker, "nav": float(cells[3].text.replace(',', '')), "validity_date": dt_str, "source": "AMC_Website"})
                            except: continue

        # --- Final Push to Supabase (Task E Bottom Part) ---
        if batch:
            unique_batch = { (item['ticker'], item['validity_date']): item for item in batch }
            final_batch = list(unique_batch.values())
            
            # Filter the final_batch right here
            safe_batch = filter_manual_entries(final_batch, "daily_nav")
            
            if safe_batch:
                supabase.table("daily_nav").upsert(safe_batch, on_conflict="ticker,validity_date").execute()
                print(f"   ✅ {len(safe_batch)} UBL funds updated (Priority, including Pensions!).")
            
    except Exception as e: 
        print(f"   ❌ UBL Error: {e}")

# --- TASK F: MUFAP PAYOUTS ---
def sync_mufap_payouts():
    print("💸 Syncing MUFAP Payouts...")
    target_ids = {str(int(float(row['fund_id_mufap']))) for row in master_res.data if row.get('fund_id_mufap')}
    id_to_ticker = {str(int(float(row['fund_id_mufap']))): row['ticker'] for row in master_res.data if row.get('fund_id_mufap')}
    
    batch = []
    try:
        soup = BeautifulSoup(session.get("https://www.mufap.com.pk/Industry/IndustryStatDaily?tab=4", verify=False, timeout=15).text, 'lxml')
        for row in soup.find_all('tr'):
            cells = row.find_all('td')
            if len(cells) < 10: continue 
            
            link = cells[2].find('a', href=True)
            if link and 'FundID=' in link['href']:
                m_id = re.search(r'FundID=(\d+)', link['href']).group(1)
                
                if m_id in target_ids:
                    ticker = id_to_ticker[m_id]
                    try:
                        payout_amount_str = cells[7].text.replace(',', '').strip()
                        ex_nav_str = cells[8].text.replace(',', '').strip()
                        payout_date_str = cells[9].text.strip()
                        
                        if not payout_amount_str or payout_amount_str == '-': continue
                            
                        payout_amount = float(payout_amount_str)
                        ex_nav = float(ex_nav_str) if ex_nav_str and ex_nav_str != '-' else 0.0
                        dt_str = datetime.strptime(payout_date_str, '%b %d, %Y').strftime('%Y-%m-%d')
                        
                        batch.append({
                            "ticker": ticker, 
                            "payout_date": dt_str, 
                            "payout_amount": payout_amount,
                            "ex_nav": ex_nav
                        })
                    except: continue
                    
        if batch:
            # Reverted: No manual filter here because the key is 'payout_date', not 'validity_date'
            supabase.table("payout_history").upsert(batch, on_conflict="ticker,payout_date").execute()
            print(f"   ✅ {len(batch)} Payouts synced.")
            
    except Exception as e: 
        print(f"   ❌ Payouts Error: {e}")


# --- TASK G: MUFAP TER ---
def sync_mufap_ter():
    print("📊 Syncing MUFAP TER...")
    target_ids = {str(int(float(row['fund_id_mufap']))) for row in master_res.data if row.get('fund_id_mufap')}
    id_to_ticker = {str(int(float(row['fund_id_mufap']))): row['ticker'] for row in master_res.data if row.get('fund_id_mufap')}
    
    batch = []
    try:
        soup = BeautifulSoup(session.get("https://www.mufap.com.pk/Industry/IndustryStatDaily?tab=5", verify=False, timeout=15).text, 'lxml')
        for row in soup.find_all('tr'):
            cells = row.find_all('td')
            if len(cells) < 10: continue
            
            link = cells[2].find('a', href=True)
            if link and 'FundID=' in link['href']:
                m_id = re.search(r'FundID=(\d+)', link['href']).group(1)
                
                if m_id in target_ids:
                    ticker = id_to_ticker[m_id]
                    try:
                        ter_mtd_str = cells[8].text.replace('%', '').replace(',', '').strip()
                        ter_ytd_str = cells[9].text.replace('%', '').replace(',', '').strip()
                        
                        ter_mtd = float(ter_mtd_str) if ter_mtd_str and ter_mtd_str != '-' else 0.0
                        ter_ytd = float(ter_ytd_str) if ter_ytd_str and ter_ytd_str != '-' else 0.0
                        
                        batch.append({"ticker": ticker, "ter_mtd": ter_mtd, "ter_ytd": ter_ytd})
                    except: continue
                    
        if batch:
            # Reverted: No manual filter here because performance_stats has no dates or source column
            supabase.table("performance_stats").upsert(batch, on_conflict="ticker").execute()
            print(f"   ✅ {len(batch)} TER stats synced.")
            
    except Exception as e: 
        print(f"   ❌ TER Error: {e}")

# --- TASK: CRYPTO DAILY (Fast & Lean) ---
def sync_crypto_rates():
    print("🪙 Syncing Crypto (Daily Routine)...")
    try:
        tickers = ["BTC-USD", "ETH-USD", "SOL-USD"]
        batch = []
        
        for t in tickers:
            # We pull "5d" just to safely cover any long weekends or API hiccups. 
            # Supabase 'on_conflict' will smoothly ignore the duplicate days.
            data = yf.Ticker(t).history(period="5d")
            
            if not data.empty:
                clean_ticker = t.split('-')[0]
                for index, row in data.iterrows():
                    batch.append({
                        "ticker": clean_ticker, 
                        "value": float(row['Close']), 
                        "validity_date": index.strftime('%Y-%m-%d'), 
                        "source": "Yahoo Finance"
                    })
        
        if batch:
            safe_batch = filter_manual_entries(batch, "benchmarks")
            
            if safe_batch:
                supabase.table("benchmarks").upsert(safe_batch, on_conflict="ticker,validity_date").execute()
            print(f"   ✅ {len(batch)} Recent Crypto rates synced.")
            
    except Exception as e: print(f"   ❌ Crypto Error: {e}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    # NEW: Updated arguments to handle granular scheduling targets
    parser.add_argument("--target", help="Specify what to scrape: 'psx', 'mufap', 'gold_ter', or 'all'", default='all')
    args = parser.parse_args()
    start_time = datetime.now()

    target = args.target.lower()
    
    print(f"🚀 Initializing Scraper (Target: {target.upper()})")

    if target == 'psx':
        sync_psx_indices()
        sync_psx_etfs()
    elif target == 'mufap':
        sync_mufap_master()
        sync_ubl_amc_refined()
    elif target == 'gold_ter':
        sync_gold_rates()
        sync_mufap_payouts()
        sync_mufap_ter()
    elif target == 'market':
        sync_psx_indices()
        sync_psx_etfs()
        sync_gold_rates()
        sync_crypto_rates()
    else: # Default 'all'
        sync_psx_indices()
        sync_gold_rates()
        sync_psx_etfs()
        sync_mufap_master()
        sync_ubl_amc_refined()
        sync_mufap_payouts()
        sync_mufap_ter()
        sync_crypto_rates()

    print(f"\n🎉 SYNC COMPLETE. Total Time: {datetime.now() - start_time}")