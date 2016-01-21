require 'mechanize'
require 'logger'
require 'digest'

def parse_page(page, options={})
  no = Nokogiri::HTML(JSON.parse(page.body.match(/[^{]+(.*)/)[1][0...-1])["componentData"])
  years = no.css("table.r_table1").css("thead > tr > th").map{|e| e.text}

  arr = []
  hsh = nil
  cnt = 0
  label = nil
  no.css("table.r_table1").css("tbody > tr:not(.hr)").each {|e|
    tup = parse_row(e)
    if tup[1].size == 0
      label = tup[0]
      cnt = 0
    else
      tup[0] = "#{label ? "#{label} " : ""}#{tup[0]}"
      arr << tup

      if cnt >= 3
        cnt = 0
        label = nil
      end
      cnt += 1
    end
  }
  years = years.map {|y| "#{y}-01"}
  years[0] = "Date"
  dt = Time.strptime(years[10], "%Y-%m")
  last = dt + (3600*24*365)
  years[11] = last.strftime("%Y-%m-%d")

  return [years, arr]
end

def parse_row(tr)
  head = tr.css("th").text
  vals = tr.css("td").map {|e| e.text}
  [head, vals]
end

def rows_to_cols(rows)
  cols = []
  (0..11).each_with_index {|col, col_idx|
    new_col = []
    rows.each_with_index {|row, row_idx|
      frow = row.flatten
      new_col << frow[col]
      # puts "VAL:#{frow[col]} row:#{row_idx} col:#{col_idx}"
    }
    cols << new_col
  }
  cols
end

def scrape(quote)
  begin
    mech = Mechanize.new
    # mech.log = Logger.new $stderr
    # mech.agent.http.debug_output = $stderr
    mech.user_agent_alias = 'Mac Safari'

    url = "http://financials.morningstar.com/financials/getFinancePart.html?&callback=jsonp1438800171603&t=XNAS:#{quote}&region=usa&culture=en-US&cur=&order=asc&_=1438800171643"
    page = mech.get(url)

    k_ratios = "http://financials.morningstar.com/financials/getKeyStatPart.html?&callback=jsonp1438924494296&t=XNAS:#{quote}&region=usa&culture=en-US&cur=&order=asc&_=1438924494334"
    k_page = mech.get(k_ratios)

    years, rows = parse_page(k_page)
    fin_years, fin_rows = parse_page(page)

    ratios = rows_to_cols(rows)
    financials = rows_to_cols(fin_rows)

    File.open("data/raw/morningstar/key_ratios/#{quote}.csv", 'w') {|f|
      ratios.each_with_index {|col,idx|
        # puts "idx:#{idx}"
        data = col.join("\t")
        data = data.gsub("\xe2\x80\x94", "?") if idx > 0
        f.write("#{years[idx]}\t#{data}\n")
      }
    }

    File.open("data/raw/morningstar/financials/#{quote}.csv", 'w') {|f|
      financials.each_with_index {|col,idx|
        # puts "idx:#{idx}"
        data = col.join("\t")
        data = data.gsub("\xe2\x80\x94", "?") if idx > 0
        f.write("#{years[idx]}\t#{data}\n")
      }
    }
    puts "Finished Scraping #{quote}"
  rescue
    puts "Unable to scrape #{quote}"
  end
end

# quotes = ["MU", "FB", "AAPL", "BABA", "CHK", "EBAY", "GLD", "GPRO", "INTC", "MSFT", "NTDOY", "OIH", "QRVO", 
#   "VGK", "VMW", "AMZN", "ARMH", "BIB", "COP", "DIS", "NFLX", "SBUX", "VOO", "XOM", "AXP", "PYPL", 
#   "SWKS", "QCOM", "ORCL", "RHT", "BBY", "ATVI", "CMG", "FIT", "AMD", "AVGO", "AZO", "BBRY", "BIDU", 
#   "BOX", "BRCM", "BRK.A", "BRK.B", "COST", "CRM", "CSCO", "DATA", "EA", "EMC", "ETSY", "EWI", "EWP", 
#   "EWW", "EXPE", "FEZ", "GS", "KING", "KORS", "LNKD", "LRCX", "MA", "MKL", "MXIM", "NTAP", "OAS", 
#   "PBR", "NVDA", "NXPI", "QQQ", "S", "SALE", "SAP", "SHAK", "SNDK", "SNE", "SPY", "SYMC", "TGT", "TMUS", 
#   "TRIP", "TWTR", "V", "VNR", "VOOV", "VOOG", "VZ", "WMT", "XLNX", "YELP", "YHOO", "Z", "ZNGA", "GOOGL"]

# quotes.each {|q|
#   scrape(q)
# }
scrape(ARGV[0])