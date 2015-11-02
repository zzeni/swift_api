require './lib/hero.rb'

class Game
  STORAGE = './db/game.json'.freeze

  attr_reader :hero, :round

  def initialize(params)
    wrong_input! unless params && params['message'] && params['message'] == 'game'
    @round = 0
    @hero = Hero.new(params['name'], params['email'])
    save
  end

  def continue(params)
    hero_key = params('hero_id')
    load(hero_key)
    wrong_input! unless params['round'] == round
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
  end

  private
  def wrong_input!
    raise ApiError.new('Wrong input')
  end
end



