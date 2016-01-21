require 'mechanize'
require 'logger'
require 'digest'

API_KEY = "xdDkDvrsbn6F17t-s6Wy"

mech = Mechanize.new
# mech.log = Logger.new $stderr
# mech.agent.http.debug_output = $stderr
mech.user_agent_alias = 'Mac Safari'

def fetch_quote_si(mech, quote)
  raise "Must be valid quote #{quote}" if quote.nil? || quote.strip == "" 
  out_file = "data/raw/si/#{quote}.csv"

  # return if File.exists?(out_file)

  begin
    pg = mech.get("https://www.quandl.com/api/v1/datasets/SI/#{quote}_SI.csv?auth_token=#{API_KEY}")

    File.open(out_file, 'w') {|f|
      f.write(pg.body)
    }
  rescue
    puts "Unable to find quote: #{quote}"
  end  
end

def fetch_quote(mech, quote)
  raise "Must be valid quote #{quote}" if quote.nil? || quote.strip == "" 

  out_file = "data/raw/#{quote}.csv"

  # return if File.exists?(out_file)

  begin
    pg = mech.get("https://www.quandl.com/api/v1/datasets/WIKI/#{quote}.csv?auth_token=#{API_KEY}")

    File.open(out_file, 'w') {|f|
      f.write(pg.body)
    }
  rescue
    puts "Unable to find quote: #{quote}"
  end
end

def parse_ycharts(mech, quote, url, value_name)
  arr = []
  # return if File.exists?(out_file)
  out_file = "data/raw/#{value_name}/#{quote}.csv"

  begin
    pg = mech.get(url)
    tables = pg.root.css("div#dataTableBox").css("table.histDataTable")
    tables.each {|e|
      e.css("tr").each{|tr|
        tds = tr.css("td")
        if !tds.empty? && tds.size == 2
          dt = tds[0].text.strip
          eps = tds[1].text.strip
          arr << [dt, eps]
        end
      }
    }

    File.open(out_file, 'w') {|f|
      f.write("Date\t#{value_name}\n")
      arr.reverse.each{|a|
        f.write(a.join("\t") + "\n")
      }
    }
  rescue StandardError => e
    puts e
  end
end

def fetch_fcf(mech, quote)
  raise "Must be valid quote #{quote}" if quote.nil? || quote.strip == "" 
  url = "https://ycharts.com/companies/#{quote}/free_cash_flow"
  parse_ycharts(mech, quote, url, "fcf")
end

def fetch_eps(mech, quote)
  raise "Must be valid quote #{quote}" if quote.nil? || quote.strip == "" 
  url = "https://ycharts.com/companies/#{quote}/eps"
  parse_ycharts(mech, quote, url, "eps")
end

def fetch_shares_o(mech, quote)
  raise "Must be valid quote #{quote}" if quote.nil? || quote.strip == "" 
  url = "https://ycharts.com/companies/#{quote}/shares_outstanding"
  parse_ycharts(mech, quote, url, "shares_o")
end  

def fetch(mech, quotes)
  quotes.each{|q|
    fetch_quote(mech, q)
    fetch_quote_si(mech, q)
    fetch_eps(mech, q)
    fetch_fcf(mech, q)
    fetch_shares_o(mech, q)
  }
end

# quotes = ["MU", "FB", "AAPL", "BABA", "CHK", "EBAY", "GLD", "GPRO", "INTC", "MSFT", "NTDOY", "OIH", "QRVO", 
#   "VGK", "VMW", "AMZN", "ARMH", "BIB", "COP", "DIS", "NFLX", "SBUX", "VOO", "XOM", "AXP", "PYPL", 
#   "SWKS", "QCOM", "ORCL", "RHT", "BBY", "ATVI", "CMG", "FIT", "AMD", "AVGO", "AZO", "BBRY", "BIDU", 
#   "BOX", "BRCM", "BRK.A", "BRK.B", "COST", "CRM", "CSCO", "DATA", "EA", "EMC", "ETSY", "EWI", "EWP", 
#   "EWW", "EXPE", "FEZ", "GS", "KING", "KORS", "LNKD", "LRCX", "MA", "MKL", "MXIM", "NTAP", "OAS", 
#   "PBR", "NVDA", "NXPI", "QQQ", "S", "SALE", "SAP", "SHAK", "SNDK", "SNE", "SPY", "SYMC", "TGT", "TMUS", 
#   "TRIP", "TWTR", "V", "VNR", "VOOV", "VOOG", "VZ", "WMT", "XLNX", "YELP", "YHOO", "Z", "ZNGA", "GOOGL"]

# quotes.each {|q|
  # fetch_quote(mech, q)
  # fetch_eps(mech, q)
  # sleep(1)
# }

# q = ["MSFT", "ORCL"]
# fetch(mech,q)

if ARGV[0]
  fetch(mech, [ARGV[0]])
end