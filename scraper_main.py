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

# Suppress SSL Warnings
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# --- # --- 1. CONNECTION ---
SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_KEY = os.environ.get("SUPABASE_KEY")

if not SUPABASE_URL or not SUPABASE_KEY:
    print("❌ ERROR: Supabase Keys are missing from GitHub Secrets!")
    sys.exit(1) # This stops the script cleanly

supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

def is_valid_date(date_str, ticker_logic):
    dt = datetime.strptime(date_str, '%Y-%m-%d').date()
    today_pk = datetime.now(pytz.timezone('Asia/Karachi')).date()
    if dt > today_pk: return False
    if ticker_logic == 'Absolute' and dt.weekday() >= 5: return False
    return True

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
            supabase.table("benchmarks").upsert(batch, on_conflict="ticker,validity_date").execute()
            print(f"   ✅ PSX Indices updated.")
    except Exception as e: print(f"   ❌ PSX Error: {e}")

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
            supabase.table("benchmarks").upsert({"ticker": "GOLD_24K", "value": val, "validity_date": today_pk, "source": "Gold.pk"}, on_conflict="ticker,validity_date").execute()
            print(f"   ✅ Gold updated.")
    except Exception as e: print(f"   ❌ Gold Error: {e}")

# --- TASK C: PSX ETFs ---
def fetch_etf(ticker):
    try:
        soup = BeautifulSoup(session.get(f"https://dps.psx.com.pk/etf/{ticker}", timeout=10).text, 'lxml')
        price = float(re.findall(r'\d+\.\d+', soup.find('div', class_='quote__price').text)[0])
        date_match = re.search(r'[A-Z][a-z]{2}\s\d{2},\s\d{4}', soup.find('div', class_='quote__date').text).group()
        web_date = datetime.strptime(date_match, '%b %d, %Y').strftime('%Y-%m-%d')
        return {"ticker": ticker, "nav": price, "validity_date": web_date, "source": "PSX"}
    except: return None

def sync_psx_etfs():
    print("📊 Syncing ETFs...")
    etfs = ["JSGBETF", "JSMFETF", "MIIETF", "MZNPETF", "ACIETF", "NBPGETF", "NITGETF", "UBLPETF"]
    with ThreadPoolExecutor(max_workers=8) as executor:
        results = list(filter(None, executor.map(fetch_etf, etfs)))
    if results:
        supabase.table("daily_nav").upsert(results, on_conflict="ticker,validity_date").execute()
        print(f"   ✅ {len(results)} ETFs updated.")

# --- TASK D: TARGETED MUFAP ---
def sync_mufap_master():
    print("🏛️ Syncing MUFAP (Targeted)...")
    res = supabase.table("master_funds").select("ticker, fund_id_mufap, return_logic").not_.is_("fund_id_mufap", "null").execute()
    target_ids = {str(int(float(row['fund_id_mufap']))) for row in res.data}
    id_to_ticker = {str(int(float(row['fund_id_mufap']))): row['ticker'] for row in res.data}
    logic_map = {row['ticker']: row.get('return_logic', 'Absolute') for row in res.data}
    
    batch = []
    soup = BeautifulSoup(session.get("https://www.mufap.com.pk/Industry/IndustryStatDaily?tab=3", verify=False).text, 'lxml')
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
                    if is_valid_date(dt_str, logic_map.get(ticker, 'Absolute')):
                        batch.append({"ticker": ticker, "nav": float(cells[6].text.replace(',', '')), "validity_date": dt_str, "source": "MUFAP"})
                except: continue
    if batch:
        supabase.table("daily_nav").upsert(batch, on_conflict="ticker,validity_date").execute()
        print(f"   ✅ {len(batch)} MUFAP funds updated.")

# --- TASK E: UBL AMC (Priority Overwrite) ---
def sync_ubl_amc_refined():
    print("🏦 Syncing UBL AMC (Priority)...")
    res = supabase.table("master_funds").select("ticker, amc_website_name, return_logic").not_.is_("amc_website_name", "null").execute()
    ubl_map = {r['amc_website_name'].strip(): r['ticker'] for r in res.data}
    logic_map = {r['ticker']: r.get('return_logic', 'Absolute') for r in res.data}
    
    batch = []
    try:
        url = "https://www.ublfunds.com.pk/resources-tools/fund-performance-tools/latest-fund-prices/"
        soup = BeautifulSoup(session.get(url, verify=False, timeout=15).text, 'lxml')
        for table_id in ['conventional-mutual-fund-schemes', 'islamic-mutual-fund-schemes']:
            table = soup.find('table', id=table_id)
            if not table: continue
            for row in table.find_all('tr'):
                cells = row.find_all('td')
                if len(cells) >= 4:
                    ticker = ubl_map.get(cells[0].get_text(strip=True))
                    if ticker:
                        try:
                            dt_str = datetime.strptime(cells[1].text.strip(), '%d-%b-%Y').strftime('%Y-%m-%d')
                            if is_valid_date(dt_str, logic_map.get(ticker, 'Absolute')):
                                batch.append({"ticker": ticker, "nav": float(cells[3].text.replace(',', '')), "validity_date": dt_str, "source": "AMC_Website"})
                        except: continue
        if batch:
            supabase.table("daily_nav").upsert(batch, on_conflict="ticker,validity_date").execute()
            print(f"   ✅ {len(batch)} UBL funds updated (Priority).")
    except Exception as e: print(f"   ❌ UBL Error: {e}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", help="funds, market, or full")
    args = parser.parse_args()
    start_time = datetime.now()

    if args.mode == "funds":
        sync_mufap_master()
        sync_ubl_amc_refined()
    elif args.mode == "market":
        sync_psx_indices()
        sync_psx_etfs()
        sync_gold_rates()
    else:
        sync_psx_indices()
        sync_gold_rates()
        sync_psx_etfs()
        sync_mufap_master()
        sync_ubl_amc_refined()

    print(f"\n🎉 SYNC COMPLETE. Total Time: {datetime.now() - start_time}")