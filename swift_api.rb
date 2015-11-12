# swift_api.rb
require 'sinatra'
require 'sinatra/namespace'
require 'pony'

require './lib/game.rb'
require './lib/api_error.rb'

require 'json'

if Sinatra::Base.development?
  require 'byebug'
end

set :default_encoding, 'utf-8'
set :encoding, 'utf-8'

WWW_ROOT = ENV['WWW_ROOT'] || '/home/deploy/swift_academy/'
HOMEWORKS_ROOT = File.expand_path('homeworks', WWW_ROOT)

if Sinatra::Base.development?
  SMTP_OPTIONS = {
    :from => 'donotreply@zenifytheweb.com',
    :via => :smtp,
    :via_options => {
      :address              => "127.0.0.1",
      :port                 => 1025,
      :domain               => "courses.zenifytheweb.com"
    }
  }.freeze
else
    SMTP_OPTIONS = {
    :from => 'donotreply@zenifytheweb.com',
    :via => :smtp,
    :via_options => {
      :address => "127.0.0.1",
      :port    => 25,
      :domain  => 'courses.zenifytheweb.com'
    }
  }.freeze
end

not_found do
  status 404
  'Ooops! That\'s not where you wanted to go'
end

namespace '/api' do
  post "/fs_read" do
    request.body.rewind  # in case someone already read it
    data = URI.decode(request.body.read)
    query = Rack::Utils.parse_nested_query(data)

    dir = query['dir']

    Dir.chdir(HOMEWORKS_ROOT)

    return 'N/A' if Dir.pwd > File.absolute_path(dir)

    if Dir.exists?(dir)
      entries = Dir.entries(dir).reject {|x| x[0] == '.'}
      entries.sort! {|a, b| a.downcase <=> b.downcase}

#      if %w(group1 group2).include?(File.basename(File.absolute_path(dir)))
#        entries.reject! { |x| x =~ /\.html\Z/ }
#      end

      unless entries.empty?
        result = "<ul class=\"jqueryFileTree\" style=\"display: none;\">"
        dirs = ""
        files = ""

        entries.each do |file|
          rel = "#{dir}/#{file}"

          if Dir.exists?(File.join(dir,file))
            dirs += "<li class=\"directory collapsed\"><a href=\"#\" rel=\"#{rel}/\">#{file}</a></li>"
          else
            ext = File.extname(file).sub(/\A\./,'')
            files += "<li class=\"file ext_#{ext}\"><a href=\"#\" rel=\"/#{rel}\">#{file}</a></li>"
          end
        end

        result += dirs
        result += files
        result += "</ul>"
      end
    else
      return "Ooops! Can't find your folder"
    end

    return result
  end

  get '/update' do
    lock_file = 'updating.lock'

    Dir.chdir(WWW_ROOT)

    if File.exists?(lock_file)
      'System is currently updating'
    else
      output = 0

      File.open(lock_file, File::RDWR|File::CREAT) do |f|
        f.flock(File::LOCK_EX)
        output = "lock file created..\n\n"
        output += %x(git fetch origin master && git reset --hard origin/master && git pull)
        output += %x(git submodule foreach git fetch origin master)
        output += %x(git submodule foreach git reset --hard origin/master && git pull)
      end

      output += "\n.. lock file removed" if File.delete(lock_file)

      "<pre>#{output}</pre>"
    end
  end

  post '/game/start' do
    begin
      @game = Game.new
      @game.start(params)
      play(@game)
    rescue ApiError => error
      status 500
      '<p>Sorry your prequest/parameters were not correct. You can try again ;)</p>' +
        '<p>Error : ' + error.message + '</p>' +
        '<p>Parameters: ' + params.to_json + '</p>'
    end
  end

  post '/game/continue' do
    begin
      @game = Game.new
      @game.load(params.delete("key"))
      @game.check(params)
      play(@game)
    rescue ApiError => error
      status 500
      '<p>Sorry your prequest/parameters were not correct. You can try again ;)</p>' +
        '<p>Error : ' + error.message + '</p>' +
        '<p>Parameters: ' + params.to_json + '</p>'
    end
  end

  get '/game/complete' do
    begin
      @game = Game.new
      @game.load(params.delete("key"))
      @game.finish
      @game.save
      erb :complete
    rescue ApiError => error
      status 500
      '<p>Sorry your prequest/parameters were not correct. You can try again ;)</p>' +
        '<p>Error : ' + error.message + '</p>' +
        '<p>Parameters: ' + params.to_json + '</p>'
    end
  end

  helpers do
    def play(game)
      stage = :initial

      mail_details = {
        to: game.hero.email,
        subject: "Swifting around: an interactive mind game - Stage #{game.round}"
      }

      case game.round.to_s
      when "0"
        stage = :start
        @task = File.read("./db/tasks/task#{game.round}.txt", :encoding => 'utf-8')
      when "1"
        stage = :round_1
        mail_details[:attachments] = { 'chuck.jpg' => File.read('./db/chuck.jpg') }
      when "2"
        stage = :round_2
      else
        raise ApiError.new('Opps. This round doesn\'t really exist')
      end

      mail_details[:body] = erb(:"mail/#{stage}")
      Pony.mail SMTP_OPTIONS.merge(mail_details)

      @game.save

      erb stage
    end
  end
end
