require 'cinch'
require 'yaml'
require 'thwait'

# Add camelcase method to Strings
class String
  def camelcase
    return self if self !~ /_/ && self =~ /[A-Z]+.*/
    split('_').map{|e| e.capitalize}.join
  end
end

# Class to load and process our config file
class BotConfig
  Network = Struct.new( :server, :port, :ssl, :password, :nick, :nicks,
                        :realname, :user, :messages_per_second, :server_queue_size,
                        :strictness, :message_split_start, :message_split_end,
                        :max_messages, :plugins, :channels, :encoding, :reconnect, :max_reconnect_delay,
                        :local_host, :timeouts, :ping_interval, :delay_joins, :dcc, :shared, :sasl )

  # Class to handle plugin files
  class Plugin
    def initialize( file )
      @plugin = file
    end

    def classname
      Object.const_get self.basename.gsub(/.rb$/, '').camelcase
    end

    def basename
      File::basename @plugin
    end
  end

  # Container attributes
  attr_reader :networks

  def initialize( config_file )
    return unless config_file
    @networks = Hash.new
    @plugins  = Array.new

    begin
      puts "Reading config from #{config_file}"
      config = YAML.load_file( config_file )
      # Load networks hash
      config['networks'].each { |name, details| @networks[name] = Network.new( details ) }

    # Syntax Error
    rescue Psych::SyntaxError
      puts "Error:  There was a problem reading #{config_file}, please check it and try again"
      return nil

    # No File
    rescue Errno::ENOENT
      puts "Could not find #{config_file}, please create this file first."
      return nil
    end

    config_dir = config['config_dir'] || '.'
    Dir.chdir(config_dir) rescue puts "#{config_dir} does not exist."

    # Collect plugins
    begin
      plugins_dir = config['plugins_dir'] || 'plugins'
      puts "Obtaining list of enabled plugins from #{plugins_dir}"

      # Find the files in the plugin_dir and load them
      Dir.glob("#{plugins_dir}/*.rb").each do |file| 
        require_relative file
        @plugins << Plugin.new(file)
      end

    rescue Errno::ENOENT
      puts 'Whoops, looks like the plugins directory specified in the config (plugins_dir) is invalid.'
    end

    puts "#{@plugins.count > 0 ? @plugins.count : 'no'} plugins loaded."

  end

  def plugins
    @plugins.map { |f| f.classname }
  end

end

# Load and process the config file
config = BotConfig.new( __FILE__.gsub(/.rb$/, '.yml') ) || exit
threads = ThreadsWait.new

# cycle through the configured networks and start our bot(s)
config.networks.each do |name, network|
  puts "Building connection to #{network.server['server']}"
  thread = Thread.new do
    bot = Cinch::Bot.new do
      configure do |c|
        c.plugins.plugins = config.plugins
        network.server.each do |key, value| 
          case key
            when /^sasl$/i
              c.sasl.username = value['username']
              c.sasl.password = value['password']
            else
              c.send( "#{key}=".to_sym, value )
          end
        end
      end
    end
    bot.start
  end

  threads.join_nowait( thread )
end

sleep 1 while threads.all_waits 

puts "That's all folks."
