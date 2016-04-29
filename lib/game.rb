# encoding: utf-8
require './lib/hero.rb'

class Game
  ROOT_DIR = '/home/deploy/swift_api'.freeze
  STORAGE = File.join(ROOT_DIR, '/db/game.json').freeze
  WINNERS = File.join(ROOT_DIR, '/db/winners.json').freeze

  attr_reader :hero, :round, :award

  def start(params)
    @round = 0
    wrong_input! unless params && params['message'] && params['message'] == 'game'
    missing_field!(:name) unless params['name']
    missing_field!(:email) unless params['email']

    @hero = Hero.new(params['name'], params['email'])
  end

  def save
    state = {
      hero: hero.name,
      email: hero.email,
      key: hero.key,
      round: round
    }

    File.open(STORAGE, 'a', encoding: 'utf-8') do |f|
      f.flock(File::LOCK_EX)
      f.puts "#{Time.now.to_i}: #{state.to_json}\n"
    end
  end

  def load(key)
    missing_key! unless key
    data = nil
    File.readlines(STORAGE, encoding: 'utf-8').each do |line|
      matchdata = line.match(/\A(\d+): (.+)\Z/)
      state = JSON.parse(matchdata[2])
      data = state if state["key"].to_s == key
    end

    raise ApiError.new('Invalid key!') unless data

    p "Loaded saved state: #{data}"

    @hero = Hero.new(data['hero'], data['email'], data['key'])
    @round = data["round"]
  end

  def check(params)
    case @round.to_s
    when "0"
      assert_check =
        params["answer_1"] == "2014" &&
        params["answer_2"].gsub(/\W/, '').downcase == "douglascrockford" &&
        params["answer_3"] == "alt"
    when "1"
      assert_check =
        params["name"] == "Chuck Norris" &&
        params["email"] == "chuck@kicks.ass" &&
        params["occupation"] == "ultimate hero" &&
        params["eyes_color"].to_s.downcase == "#0000ff" &&
        params["photo"] == "chuck.jpg"
    when "2"
      assert_check = params["javascript-rocks"] == "36144"
    when "3"
      assert_check = params["result"] == "N189391C"
    else
      assert_check = false
    end
    p "Params: #{params.inspect}"
    p "Assert check: #{assert_check}"

    wrong_input! unless assert_check

    @round += 1
  end

  def finish
    wrong_input! unless round == 3

    record = nil
    if File.exists?(WINNERS)
      File.readlines(WINNERS, encoding: 'utf-8').each do |line|
        matchdata = line.match(/\A(\d+): (.+)\Z/)
        if matchdata
          data = JSON.parse(matchdata[2])
          record = data if data["key"].to_s == @hero.key.to_s
        end
      end
    end

    if record
      @award = record["award"]
    else
      @award = get_award
      data = {
        hero: hero.name,
        email: hero.email,
        key: hero.key,
        award: @award
      }
      File.open(WINNERS, 'a', encoding: 'utf-8') do |f|
        f.flock(File::LOCK_EX)
        f.puts "#{Time.now.to_i}: #{data.to_json}\n"
      end
    end
  end

  private
  def get_award
    awards = Dir.glob(File.join(ROOT_DIR, 'public/images/catz/*.jpg'))
    awards.sample.gsub(File.join(ROOT_DIR, 'public/images'), 'http://zenlabs.pro/img')
  end

  def wrong_input!
    raise ApiError.new("[GAME ROUND #{@round+1}] Wrong input")
  end

  def missing_key!
    raise ApiError.new("Game cant load due to a missing key!")
  end

  def missing_field(name)
    raise ApiError.new("Game cant load due to a missing #{field.to_s}!")
  end
end



