require './lib/hero.rb'

class Game
  STORAGE = './db/game.json'.freeze

  attr_reader :hero, :round

  def initialize(params)
    if params['key']
      load(params['key'])
    else
      wrong_input! unless params && params['message'] && params['message'] == 'game'
      @round = 0
      @hero = Hero.new(params['name'], params['email'])
      save
    end
  end

  def save
    state = {
      hero: hero.name,
      email: hero.email,
      key: hero.key,
      round: round
    }

    File.open(STORAGE, File::RDWR|File::CREAT, 0644) do |f|
      f.flock(File::LOCK_EX)
      f.write("#{Time.now.to_i}: #{state.to_json}\n")
    end
  end

  def load(key)
    saves = {}
    File.readlines(STORAGE).each do |line|
      matchdata = line.match(/\A(\d+): (.+)\Z/)
      saves[matchdata[1]] = JSON.parse(matchdata[2])
    end
    data = saves[key] or raise ApiError.new('Invalid key!')

    @round = data['round'] + 1
    @hero = Hero.new(data['hero'], data['email'], data['key'])
  end

  private
  def wrong_input!
    raise ApiError.new('Wrong input')
  end
end



