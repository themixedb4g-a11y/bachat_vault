import os
import requests
from bs4 import BeautifulSoup
from lxml import html
import re
from supabase import create_client
from datetime import datetime
import pytz
import urllib3
from concurrent.futures import ThreadPoolExecutor # For parallel processing

# Suppress SSL Warnings
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# --- 1. CONNECTION ---
SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_KEY = os.environ.get("SUPABASE_KEY")
supabase = create_client(SUPABASE_URL, SUPABASE_KEY) if SUPABASE_URL and SUPABASE_KEY else None

headers = {'User-Agent': 'Mozilla/5.0'}
session = requests.Session() # Persistent session is faster than individual requests
session.headers.update(headers)

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
        response = session.get("https://dps.psx.com.pk", timeout=10)
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
            print(f"   ✅ PSX Indices synced.")
    except Exception as e: print(f"   ❌ PSX Error: {e}")

# --- TASK B: GOLD ---
def sync_gold_rates():
    print("💰 Syncing Gold...")
    try:
        soup = BeautifulSoup(session.get("https://gold.pk/gold-rates-pakistan.php", timeout=10).text, 'html.parser')
        gold_el = soup.find('p', class_='goldratehome')
        if gold_el:
            val = float(re.search(r'(\d+\.\d+|\d+)', gold_el.text.replace('Rs.', '').replace(',', '')).group(1))
            if val > 1000000: val = float(str(int(val))[:6])
            today_pk = datetime.now(pytz.timezone('Asia/Karachi')).strftime('%Y-%m-%d')
            supabase.table("benchmarks").upsert({"ticker": "GOLD_24K", "value": val, "validity_date": today_pk, "source": "Gold.pk"}, on_conflict="ticker,validity_date").execute()
            print(f"   ✅ Gold synced.")
    except Exception as e: print(f"   ❌ Gold Error: {e}")

# --- TASK C: PSX ETFs (Parallelized) ---
def fetch_etf(ticker):
    try:
        soup = BeautifulSoup(session.get(f"https://dps.psx.com.pk/etf/{ticker}", timeout=10).text, 'html.parser')
        price = float(re.findall(r'\d+\.\d+', soup.find('div', class_='quote__price').text)[0])
        date_match = re.search(r'[A-Z][a-z]{2}\s\d{2},\s\d{4}', soup.find('div', class_='quote__date').text).group()
        web_date = datetime.strptime(date_match, '%b %d, %Y').strftime('%Y-%m-%d')
        return {"ticker": ticker, "nav": price, "validity_date": web_date, "source": "PSX"}
    except: return None

def sync_psx_etfs():
    print("📊 Syncing ETFs (Parallel)...")
    etfs = ["JSGBETF", "JSMFETF", "MIIETF", "MZNPETF", "ACIETF", "NBPGETF", "NITGETF", "UBLPETF"]
    with ThreadPoolExecutor(max_workers=5) as executor:
        results = list(filter(None, executor.map(fetch_etf, etfs)))
    if results:
        supabase.table("daily_nav").upsert(results, on_conflict="ticker,validity_date").execute()
        print(f"   ✅ {len(results)} ETFs synced.")

# --- TASK D: MUFAP ---
def sync_mufap_master():
    print("🏛️ Syncing MUFAP...")
    res = supabase.table("master_funds").select("ticker, fund_id_mufap, return_logic").execute()
    id_map = {str(int(float(row['fund_id_mufap']))): row['ticker'] for row in res.data if row['fund_id_mufap']}
    logic_map = {row['ticker']: row.get('return_logic', 'Absolute') for row in res.data}
    
    batch = []
    for tab in [3]: # Can expand to 4, 5 if needed
        rows = BeautifulSoup(session.get(f"https://www.mufap.com.pk/Industry/IndustryStatDaily?tab={tab}", verify=False).text, 'html.parser').find_all('tr')
        for row in rows:
            cells = row.find_all('td')
            if len(cells) < 9: continue
            link = cells[2].find('a', href=True)
            if link:
                m_id = re.search(r'FundID=(\d+)', link['href']).group(1)
                ticker = id_map.get(m_id)
                if ticker:
                    dt_str = datetime.strptime(cells[8].text.strip().title(), '%b %d, %Y').strftime('%Y-%m-%d')
                    if is_valid_date(dt_str, logic_map.get(ticker, 'Absolute')):
                        batch.append({"ticker": ticker, "nav": float(cells[6].text.replace(',', '')), "validity_date": dt_str, "source": "MUFAP"})
    
    if batch:
        supabase.table("daily_nav").upsert(batch, on_conflict="ticker,validity_date").execute()
        print(f"   ✅ {len(batch)} MUFAP entries synced.")

# --- MASTER EXECUTION ---
def run_everything():
    start_time = datetime.now()
    # Running tasks that don't depend on each other in parallel
    with ThreadPoolExecutor(max_workers=3) as executor:
        executor.submit(sync_psx_indices)
        executor.submit(sync_gold_rates)
        executor.submit(sync_psx_etfs)
    
    # MUFAP and UBL tend to be heavier, run them sequentially or in their own block
    sync_mufap_master()
    
    print(f"\n🎉 SYNC COMPLETE. Total Time: {datetime.now() - start_time}")

if __name__ == "__main__":
    run_everything()