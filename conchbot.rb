#!/usr/bin/env ruby
require 'yaml'
require 'thwait'
require 'cinch'
require 'cinch/extensions/authentication'

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
        @plugins  = {
            core: [],
            extra: []
        }

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

        # Main Bot Directory (all future paths will be relative to this, unless specified otherwise in the config)
        dir_main = config['directories']['main'] || '.'

        begin
            Dir.chdir( File.expand_path(dir_main) )
        rescue
            puts "#{dir_main} does not exist.  Please check your dir_main configuration."
            puts 'Continuing using the current directory.'
        end

        # Collect and enable plugins
        # Load core plugins
        plugins_core = config['directories']['plugins']['core'] || "#{dir_main}/plugins/core"

        raise "Required directory, #{plugins_core}, cannot be found.  Please check your plugins_core configuration item and try again." unless Dir.exists?(plugins_core)

        puts "Loading core plugins from #{plugins_core}"
        Dir.glob("#{plugins_core}/*.rb").each do |file| 
            require_relative file
            @plugins[:core] << Plugin.new(file)
        end

        begin
            # Load optional extra plugins
            plugins_extra = config['plugins_extra'] || 'plugins/enabled'
            puts "Loading extra plugins from #{plugins_extra}"
  
            # Find the files in the plugin_dir and load them
            Dir.glob("#{plugins_extra}/*.rb").each do |file| 
                require_relative file
                @plugins[:extra] << Plugin.new(file)
            end

        rescue Errno::ENOENT
            puts 'Whoops, looks like the plugins directory specified in the config (plugins_extra) is invalid.'
        end

        puts "#{@plugins[:extra].count > 0 ? @plugins[:extra].count : 'no'} plugins loaded."

    end

    def plugins
        classes = Array.new
        @plugins.keys.each { |key| @plugins[key].map { |f| classes << f.classname } }
        return classes
    end

end

# Load and process the config file
config  = BotConfig.new( __FILE__.gsub(/.rb$/, '.yml') ) || exit
threads = ThreadsWait.new

# cycle through the configured networks and start our bot(s)
config.networks.each do |name, network|
    Thread.abort_on_exception = true    # Show exceptions as they happen
    thread = Thread.new do
        bot = Cinch::Bot.new do
            configure do |c|
                c.authentication          = Cinch::Configuration::Authentication.new
                c.authentication.level    = :users
                c.authentication.strategy = :list
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

        puts "Starting connection to #{bot.config.server}"
        bot.start
    end

    threads.join_nowait( thread )
end

sleep 1 while threads.all_waits 

puts "That's all folks."
