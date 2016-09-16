require 'fileutils'
require 'find'
require 'optparse'
require 'json'
require 'time'

require_relative 'lib/extract_files.rb'
require_relative 'lib/show_index.rb'

if __FILE__ == $0

  # parse arguments
  file = __FILE__

  debug = true
  title = nil
  season = nil
  commands = ['iterate_new_and_uncategorized']

  ARGV.options do |opts|
    opts.on("-p", "--prod")              { Episode.set(:debug, false) }
    opts.on("--list=[x,y,z]", Array)     { |val| commands = val }
    opts.on_tail("-h", "--help")         { exec "grep ^#/<'#{file}'|cut -c4-" }
    opts.on("-t TITLE", "--title=TITLE", String)        { |val| title = val }
    opts.on("-s SEASON", "--season=SEASON", String)     { |val| season = val }
    opts.on("-n NUM", "--number=NUMBER", Integer)     { |val| Episode.set(:number_to_run, val) }
    opts.parse!
  end

  commands.each do |command|
    if command == "test_missing_shows"
      raise "Must provide title and season" if title.nil? || season.nil?
      Episode.test_missing_shows(title, season.to_i)
    else
      Episode.send(command)
    end
  end
end
