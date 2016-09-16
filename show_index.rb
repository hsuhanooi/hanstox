class ShowIndex
  attr_accessor :shows, :newest

  NEWEST_INDEXES = 'newest.json'
  SHOWS_INDEXES = 'shows.json'

  def initialize(options={})
    reset

    load_newest if File.exists?(NEWEST_INDEXES)
    load_shows if File.exists?(SHOWS_INDEXES)

    # scan unless valid?
  end

  def valid?
    @newest.size > 0 && @shows.size > 0
  end

  def save
    save_newest
    save_shows
  end

  def save_newest
    File.open(NEWEST_INDEXES, 'w') do |f|
      f.write(JSON.pretty_generate(@newest))
    end
  end

  def save_shows
    File.open(SHOWS_INDEXES, 'w') do |f|
      f.write(JSON.pretty_generate(@shows))
    end
  end

  def load_newest
    File.open(NEWEST_INDEXES, 'r') do |f|
      @newest = JSON.parse(f.read)
    end
  end

  def load_shows
    File.open(SHOWS_INDEXES, 'r') do |f|
      @shows = JSON.parse(f.read)
    end
  end

  def newest_feed
    sorted = @newest.keys.sort {|i1,i2| i2 <=> i1}
    sorted.each do |key|
      arr = @newest[key]
      puts key
      puts arr.to_s
    end
  end

  def reset
    @newest = {}
    @shows = {}
  end

  def scan_show(show = nil)
    show_path = "#{Episode::TV_ROOT}/#{show}"
    if File.directory?(show_path)
      Dir.foreach(show_path) do |season|
        next if season == '.' or season == '..'
        season_path = "#{show_path}/#{season}"
        if File.directory?(season_path)
          Dir.foreach(season_path) do |episode|
            next if episode == '.' or episode == '..'
            episode_path = "#{season_path}/#{episode}"
            puts "Scan: #{episode_path}"
            ep = Episode.new(filepath: episode_path)
            created = ep.mdate

            if ep.new_episode?
              if @newest[created]
                @newest[created] << ep
              else
                @newest[created] = [ep]
              end
            end

            if @shows[ep.title]
              @shows[ep.title] << ep
            else
              @shows[ep.title] = [ep]
            end
          end
        end
      end
    end
  end

  def scan
    reset

    Dir.foreach(Episode::TV_ROOT) do |show|
      next if show == '.' or show == '..'
      show_path = "#{Episode::TV_ROOT}/#{show}"
      if File.directory?(show_path)
        Dir.foreach(show_path) do |season|
          next if season == '.' or season == '..'
          season_path = "#{show_path}/#{season}"
          if File.directory?(season_path)
            Dir.foreach(season_path) do |episode|
              next if episode == '.' or episode == '..'
              episode_path = "#{season_path}/#{episode}"
              puts "Scan: #{episode_path}"
              ep = Episode.new(filepath: episode_path)
              created = ep.mdate

              if ep.new_episode?
                if @newest[created]
                  @newest[created] << ep
                else
                  @newest[created] = [ep]
                end
              end

              if @shows[ep.title]
                @shows[ep.title] << ep
              else
                @shows[ep.title] = [ep]
              end
            end
          end
        end
      end
    end
  end
end

