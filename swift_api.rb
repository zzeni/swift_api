# swift_api.rb
require 'sinatra'
require 'sinatra/namespace'
require 'pony'

require './lib/game.rb'
require './lib/api_error.rb'

require 'json'
#require 'byebug'

WWW_ROOT = ENV['WWW_ROOT'] || '/home/deploy/swift_academy/'
HOMEWORKS_ROOT = File.expand_path('homeworks', WWW_ROOT)

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
      entries.sort! {|a, b| a <=> b}

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

      File.open(lock_file, File::RDWR|File::CREAT, 0644) do |f|
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

  post '/game' do
    begin
      @game = params['round']? Game.continue(params) : Game.new(params)
      play(@game)
    rescue ApiError => error
      status 500
      '<p>Sorry your prequest/parameters were not correct. You can try again ;)</p>' +
        '<p>Error : ' + error.message + '</p>' +
        '<p>Parameters: ' + params.to_json + '</p>'
    end
  end

  helpers do
    def play(game)
      case game.round
      when 0 then start
      when 1 then round_1
      when 2 then round_2
      else
        raise ApiError('Opps. This round doesn\'t really exist')
      end
    end
  end

  def start
    Pony.mail(:to => 'emanolova@gmail.com', :via => :sendmail, body: erb('mail/start'))
    erb :start
  end
end
