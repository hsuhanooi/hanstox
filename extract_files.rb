require 'time'

class Episode
  @@configuration = {debug: true, number_to_run: nil}

  attr_accessor :season, :number, :title

  NEW_AND_UNCATEGORIZED = '/Volumes/Media/NewAndUncategorized'
  TV_ROOT = '/Volumes/Media/TV'

  SEASON_EP = /([\.\w]+)\.[s|S]([0-9]{2})[e|E]([0-9]{2})/
  ONE_WORD = /([\.\w]+)\.([0-9])([0-9]{2})\./
  NO_TITLE = /[s|S]([0-9]{2})[e|E]([0-9]{2})/
  TITLE_FROM_PATH = %r(#{TV_ROOT}/([^/]+)/)
  SEASON_FROM_PATH = %r(#{TV_ROOT}/[^/]+/Season ([0-9]*)/)
  EPISODE_EXPLICIT = %r(Episode ([0-9]*))

  TITLE_MAP = { "Hells Kitchen" => "Hell's Kitchen" }

  def initialize(options={})
    filepath = options[:filepath]
    season = options[:season]
    number = options[:number]
    title = options[:title]

    if filepath
      @filepath = filepath
      @season, @number, @title = Episode.parse(filepath)
    elsif season && number && title
      @season = season
      @number = number
      @title = title
    else
      raise "Must supply filepath or season, number, title"
    end
  end

  def self.test_missing_shows(title, season)
    Episode.find_missing_shows(title, season)
  end

  def self.find_missing_shows(title, season)
    ep = Episode.new(title: title, season: season, number: 1)
    if ep.dest_valid?
      episodes = {}
      Dir.foreach(ep.dest) do |item|
        next if item == '.' or item == '..'
        e = Episode.new(filepath: item)
        episodes[e.number] = e
      end

      min_ep = episodes.keys.first
      max_ep = episodes.keys.last

      missing = 0
      (min_ep..max_ep).each do |ep_num|
        if episodes[ep_num] == nil
          puts "Missing #{ep_num} for Title: #{title} Season: #{season}"
          missing += 1
        end
      end

      if missing == 0
        puts "Not missing any episodes for Title: #{title} Season: #{season}"
      else
        puts "Missing episodes for Title: #{title} Season: #{season}"
      end
    else
      raise "Destination for show not valid #{ep.dest}"
    end
  end

  def self.set(property, value)
    @@configuration[property] = value
  end

  def self.get(property)
    @@configuration[property]
  end

  def self.debug
    @@configuration[:debug]
  end

  def self.number_to_run
    @@configuration[:number_to_run]
  end

  def size_in_mb
    @size_in_mb ||= File.size(@filepath) / 1024 / 1024
  end

  def valid_size?
    size_in_mb > 25
  end

  def sample?
    @filepath.match("sample")
  end

  def video?
    ext = File.extname(@filepath)
    !sample? && valid_size? && (ext == ".mp4" || ext == ".avi" || ext == ".mkv")
  end

  def valid?
    video? && !(@season.nil? || @number.nil? || @season < 1 || @number < 1 || @title.nil?)
  end

  def filename
    if @filepath
      @filepath.split('/').last
    else
      raise "No filepath to get filename"
    end
  end

  def self.tokenize(title)
    title.split(/\.|\s/)
  end

  def dest
    tokens = Episode.tokenize(@title)
    (1..tokens.size-1).each do |i|
      fix_name = TITLE_MAP[tokens[0, i]]
      if fix_name

      end
    end

    "#{TV_ROOT}/#{@title}/Season #{@season}/"
  end

  def dest_valid?
    File.directory?(dest)
  end

  def new_episode?
    mtime > Time.now - (3600 * 24 * 30)
  end

  def mtime
    @mtime ||= File.mtime(@filepath)
  end

  def mdate
    @mdate ||= mtime.strftime("%Y-%m-%d")
  end

  def ctime
    @ctime ||= File.ctime(@filepath)
  end

  def cdate
    @cdate ||= ctime.strftime("%Y-%m-%d")
  end

  def old?
    Time.strptime(cdate, '%Y-%m-%d') < (Time.now - (3600*24*7))
  end

  def create_season_folder
    if !Dir.exists?(dest)
      Dir.mkdir(dest)
    end
  end

  def move
    if !dest_valid?
      create_season_folder
    end

    raise "Can't move unless both destination and file is valid. valid?:#{valid?} dest_valid?#{dest_valid?} dest:#{dest}" if !valid? || !dest_valid?

    begin
      if Episode.debug
        puts "Moving #{@filepath} to #{dest}"
      else
        FileUtils.mv(@filepath, dest)
      end
      true
    rescue => e
      puts "Unable to move file #{@filepath} to #{dest}"
      raise e
      false
    end
  end

  def movie?

  end

  def to_json(str=nil)
    JSON.dump({
      title: @title,
      season: @season,
      number: @number,
      mtime: mtime,
      filepath: @filepath
    })
  end

  def self.from_json(string)
    data = JSON.load string
    self.new(filepath: data['filepath'], season: data['season'],
      number: data['number'], title: data['title'], mtime: data['mtime'])
  end

  def to_s
    "Title: #{@title}; Season: #{@season}; EP: #{@number}; DEST: #{dest}; DEST_VALID: #{dest_valid?}; FILE: #{@filepath} CDATE: #{cdate} VALID: #{valid?} OLD: #{old?}"
  end

  def self.iterate_new_and_uncategorized
    count = 0
    Dir.foreach(NEW_AND_UNCATEGORIZED) do |item|
      next if item == '.' or item == '..'
      count += 1
      break if Episode.number_to_run && count >= Episode.number_to_run
      # puts item
      fullpath = "#{NEW_AND_UNCATEGORIZED}/#{item}"
      if File.directory?(fullpath)
        valid_eps = 0
        Find.find(fullpath) do |path|
          e = Episode.new(filepath: path)
          if e.valid? && e.old?
            puts e.to_s + "\n"
            e.move
            valid_eps += 1
          end
        end
        if valid_eps == 1
          if Episode.debug
            puts "Removing #{fullpath}"
          else
            FileUtils.rm_r(fullpath)
          end
        end
      else
        e = Episode.new(filepath: fullpath)
        if e.valid?
          puts e.to_s + "\n"
          e.move
        end
      end
    end
  end

  def self.parse(filepath)
    season = nil
    ep = nil
    title = nil

    [SEASON_EP, ONE_WORD, NO_TITLE].each do |regex|
      match = filepath.match(regex)
      if (season.nil? || ep.nil? || title.nil?) && match && match.size == 4
        title = match[1].gsub(".", ' ')
        season = match[2].to_i
        ep = match[3].to_i
      elsif (season.nil? || ep.nil? || title.nil?) && match && match.size == 3
        season = match[1].to_i
        ep = match[2].to_i
      end
    end

    if title.nil? || title == ""
      match = TITLE_FROM_PATH.match(filepath)
      if match && match.size == 2
        title = match[1]
      end
    end

    if season.nil? || season == ""
      match = SEASON_FROM_PATH.match(filepath)
      if match && match.size == 2
        season = match[1].to_i
      end
    end

    if ep.nil? || ep == ""
      match = EPISODE_EXPLICIT.match(filepath)
      if match && match.size == 2
        ep = match[1].to_i
      end
    end

    # puts "Season: #{season}; Ep: #{ep}"
    [season, ep, title]
  end

  def self.scan
    si = ShowIndex.new(skip_load: true)
    si.scan
    si.newest_feed
    si.save
  end

  def self.test_scan
    ep = Episode.new(filepath: "#{TV_ROOT}/Arrow/Season 4/arrow.402.hdtv-lol.mp4")
    puts ep.to_json
  end

  def self.test
    "Arrow.S04E05.HDTV.x264-LOL\[ettv\]/
      Elementary.S04E08.1080p.WEB-DL.x265.HEVC.AAC.5.1.Condo.mkv*
      Elementary.S04E09.HDTV.x264-LOL\[rarbg\]/
      Elementary.S04E10.HDTV.x264-LOL\[rarbg\]/
      Elementary.S04E11.HDTV.x264-LOL\[rarbg\]/
      Homeland.S05E02.WEB-DL.XviD-FUM\[ettv\]/
      Homeland.S05E04.WEB-DL.x264-FUM\[ettv\]/
      Homeland.S05E10.HDTV.x264-KILLERS\[ettv\]/
      How.to.Get.Away.with.Murder.S02E03.HDTV.x264-LOL\[ettv\]/
      How.to.Get.Away.with.Murder.S02E04.HDTV.x264-LOL\[ettv\]/
      MasterChef.Junior.S04E11.Head.Of.The.Class.720p.HULU.WEBRip.AAC2.0.H264-NTb\[rarbg\]/
      MasterChef.Junior.S04E12.The.Finale.720p.HULU.WEBRip.AAC2.0.H264-NTb\[rarbg\]/
      MasterChef.US.S06E17.720p.HDTV.X264-DIMENSION\[rarbg\]/
      MasterChef.US.S06E18.HDTV.x264-LOL\[ettv\]/
      MasterChef.US.S06E19E20.HDTV.x264-LOL\[ettv\]/
      Masterchef.US.S06E03.720p.HDTV.X264-DIMENSION.mkv*
      Masterchef.US.S06E04.720p.HDTV.X264-DIMENSION.mkv*
      New.Girl.S05E03.PROPER.HDTV.x264-KILLERS\[rarbg\]/
      New.Girl.S05E04.HDTV.x264-FLEET\[rarbg\]/
      New.Girl.S05E05.HDTV.x264-KILLERS\[rarbg\]/
      New.Girl.S05E06.HDTV.x264-KILLERS\[rarbg\]/
      New.Girl.S05E07.HDTV.x264-KILLERS\[rarbg\]/
      Pretty.Little.Liars.S06E12.HDTV.x264-LOL\[rarbg\]/
      Pretty.Little.Liars.S06E13.HDTV.x264-LOL\[rarbg\]/
      Pretty.Little.Liars.S06E14.HDTV.x264-LOL\[rarbg\]/
      Pretty.Little.Liars.S06E14.PROPER.WEB-DL.x264-RARBG/
      Pretty.Little.Liars.S06E15.HDTV.x264-LOL\[rarbg\]/
      Pretty.Little.Liars.S06E16.HDTV.x264-LOL\[rarbg\]/
      Scandal.US.S05E10.HDTV.x264-FUM\[ettv\]/
      Shark.Tank.S07E15.HDTV.x264-UAV\[rarbg\]/
      Shark.Tank.S07E16.HDTV.x264-UAV\[rarbg\]/
      Shark.Tank.S07E17.HDTV.x264-UAV\[rarbg\]/
      The.Walking.Dead.S06E09.HDTV.x264-FUM\[ettv\]/
      The.Walking.Dead.S06E09.HDTV.x264-FUM\[ettv\].mp4*
      Thumbs.db*
      the.good.wife.702.hdtv-lol.mp4*".split("\n").each do |line|
      ep = Episode.new(filepath: line.strip)
      puts ep.to_s
    end
  end
end
